defmodule Ello.V3.Resolvers.GlobalPostStreamTest do
  use Ello.V3.Case
  alias Ello.Stream
  alias Ello.Stream.Item
  alias Ello.Search.Post.Index

  @query """
    query($perPage: String, $before: String, $kind: StreamKind!) {
      globalPostStream(before: $before, kind: $kind, perPage: $perPage) {
        next
        isLastPage
        posts { id }
      }
    }
  """

  setup do
    Ecto.Adapters.SQL.Sandbox.mode(Ello.Core.Repo, {:shared, self()})
    Stream.Client.Test.start
    Stream.Client.Test.reset

    :ok
  end

  test "Recent stream", %{} do
    user = Factory.insert(:user)
    post1 = Factory.add_assets(Factory.insert(:post))
    post2 = Factory.insert(:post)
    post3 = Factory.insert(:post, has_nudity: true)
    post4 = Factory.insert(:post)
    post5 = Factory.insert(:post)
    post6 = Factory.insert(:post, has_nudity: true)
    Factory.insert(:love, post: post1, user: user)
    key = Stream.key(:global_recent)
    roshi_items = [
      %Item{id: "#{post1.id}", stream_id: key, ts: DateTime.utc_now},
      %Item{id: "#{post2.id}", stream_id: key, ts: DateTime.utc_now},
      %Item{id: "#{post3.id}", stream_id: key, ts: DateTime.utc_now},
      %Item{id: "#{post4.id}", stream_id: key, ts: DateTime.utc_now},
      %Item{id: "#{post5.id}", stream_id: key, ts: DateTime.utc_now},
      %Item{id: "#{post6.id}", stream_id: key, ts: DateTime.utc_now},
    ]
    Stream.Client.add_items(roshi_items)

    resp = post_graphql(%{query: @query, variables: %{"kind" => "RECENT", "perPage" => 3}})
    assert %{"data" => %{"globalPostStream" => json}} = json_response(resp)
    assert %{"isLastPage" => false, "next" => next, "posts" => posts} = json
    assert to_string(post6.id) in Enum.map(posts, &(&1["id"]))
    assert to_string(post5.id) in Enum.map(posts, &(&1["id"]))
    assert to_string(post4.id) in Enum.map(posts, &(&1["id"]))

    resp2 = post_graphql(%{query: @query, variables: %{
      "before" => next,
      "kind" => "RECENT",
      "perPage" => 3,
    }})
    assert %{"data" => %{"globalPostStream" => json2}} = json_response(resp2)
    assert %{"isLastPage" => false, "next" => next2, "posts" => posts2} = json2
    assert to_string(post3.id) in Enum.map(posts2, &(&1["id"]))
    assert to_string(post2.id) in Enum.map(posts2, &(&1["id"]))
    assert to_string(post1.id) in Enum.map(posts2, &(&1["id"]))

    resp3 = post_graphql(%{query: @query, variables: %{
      "before" => next2,
      "kind" => "RECENT",
      "perPage" => 3,
    }})
    assert %{"data" => %{"globalPostStream" => json3}} = json_response(resp3)
    assert %{"isLastPage" => true, "posts" => []} = json3
  end

  test "Shop stream", %{} do
    user = Factory.insert(:user)
    post1 = Factory.add_assets(Factory.insert(:post))
    post2 = Factory.insert(:post, is_saleable: true)
    post3 = Factory.insert(:post, has_nudity: true, is_saleable: true)
    post4 = Factory.insert(:post, is_saleable: true)
    post5 = Factory.insert(:post, is_saleable: true)
    post6 = Factory.insert(:post, has_nudity: true, is_saleable: true)
    Factory.insert(:love, post: post1, user: user)
    key = Stream.key(:global_shop)
    roshi_items = [
      %Item{id: "#{post1.id}", stream_id: key, ts: DateTime.utc_now},
      %Item{id: "#{post2.id}", stream_id: key, ts: DateTime.utc_now},
      %Item{id: "#{post3.id}", stream_id: key, ts: DateTime.utc_now},
      %Item{id: "#{post4.id}", stream_id: key, ts: DateTime.utc_now},
      %Item{id: "#{post5.id}", stream_id: key, ts: DateTime.utc_now},
      %Item{id: "#{post6.id}", stream_id: key, ts: DateTime.utc_now},
    ]
    Stream.Client.add_items(roshi_items)

    resp = post_graphql(%{query: @query, variables: %{"kind" => "SHOP", "perPage" => 3}})
    assert %{"data" => %{"globalPostStream" => json}} = json_response(resp)
    assert %{"isLastPage" => false, "next" => next, "posts" => posts} = json
    assert to_string(post6.id) in Enum.map(posts, &(&1["id"]))
    assert to_string(post5.id) in Enum.map(posts, &(&1["id"]))
    assert to_string(post4.id) in Enum.map(posts, &(&1["id"]))

    resp2 = post_graphql(%{query: @query, variables: %{
      "before" => next,
      "kind" => "SHOP",
      "perPage" => 3,
    }})
    assert %{"data" => %{"globalPostStream" => json2}} = json_response(resp2)
    assert %{"isLastPage" => false, "next" => next2, "posts" => posts2} = json2
    assert to_string(post3.id) in Enum.map(posts2, &(&1["id"]))
    assert to_string(post2.id) in Enum.map(posts2, &(&1["id"]))
    assert to_string(post1.id) in Enum.map(posts2, &(&1["id"]))

    resp3 = post_graphql(%{query: @query, variables: %{
      "before" => next2,
      "kind" => "SHOP",
      "perPage" => 3,
    }})
    assert %{"data" => %{"globalPostStream" => json3}} = json_response(resp3)
    assert %{"isLastPage" => true, "posts" => []} = json3
  end


  test "Trending stream", _ do
    posts = Factory.insert_list(6, :post)
    Index.delete
    Index.create
    Enum.each(posts, &Index.add/1)

    resp = post_graphql(%{query: @query, variables: %{"kind" => "TRENDING", "perPage" => 3}})
    assert %{"data" => %{"globalPostStream" => json}} = json_response(resp)
    assert %{"isLastPage" => false, "next" => next, "posts" => [_p1, _p2, _p3]} = json

    resp2 = post_graphql(%{query: @query, variables: %{
      "before" => next,
      "kind" => "TRENDING",
      "perPage" => 3,
    }})
    assert %{"data" => %{"globalPostStream" => json2}} = json_response(resp2)
    assert %{"isLastPage" => true, "next" => nil, "posts" => [_p1, _p2, _p3]} = json2
  end

  test "Featured stream", _ do
    Stream.Client.Test.start
    Stream.Client.Test.reset

    cat1 = Factory.insert(:category, roshi_slug: "cat1", slug: "cat1", level: "primary")
    cat2 = Factory.insert(:category, roshi_slug: "cat2", slug: "cat2", level: "primary")
    inv1 = Factory.insert(:artist_invite, status: "open")
    inv2 = Factory.insert(:artist_invite, status: "open")
    inv3 = Factory.insert(:artist_invite, status: "closed")

    post1 = Factory.insert(:post)
    post2 = Factory.insert(:post)
    post3 = Factory.insert(:post, has_nudity: true)
    post4 = Factory.insert(:post)
    post5 = Factory.insert(:post)
    post6 = Factory.insert(:post, has_nudity: true)
    post7 = Factory.insert(:post)
    post8 = Factory.insert(:post, has_nudity: true)
    post9 = Factory.insert(:post)
    Factory.insert(:artist_invite_submission, post: post7, artist_invite: inv1)
    Factory.insert(:artist_invite_submission, post: post8, artist_invite: inv2)
    Factory.insert(:artist_invite_submission, post: post9, artist_invite: inv3)
    roshi_items = [
      %Item{id: "#{post1.id}", stream_id: Stream.key(cat1, :featured), ts: DateTime.utc_now},
      %Item{id: "#{post2.id}", stream_id: Stream.key(cat1, :featured), ts: DateTime.utc_now},
      %Item{id: "#{post3.id}", stream_id: Stream.key(cat1, :featured), ts: DateTime.utc_now},
      %Item{id: "#{post4.id}", stream_id: Stream.key(cat2, :featured), ts: DateTime.utc_now},
      %Item{id: "#{post5.id}", stream_id: Stream.key(cat2, :featured), ts: DateTime.utc_now},
      %Item{id: "#{post6.id}", stream_id: Stream.key(cat2, :featured), ts: DateTime.utc_now},
      %Item{id: "#{post7.id}", stream_id: Stream.key(inv1), ts: DateTime.utc_now},
      %Item{id: "#{post8.id}", stream_id: Stream.key(inv2), ts: DateTime.utc_now},
      %Item{id: "#{post9.id}", stream_id: Stream.key(inv3), ts: DateTime.utc_now},
    ]
    Stream.Client.add_items(roshi_items)

    resp = post_graphql(%{query: @query, variables: %{"kind" => "FEATURED", "perPage" => 6}})
    assert %{"data" => %{"globalPostStream" => json}} = json_response(resp)
    assert %{"isLastPage" => false, "next" => next, "posts" => [_p1, _p2, _p3, _p4, _p5, _p6]} = json

    resp2 = post_graphql(%{query: @query, variables: %{
      "before" => next,
      "kind" => "FEATURED",
      "perPage" => 6,
    }})
    assert %{"data" => %{"globalPostStream" => json2}} = json_response(resp2)
    assert %{"isLastPage" => true, "next" => _, "posts" => [_p1, _p2]} = json2
  end
end
