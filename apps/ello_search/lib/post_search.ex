defmodule Ello.Search.PostSearch do
  import NewRelicPhoenix, only: [measure_segment: 2]
  alias Ello.Core.Content
  alias Ello.Search.{Client, PostIndex, TrendingPost}
  use Timex

  def post_search(%{terms: terms} = opts) do
    opts
    |> build_client_filter_queries
    |> build_text_content_query(terms)
    |> build_mention_query(terms)
    |> build_hashtag_query(terms)
    |> build_pagination_query(opts)
    |> search_post_index(opts)
  end

  def post_search(%{trending: true} = opts) do
    client_filters = build_client_filter_queries(opts)[:query]

    TrendingPost.base_query
    |> TrendingPost.build_boosting_queries
    |> Map.merge(%{query: %{function_score: %{query: client_filters}}})
    |> TrendingPost.build_match_all_query
    |> build_pagination_query(opts)
    |> search_post_index(opts)
  end

  defp build_client_filter_queries(opts) do
    base_query()
    |> build_author_query(opts[:current_user])
    |> build_language_query(opts[:language])
    |> filter_nsfw(opts[:allow_nsfw])
    |> filter_nudity(opts[:allow_nudity])
    |> filter_blocked(opts[:current_user])
    |> filter_days(opts[:within_days])
  end

  defp base_query do
    %{
      from: 0,
      size: 10,
      stored_fields: [],
      query: %{
        bool: %{
          must:     [],
          should:   [],
          filter:   [],
          must_not: [
            %{term: %{is_comment: true}},
            %{term: %{is_hidden:  true}},
            %{term: %{is_repost:  true}},
          ]
        }
      }
    }
  end

  defp build_text_content_query(query, terms) do
    text_boost = Application.get_env(:ello_search, :text_content_boost_factor)
    update_in(query[:query][:bool][:must], &([%{query_string: %{query: terms, fields: ["text_content"], boost: text_boost}} | &1]))
  end

  defp build_mention_query(query, terms) do
    mention_boost = Application.get_env(:ello_search, :mention_boost_factor)
    update_in(query[:query][:bool][:should], &([%{match: %{mentions: %{query: terms, boost: mention_boost}}} | &1]))
  end

  defp build_hashtag_query(query, terms) do
    hashtag_boost = Application.get_env(:ello_search, :hashtag_boost_factor)
    update_in(query[:query][:bool][:should], &([%{match: %{hashtags: %{query: terms, boost: hashtag_boost}}} | &1]))
  end

  defp filter_nsfw(query, true), do: query
  defp filter_nsfw(query, false) do
    update_in(query[:query][:bool][:must_not], &([%{term: %{is_adult_content: true}} | &1]))
  end

  defp filter_nudity(query, true), do: query
  defp filter_nudity(query, false) do
    update_in(query[:query][:bool][:must_not], &([%{term: %{has_nudity: true}} | &1]))
  end

  defp filter_blocked(query, nil), do: query
  defp filter_blocked(query, user) do
    update_in(query[:query][:bool][:must_not], &([%{terms: %{author_id: user.all_blocked_ids}} | &1]))
  end

  defp author_query do
    %{
      has_parent: %{
        parent_type: "author",
        query: %{
          bool: %{
            filter: [
              %{term: %{locked_out: false}},
              %{term: %{is_spammer: false}},
            ]
          }
        }
      }
    }
  end

  defp build_author_query(query, nil) do
    author_query = filter_private_authors(author_query())
    update_in(query[:query][:bool][:filter], &([author_query | &1]))
  end
  defp build_author_query(query, current_user) do
    update_in(query[:query][:bool][:filter], &([author_query() | &1]))
  end

  defp build_pagination_query(query, %{page: nil, per_page: nil}), do: query
  defp build_pagination_query(query, %{page: page, per_page: per_page}) do
    query
    |> update_in([:from], &(&1 = page * per_page))
    |> update_in([:size], &(&1 = per_page))
  end
  defp build_pagination_query(query, _), do: query

  defp filter_private_authors(query) do
    update_in(query[:has_parent][:query][:bool][:filter], &([%{term: %{is_public: true}} | &1]))
  end

  defp build_language_query(query, nil), do: query
  defp build_language_query(query, language) do
    language_boost = Application.get_env(:ello_search, :language_boost_factor)
    update_in(query[:query][:bool][:should], &([%{term: %{detected_language: %{value: language, boost: language_boost}}} | &1]))
  end

  defp filter_days(query, nil), do: query
  defp filter_days(query, within_days) do
    date = Timex.now
           |> Timex.shift(days: -within_days)
           |> Timex.format!("%Y-%m-%d", :strftime)
    update_in(query[:query][:bool][:filter], &([%{range: %{created_at: %{gte: date}}} | &1]))
  end

  defp search_post_index(query, opts) do
    ids = Client.search(PostIndex.index_name(), [PostIndex.post_doc_type], query).body["hits"]["hits"]
    ids
    |> Enum.map(&(String.to_integer(&1["_id"])))
    |> Content.posts_by_ids(opts)
  end
end
