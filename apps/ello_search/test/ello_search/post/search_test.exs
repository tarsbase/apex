defmodule Ello.Search.Post.SearchTest do
  use Ello.Search.Case
  alias Ello.Search.Post.{Index, Search}
  alias Ello.Core.{Repo, Factory, Network}

  setup do
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    cat1         = Factory.insert(:category, id: 1)
    cat10        = Factory.insert(:category, id: 10)
    cat100       = Factory.insert(:category, id: 100)
    current_user = Factory.insert(:user)
    post         = Factory.insert(:post)
    Factory.insert(:category_post, post: post, category: cat1)
    Factory.insert(:category_post, post: post, category: cat100)
    irrel_post   = Factory.insert(:post, %{body: [%{"data" => "Irrelevant post!", "kind" => "text"}]})
    comment      = Factory.insert(:comment)
    repost       = Factory.insert(:repost)
    flagged_post = Factory.insert(:post)
    nsfw_post    = Factory.insert(:post, %{is_adult_content: true})
    nudity_post  = Factory.insert(:post, %{has_nudity: true})
    Factory.insert(:category_post, post: nudity_post, category: cat1)
    private_user = Factory.insert(:user, %{is_public: false})
    private_post = Factory.insert(:post, %{author: private_user})
    locked_user  = Factory.insert(:user, %{locked_at: DateTime.utc_now})
    locked_post  = Factory.insert(:post, %{author: locked_user})
    spam_post    = Factory.insert(:post)
    hashtag_post = Factory.insert(:post, %{body: [%{"data" => "#phrasing", "kind" => "text"}]})
    mention_post = Factory.insert(:post, %{body: [%{"data" => "@archer", "kind" => "text"}]})
    badman_post  = Factory.insert(:post, %{body: [%{"data" => "This is a bad, bad man.", "kind" => "text"}]})
    stopword_post = Factory.insert(:post, %{body: [%{"data" => "asshole #ass", "kind" => "text"}]})
    irrel_post2  = Factory.insert(:post, %{body: [%{"data" => "Irrelevantpost!", "kind" => "text"}]})
    nfp          = Factory.insert(:post, %{body: [%{"data" => "not for print is finally here!", "kind" => "text"}, %{"kind" => "image", "date" => %{"url" => "doesntmatter"}}]})
    not_nfp      = Factory.insert(:post, %{body: [%{"data" => "not my print for ello", "kind" => "text"}]})

    Index.delete
    Index.create
    Index.add(post)
    Index.add(irrel_post)
    Index.add(comment)
    Index.add(repost)
    Index.add(flagged_post, %{post: %{is_hidden: true}})
    Index.add(nsfw_post)
    Index.add(nudity_post)
    Index.add(private_post)
    Index.add(locked_post)
    Index.add(spam_post, %{author: %{is_spammer: true}})
    Index.add(stopword_post)
    Index.add(irrel_post2)
    Index.add(nfp)
    Index.add(not_nfp)

    {:ok,
      current_user: current_user,
      cat1: cat1,
      cat10: cat10,
      cat100: cat100,
      post: post,
      irrel_post: irrel_post,
      comment: comment,
      repost: repost,
      flagged_post: flagged_post,
      nsfw_post: nsfw_post,
      nudity_post: nudity_post,
      private_post: private_post,
      private_user: private_user,
      locked_post: locked_post,
      spam_post: spam_post,
      hashtag_post: hashtag_post,
      mention_post: mention_post,
      badman_post: badman_post,
      stopword_post: stopword_post,
      irrel_post2: irrel_post2,
      nfp: nfp,
      not_nfp: not_nfp,
    }
  end

  test "post_search - returns empty result when nothing relevant", _context do
    search = Search.post_search(%{
      terms: "notactualyincludinganywhere",
      current_user: nil,
      allow_nsfw: false,
      allow_nudity: false
    })
    assert search.results == []
  end

  test "post_search - returns relevant results", context do
    results = Search.post_search(%{terms: "Phrasing", current_user: nil, allow_nsfw: false, allow_nudity: false}).results
    assert context.post.id in Enum.map(results, &(&1.id))
  end

  test "post_search - does not return irrelevant results", context do
    results = Search.post_search(%{terms: "Phrasing", current_user: nil, allow_nsfw: false, allow_nudity: false}).results
    refute context.irrel_post.id in Enum.map(results, &(&1.id))
  end

  test "post_search - does not return comments", context do
    results = Search.post_search(%{terms: "Phrasing", current_user: nil, allow_nsfw: false, allow_nudity: false}).results
    refute context.comment.id in Enum.map(results, &(&1.id))
  end

  test "post_search - does not return flagged (hidden) posts", context do
    results = Search.post_search(%{terms: "Phrasing", current_user: nil, allow_nsfw: false, allow_nudity: false}).results
    refute context.flagged_post.id in Enum.map(results, &(&1.id))
  end

  test "post_search - does not return nsfw posts if the client disallows", context do
    results = Search.post_search(%{terms: "Phrasing", current_user: nil, allow_nsfw: false, allow_nudity: false}).results
    refute context.nsfw_post.id in Enum.map(results, &(&1.id))
  end

  test "post_search - returns nsfw posts if the client allows", context do
    results = Search.post_search(%{terms: "Phrasing", current_user: nil, allow_nsfw: true, allow_nudity: false}).results
    assert context.nsfw_post.id in Enum.map(results, &(&1.id))
  end

  test "post_search - does not return nudity posts if the client disallows", context do
    results = Search.post_search(%{terms: "Phrasing", current_user: nil, allow_nsfw: false, allow_nudity: false}).results
    refute context.nudity_post.id in Enum.map(results, &(&1.id))
  end

  test "post_search - returns nudity posts if the client allows", context do
    results = Search.post_search(%{terms: "Phrasing", current_user: nil, allow_nsfw: false, allow_nudity: true}).results
    assert context.nudity_post.id in Enum.map(results, &(&1.id))
  end

  test "post_search - does not return posts with a private author if no current_user", context do
    results = Search.post_search(%{terms: "Phrasing", current_user: nil, allow_nsfw: false, allow_nudity: false}).results
    refute context.private_post.id in Enum.map(results, &(&1.id))
  end

  test "post_search - does not return posts with a locked author", context do
    results = Search.post_search(%{terms: "Phrasing", current_user: nil, allow_nsfw: false, allow_nudity: false}).results
    refute context.locked_post.id in Enum.map(results, &(&1.id))
  end

  test "post_search - does not return posts with a spam author", context do
    results = Search.post_search(%{terms: "Phrasing", current_user: nil, allow_nsfw: false, allow_nudity: false}).results
    refute context.spam_post.id in Enum.map(results, &(&1.id))
  end

  test "post_search - paginates successfully", _ do
    results = Search.post_search(%{terms: "Phrasing", allow_nsfw: true, allow_nudity: true, current_user: nil}).results
    assert length(Enum.map(results, &(&1.id))) == 3

    results = Search.post_search(%{terms: "Phrasing", allow_nsfw: true, allow_nudity: true, current_user: nil, per_page: 2}).results
    assert length(Enum.map(results, &(&1.id))) == 2

    results = Search.post_search(%{terms: "Phrasing", allow_nsfw: true, allow_nudity: true, current_user: nil, page: 2, per_page: 2}).results
    assert length(Enum.map(results, &(&1.id))) == 1

    results = Search.post_search(%{terms: "Phrasing", allow_nsfw: true, allow_nudity: true, current_user: nil, page: 3, per_page: 2}).results
    assert Enum.empty?(results)
  end

  test "post_search - returns hashtag posts and non-hashtag posts", context do
    Index.add(context.hashtag_post)
    results = Search.post_search(%{terms: "phrasing", current_user: nil, allow_nsfw: false, allow_nudity: false}).results
    assert context.hashtag_post.id in Enum.map(results, &(&1.id))
    assert context.post.id in Enum.map(results, &(&1.id))
    assert length(Enum.map(results, &(&1.id))) == 2
  end

  test "post_search - returns only hashtag posts", context do
    Index.add(context.hashtag_post)
    results = Search.post_search(%{terms: "#phrasing", current_user: nil, allow_nsfw: false, allow_nudity: false}).results
    assert hd(results).id == context.hashtag_post.id
    refute context.post.id in Enum.map(results, &(&1.id))
    assert length(Enum.map(results, &(&1.id))) == 1
  end

  test "post_search - matches on mentions", context do
    Index.add(context.mention_post)
    results = Search.post_search(%{terms: "@archer", current_user: nil, allow_nsfw: false, allow_nudity: false}).results
    assert hd(results).id == context.mention_post.id
    assert length(Enum.map(results, &(&1.id))) == 1
  end

  test "post_search - handles encoded terms correctly", context do
    Index.add(context.badman_post)
    results = Search.post_search(%{terms: "bad%20AND%20man%20", current_user: nil, allow_nsfw: false, allow_nudity: false}).results
    assert hd(results).id == context.badman_post.id
    assert length(Enum.map(results, &(&1.id))) == 1
  end

  test "post_search - does not throw exceptions when logic operators end the terms", context do
    Index.add(context.badman_post)
    results = Search.post_search(%{terms: "bad%20%20%20AND%20%20%20", current_user: nil, allow_nsfw: false, allow_nudity: false}).results
    assert hd(results).id == context.badman_post.id
    assert length(Enum.map(results, &(&1.id))) == 1
  end

  test "post_search - does not include blocked users", context do
    Redis.command(["SADD", "user:#{context.current_user.id}:block_id_cache", context.private_user.id])
    current_user = Network.User.preload_blocked_ids(context.current_user)

    results = Search.post_search(%{terms: "phrasing", allow_nsfw: false, allow_nudity: false, current_user: current_user}).results
    refute context.private_post.id in Enum.map(results, &(&1.id))
    assert context.post.id in Enum.map(results, &(&1.id))
  end

  test "post_search - does not include inverse blocked users", context do
    Redis.command(["SADD", "user:#{context.current_user.id}:inverse_block_id_cache", context.private_user.id])
    current_user = Network.User.preload_blocked_ids(context.current_user)

    results = Search.post_search(%{terms: "phrasing", allow_nsfw: false, allow_nudity: false, current_user: current_user}).results
    refute context.private_post.id in Enum.map(results, &(&1.id))
    assert context.post.id in Enum.map(results, &(&1.id))
  end

  test "post_search - does not include results with stopwords if client disallows", context do
    results = Search.post_search(%{terms: "asshole", webapp: true, allow_nsfw: false, allow_nudity: false, current_user: context.current_user}).results
    refute context.stopword_post.id in Enum.map(results, &(&1.id))
  end

  test "post_search - does not include hashtag results with stopwords if client disallows", context do
    results = Search.post_search(%{terms: "#ass", webapp: true, allow_nsfw: false, allow_nudity: false, current_user: context.current_user}).results
    refute context.stopword_post.id in Enum.map(results, &(&1.id))
  end

  test "post_search - includes results with stopwords if client allows", context do
    results = Search.post_search(%{terms: "asshole", webapp: true, allow_nsfw: true, allow_nudity: false, current_user: context.current_user}).results
    assert context.stopword_post.id in Enum.map(results, &(&1.id))
  end

  test "post_search - includes hashtag results with stopwords if client allows", context do
    results = Search.post_search(%{terms: "#ass", webapp: true, allow_nsfw: true, allow_nudity: false, current_user: context.current_user}).results
    assert context.stopword_post.id in Enum.map(results, &(&1.id))
  end

  test "post_search - exact phrase results for quotation searches", context do
    results = Search.post_search(%{terms: ~s("irrelevant post"), allow_nsfw: true, allow_nudity: true, current_user: context.current_user}).results
    assert context.irrel_post.id in Enum.map(results, &(&1.id))
    refute context.irrel_post2.id in Enum.map(results, &(&1.id))
  end

  test "post_search - NFP test - exact phrase results for quotation searches", context do
    results = Search.post_search(%{terms: ~s("not for print"), allow_nsfw: true, allow_nudity: true, current_user: context.current_user}).results
    assert context.nfp.id in Enum.map(results, &(&1.id))
    refute context.not_nfp.id in Enum.map(results, &(&1.id))
  end

  test "trending - returns a relevant result", context do
    results = Search.post_search(%{trending: true, current_user: nil, allow_nsfw: false, allow_nudity: false}).results
    assert context.irrel_post.id in Enum.map(results, &(&1.id))
    assert context.post.id in Enum.map(results, &(&1.id))
  end

  test "trending - does not return comments", context do
    results = Search.post_search(%{trending: true, current_user: nil, allow_nsfw: false, allow_nudity: false}).results
    refute context.comment.id in Enum.map(results, &(&1.id))
  end

  test "trending - does not return flagged (hidden) posts", context do
    results = Search.post_search(%{trending: true, current_user: nil, allow_nsfw: false, allow_nudity: false}).results
    refute context.flagged_post.id in Enum.map(results, &(&1.id))
  end

  test "trending - does not return nsfw posts if the client disallows", context do
    results = Search.post_search(%{trending: true, current_user: nil, allow_nsfw: false, allow_nudity: false}).results
    refute context.nsfw_post.id in Enum.map(results, &(&1.id))
  end

  test "trending - returns nsfw posts if the client allows", context do
    results = Search.post_search(%{trending: true, current_user: nil, allow_nsfw: true, allow_nudity: false}).results
    assert context.nsfw_post.id in Enum.map(results, &(&1.id))
  end

  test "trending - does not return nudity posts if the client disallows", context do
    results = Search.post_search(%{trending: true, current_user: nil, allow_nsfw: false, allow_nudity: false}).results
    refute context.nudity_post.id in Enum.map(results, &(&1.id))
  end

  test "trending - returns nudity posts if the client allows", context do
    results = Search.post_search(%{trending: true, current_user: nil, allow_nsfw: false, allow_nudity: true}).results
    assert context.nudity_post.id in Enum.map(results, &(&1.id))
  end

  test "trending - does not return posts with a private author if no current_user", context do
    results = Search.post_search(%{trending: true, current_user: nil, allow_nsfw: false, allow_nudity: false}).results
    refute context.private_post.id in Enum.map(results, &(&1.id))
  end

  test "trending - returns private posts if there is a current_user", context do
    results = Search.post_search(%{trending: true, current_user: context.current_user, allow_nsfw: false, allow_nudity: false}).results
    assert context.private_post.id in Enum.map(results, &(&1.id))
  end

  test "trending - does not return posts with a locked author", context do
    results = Search.post_search(%{trending: true, current_user: nil, allow_nsfw: false, allow_nudity: false}).results
    refute context.locked_post.id in Enum.map(results, &(&1.id))
  end

  test "trending - does not return posts with a spam author", context do
    results = Search.post_search(%{trending: true, current_user: nil, allow_nsfw: false, allow_nudity: false}).results
    refute context.spam_post.id in Enum.map(results, &(&1.id))
  end

  test "trending - does not include blocked users", context do
    Redis.command(["SADD", "user:#{context.current_user.id}:block_id_cache", context.private_user.id])
    current_user = Network.User.preload_blocked_ids(context.current_user)

    results = Search.post_search(%{trending: true, allow_nsfw: false, allow_nudity: false, current_user: current_user}).results
    refute context.private_post.id in Enum.map(results, &(&1.id))
  end

  test "trending - does not include inverse blocked users", context do
    Redis.command(["SADD", "user:#{context.current_user.id}:inverse_block_id_cache", context.private_user.id])
    current_user = Network.User.preload_blocked_ids(context.current_user)

    results = Search.post_search(%{trending: true, allow_nsfw: false, allow_nudity: false, current_user: current_user}).results
    refute context.private_post.id in Enum.map(results, &(&1.id))
  end

  test "category filtering - for search or trending", context do
    results = Search.post_search(%{
      trending:     true,
      allow_nsfw:   true,
      allow_nudity: true,
      current_user: context.current_user,
      category_ids: [context.cat1.id]
    }).results

    ids = Enum.map(results, &(&1.id))
    assert context.post.id in ids
    assert context.nudity_post.id in ids
    refute context.nsfw_post.id in ids
    refute context.private_post.id in ids

    results = Search.post_search(%{
      terms:        "Phrasing",
      allow_nsfw:   true,
      allow_nudity: true,
      current_user: context.current_user,
      category_ids: [context.cat100.id]
    }).results

    ids = Enum.map(results, &(&1.id))
    assert context.post.id in ids
    refute context.nudity_post.id in ids
    refute context.nsfw_post.id in ids
    refute context.private_post.id in ids
  end

  test "following filtering - for search or trending", context do
    Redis.command(["SADD", "user:#{context.current_user.id}:followed_users_id_cache", context.post.author_id])
    Redis.command(["SADD", "user:#{context.current_user.id}:followed_users_id_cache", context.nudity_post.author_id])

    results = Search.post_search(%{
      trending:     true,
      allow_nsfw:   true,
      allow_nudity: true,
      current_user: context.current_user,
      following:    true
    }).results

    Redis.command(["DEL", "user:#{context.current_user.id}:followed_users_id_cache"])
    ids = Enum.map(results, &(&1.id))
    assert context.post.id in ids
    assert context.nudity_post.id in ids
    refute context.nsfw_post.id in ids
    refute context.private_post.id in ids
  end

  test "image only filtering - for search or trending", context do
    results = Search.post_search(%{
      terms:        "print",
      allow_nsfw:   true,
      allow_nudity: true,
      current_user: context.current_user,
    }).results
    ids = Enum.map(results, &(&1.id))
    assert context.nfp.id in ids
    assert context.not_nfp.id in ids

    results = Search.post_search(%{
      terms:        "print",
      allow_nsfw:   true,
      allow_nudity: true,
      current_user: context.current_user,
      images_only:  true,
    }).results
    ids = Enum.map(results, &(&1.id))
    assert context.nfp.id in ids
    refute context.not_nfp.id in ids
  end
end
