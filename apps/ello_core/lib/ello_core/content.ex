defmodule Ello.Core.Content do
  import NewRelicPhoenix, only: [measure_segment: 2]
  import Ecto.Query
  import Ello.Core
  alias Ello.Core.Repo
  alias Ello.Core.Network
  alias Ello.Core.Network.{Flag}
  alias __MODULE__.{
    Filter,
    Preload,
    Post,
    Love,
    Watch,
  }

  @moduledoc """
  Responsible for retrieving and loading posts, comments, and related assets.

  Handles database queryies, preloading reposts, and fetching cached values.
  """

  @typedoc """
  All Ello.Core.Content public functions expect to receive a map of options.
  Those options should always include `current_user`, `allow_nsfw`, and
  `allow_nudity`. Any extra options should be included in the same map.
  """
  @type options :: %{
    required(:current_user) => User.t | nil,
    required(:allow_nsfw)   => boolean,
    required(:allow_nudity) => boolean,
    optional(:id_or_slug)   => integer | String.t,
    optional(:ids)          => [integer],
    optional(:tokens)       => [String.t],
    optional(:related_to)   => Post.t,
    optional(any)           => any
  }

  @doc """
  Get a post by id or token.

  Includes postgres info and bulk fetched redis info.

  If the current_user is passed in the reposted/wathched/loved relationship will
  also be included, and the post will be filtered based on blocked users, nsfw
  and nudity content visibility, and posts by banned users.  If no user is
  present, posts by private users will not be included.
  """
  @spec post(options) :: Post.t | nil
  def post(%{id_or_token: "~" <> token} = options) do
    Post
    |> Filter.post_query(options)
    |> Repo.get_by(token: token)
    |> Preload.post_list(options)
    |> Filter.post_list(options)
  end
  def post(%{id_or_token: id} = options) do
    Post
    |> Filter.post_query(options)
    |> Repo.get(id)
    |> Preload.post_list(options)
    |> Filter.post_list(options)
  end

  @doc """
  Get posts filtered for user/client and with all preloads.

  Uses different algorithms to find the posts based on the options passed in.
    * ids - Finds by post ids, posts returned in same order as ids.
    * tokens - Finds by post tokens, posts returned in same order as tokens.
    * related_to - Finds posts related to the post passed in.
    * user_id - Finds posts authored/reposted by the given user.

  Posts are returned in the order the ids are given.
  """
  def posts(%{ids: ids} = options) do
    Post
    |> where([p], p.id in ^ids)
    |> Filter.post_query(options)
    |> Repo.all
    |> Preload.post_list(options)
    |> Filter.post_list(options)
    |> post_sorting(:id, ids)
  end
  def posts(%{tokens: tokens} = options) do
    Post
    |> where([p], p.token in ^tokens)
    |> Filter.post_query(options)
    |> Repo.all
    |> Preload.post_list(options)
    |> Filter.post_list(options)
    |> post_sorting(:token, tokens)
  end
  def posts(%{related_to: %Post{} = related_to, per_page: per_page} = options) do
    %{id: related_id, author_id: author_id} = related_to
    Post
    |> Filter.post_query(options)
    |> where([p], p.author_id == ^author_id)
    |> where([p], p.id != ^related_id)
    |> where([p], is_nil(p.parent_post_id))
    |> order_by(fragment("random()"))
    |> limit(^per_page)
    |> Repo.all
    |> Preload.post_list(options)
    |> Filter.post_list(options)
  end
  def posts(%{user_id: user_id} = options) do
    Post
    |> Filter.post_query(options)
    |> where([p], p.author_id == ^user_id)
    |> where([p], is_nil(p.parent_post_id))
    |> post_pagination(options)
    |> Repo.all
    |> Preload.post_list(options)
    |> Filter.post_list(options)
  end

  defp post_sorting(posts, field, values) do
    measure_segment {__MODULE__, "post_sorting"} do
      mapped = Enum.group_by(posts, &Map.get(&1, field))
      values
      |> Enum.uniq
      |> Enum.flat_map(&(mapped[&1] || []))
    end
  end

  defp post_pagination(query, %{before: nil, per_page: per_page}) do
    query
    |> order_by([p], [desc: p.created_at])
    |> limit(^per_page)
  end
  defp post_pagination(query, %{before: before, per_page: per_page}) do
    before = parse_before(before)
    query
    |> order_by([p], [desc: p.created_at])
    |> where([p], p.created_at < ^before)
    |> limit(^per_page)
  end

  @doc """
  Get all comments for a post_id
  """
  def comments(%{post: %{reposted_source: %Post{} = source}} = options),
    do: comments(Map.put(options, :post, source))
  def comments(%{ids: ids} = options) do
    # We don't filter NSFW users from comments
    options = Map.merge(options, %{allow_nsfw: true, allow_nudity: true})
    Post
    |> where([p], p.id in ^ids)
    |> Repo.all
    |> Preload.comment_list(options)
    |> Filter.post_list(options)
  end
  def comments(options) do
    # We don't filter NSFW users from comments
    options = Map.merge(options, %{allow_nsfw: true, allow_nudity: true})
    Post
    |> Filter.comments_query(options)
    |> comments_for_post(options)
    |> post_pagination(options)
    |> Repo.all
    |> Preload.comment_list(options)
    |> Filter.post_list(options)
  end

  @doc """
  Get a comments by post_id and id
  """
  def comment(%{post: %{reposted_source: %Post{} = source}} = options),
    do: comment(Map.put(options, :post, source))
  def comment(%{id: id} = options) do
    # We don't filter NSFW users from comments
    options = Map.merge(options, %{allow_nsfw: true, allow_nudity: true})
    Post
    |> Filter.comments_query(options)
    |> comments_for_post(options)
    |> Repo.get(id)
    |> Preload.comment_list(options)
    |> Filter.post_list(options)
  end

  defp comments_for_post(q, %{post: %{id: id}} = options) do
    q
    |> join(:left, [c, a], parent in assoc(c, :parent_post))
    |> where([c, a, parent], parent.id == ^id or parent.reposted_source_id == ^id)
    |> filter_spam(options)
  end

  defp filter_spam(q, %{current_user: %{is_spammer: true}}), do: q
  defp filter_spam(q, _) do
    q
    |> join(:left, [c, a, parent], f in Flag, [subject_user_id: a.id, verified: true, kind: "spam"])
    |> where([c, a, parent, flags], is_nil(flags.id))
  end

  def loves(%{user: %{id: user_id}} = options) do
    Love
    |> where([l], l.user_id == ^user_id and l.deleted == false)
    |> Filter.loves_query(options)
    |> Network.paginate(options)
    |> Repo.all
    |> Preload.love_list(options)
  end
  def loves(%{ids: ids} = options) do
    Love
    |> where([l], l.id in ^ids)
    |> Filter.loves_query(options)
    |> Repo.all
    |> Preload.love_list(options)
  end

  def watches(%{ids: ids} = options) do
    Watch
    |> where([w], w.id in ^ids)
    |> Repo.all
    |> Preload.watches_list(options)
  end
end
