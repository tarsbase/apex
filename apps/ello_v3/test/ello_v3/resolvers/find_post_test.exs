defmodule Ello.V3.Resolvers.FindPostTest do
  use Ello.V3.Case

  setup do
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})

    cat1 = Script.insert(:lacross_category)
    staff = Factory.insert(:user, is_staff: true)
    user = Factory.insert(:user)
    post = Factory.insert(:post, author: user)
    Factory.insert(:featured_category_post, %{
      post: post,
      category: cat1,
      featured_at: DateTime.utc_now,
      featured_by: Factory.insert(:user, username: "Curator McCurator"),
    })
    reposter = Factory.insert(:user)
    a_inv = Factory.insert(:artist_invite, %{id: 1, status: "closed", brand_account: reposter})
    Factory.insert(:artist_invite_submission, post: post, artist_invite: a_inv, status: "approved")
    repost = Factory.insert(:post, reposted_source: post, author: reposter)
    Factory.insert(:category_post, post: repost, category: cat1, submitted_at: DateTime.utc_now)
    Factory.insert(:artist_invite_submission, post: repost, artist_invite: a_inv, status: "approved")
    {:ok, %{user: user, staff: staff, post: post, repost: repost, reposter: reposter}}
  end

  @fragment_query """
    fragment imageVersionProps on Image {
      url
      metadata { height width type size }
    }

    fragment avatarImageVersion on TshirtImageVersions {
      small { ...imageVersionProps }
      regular { ...imageVersionProps }
      large { ...imageVersionProps }
      original { ...imageVersionProps }
    }

    fragment authorSummary on User {
      id
      username
      name
      currentUserState { relationshipPriority }
      avatar {
        ...avatarImageVersion
      }
    }

    fragment contentProps on ContentBlocks {
      linkUrl
      kind
      data
      links { assets }
    }

    fragment artistInviteSubmissionAction on ArtistInviteSubmissionAction {
      href label method body { status }
    }

    fragment artistInviteSubmissionDetails on ArtistInviteSubmission {
      id
      status
      artistInvite { id slug title }
      actions {
        approve { ...artistInviteSubmissionAction }
        decline { ...artistInviteSubmissionAction }
        select { ...artistInviteSubmissionAction }
        unapprove { ...artistInviteSubmissionAction }
        unselect { ...artistInviteSubmissionAction }
      }
    }

    fragment categoryPostDetails on CategoryPost {
      id
      status
      category { id slug name }
      submitted_at
      submitted_by { username }
      featured_at
      featured_by { username }
      unfeatured_at
      removed_at
      actions {
        feature { href method }
        unfeature { href method }
      }
    }

    fragment postSummary on Post {
      id
      token
      createdAt
      summary { ...contentProps }
      author { ...authorSummary }
      assets {
        id
        attachment {
          hdpi {
            url
          }
        }
      }
      postStats { lovesCount commentsCount viewsCount repostsCount }
      currentUserState { watching loved reposted }
      artistInviteSubmission { ...artistInviteSubmissionDetails }
      categoryPosts { ...categoryPostDetails }
    }

    query($username: String!, $token: String!) {
      post(username: $username, token: $token) {
        ...postSummary
        repostedSource {
          ...postSummary
        }
      }
    }
  """

  test "Abbreviated post representation", %{user: user, post: post} do
    query = """
      query($username: String!, $token: String!) {
        post(username: $username, token: $token) {
          id
          token
          createdAt
          summary {
            link_url
            kind
            data
          }
        }
      }
    """

    resp = post_graphql(%{query: query, variables: %{username: user.username, token: post.token}})
    assert %{"data" => %{"post" => json}} = json_response(resp)
    assert json["id"] == "#{post.id}"
    assert json["token"] == "#{post.token}"
    assert json["createdAt"] == DateTime.to_iso8601(post.created_at)
    assert json["summary"] == post.rendered_summary
  end

  test "Abbreviated post representation - by id", %{post: post} do
    query = """
      query($id: ID!) {
        post(id: $id) {
          id
          token
          createdAt
          summary {
            link_url
            kind
            data
          }
        }
      }
    """

    resp = post_graphql(%{query: query, variables: %{id: post.id}})
    assert %{"data" => %{"post" => json}} = json_response(resp)
    assert json["id"] == "#{post.id}"
    assert json["token"] == "#{post.token}"
    assert json["createdAt"] == DateTime.to_iso8601(post.created_at)
    assert json["summary"] == post.rendered_summary
  end

  test "Abbreviated post representation - wrong username", %{post: post} do
    query = """
      query($username: String!, $token: String!) {
        post(username: $username, token: $token) {
          id
          token
          createdAt
          summary {
            link_url
            kind
            data
          }
        }
      }
    """

    resp = post_graphql(%{query: query, variables: %{username: "nope", token: post.token}})
    assert %{"errors" => [%{"message" => "Post not found"}]} = json_response(resp)
  end

  test "Abbreviated post representation - no username", %{post: post} do
    query = """
      query($token: String!) {
        post(token: $token) {
          id
          token
          createdAt
          summary {
            link_url
            kind
            data
          }
        }
      }
    """

    resp = post_graphql(%{query: query, variables: %{token: post.token}})
    assert %{"data" => %{"post" => json}} = json_response(resp)
    assert json["id"] == "#{post.id}"
    assert json["token"] == "#{post.token}"
    assert json["createdAt"] == DateTime.to_iso8601(post.created_at)
    assert json["summary"] == post.rendered_summary
  end

  test "Full post representation with a repost", %{user: user, post: post, repost: repost, reposter: reposter} do
    query = """
      query($username: String!, $token: String!) {
        post(username: $username, token: $token) {
          id
          token
          createdAt
          artistInviteSubmission {
            id
            status
            artistInvite {
              id
              slug
              title
            }
            actions {
              approve { href label method body { status } }
              decline { href label method body { status } }
              select  { href label method body { status } }
              unapprove { href label method body { status } }
              unselect { href label method body { status } }
            }
          }
          categories {
            id
            slug
            tile_image {
              small {
                url
                metadata {
                  width
                  height
                  size
                  type
                }
              }
            }
          }
          assets {
            id
            attachment {
              hdpi {
                metadata {
                  width
                  height
                  size
                  type
                }
                url
              }
            }
          }
          author {
            id
            username
            currentUserState { relationshipPriority }
          }
          repostContent {
            linkUrl
            kind
            data
            links {
              assets
            }
          }
          summary {
            linkUrl
            kind
            data
            links {
              assets
            }
          }
          content {
            linkUrl
            kind
            data
            links {
              assets
            }
          }
          postStats {
            lovesCount
            viewsCount
            commentsCount
            repostsCount
          }
          currentUserState {
            loved
            reposted
            watching
          }
          repostedSource {
            id
            token
            createdAt
            summary {
              linkUrl
              kind
              data
              links {
                assets
              }
            }
            content {
              linkUrl
              kind
              data
              links {
                assets
              }
            }
            author {
              id
              username
              currentUserState { relationshipPriority }
            }
            postStats {
              lovesCount
              viewsCount
              commentsCount
              repostsCount
            }
            currentUserState {
              loved
              reposted
              watching
            }
            artistInviteSubmission {
              id
              status
              artistInvite {
                id
                slug
                title
              }
              actions {
                approve { href label method body { status } }
                decline { href label method body { status } }
                select  { href label method body { status } }
                unapprove { href label method body { status } }
                unselect { href label method body { status } }
              }
            }
          }
        }
      }
    """
    Factory.insert(:relationship, owner: user, subject: reposter, priority: "friend")
    resp = post_graphql(%{query: query, variables: %{username: reposter.username, token: repost.token}}, user)
    assert %{"data" => %{"post" => json}} = json_response(resp)

    assert json["id"] == "#{repost.id}"
    assert json["author"]["id"] == "#{reposter.id}"
    assert json["author"]["currentUserState"]["relationshipPriority"] == "friend"
    assert hd(json["summary"])["kind"] == "text"
    assert hd(json["summary"])["data"] == "<p>Phrasing!</p>"
    assert json["postStats"]["lovesCount"] == 0
    assert json["postStats"]["viewsCount"] == 0
    assert json["postStats"]["commentsCount"] == 0
    assert json["postStats"]["repostsCount"] == 0
    assert json["currentUserState"]["reposted"] == false
    assert json["currentUserState"]["loved"] == false
    assert json["currentUserState"]["watching"] == false
    refute json["artist_invite_submission"]


    assert json["repostedSource"]["id"] == "#{post.id}"
    assert json["repostedSource"]["author"]["id"] == "#{user.id}"
    assert json["repostedSource"]["author"]["currentUserState"]["relationshipPriority"] == "self"
    assert hd(json["repostedSource"]["summary"])["data"] == "<p>Phrasing!</p>"
    assert hd(json["repostedSource"]["summary"])["kind"] == "text"
    assert json["repostedSource"]["postStats"]["lovesCount"] == 0
    assert json["repostedSource"]["postStats"]["viewsCount"] == 0
    assert json["repostedSource"]["postStats"]["commentsCount"] == 0
    assert json["repostedSource"]["postStats"]["repostsCount"] == 0
    assert json["repostedSource"]["currentUserState"]["reposted"] == false
    assert json["repostedSource"]["currentUserState"]["loved"] == false
    assert json["repostedSource"]["currentUserState"]["watching"] == false

    refute json["repostedSource"]["artistInviteSubmission"]["actions"]
  end

  test "Full post representation via fragments with a repost as staff", %{
    staff: staff,
    user: user,
    post: post,
    repost: repost,
    reposter: reposter
  } do
    Factory.insert(:relationship, owner: staff, subject: user, priority: "friend")
    resp = post_graphql(%{query: @fragment_query, variables: %{
      username: reposter.username,
      token: repost.token
    }}, staff)
    assert %{"data" => %{"post" => json}} = json_response(resp)
    assert json["id"] == "#{repost.id}"
    assert json["author"]["id"] == "#{reposter.id}"
    refute json["author"]["currentUserState"]["relationshipPriority"]
    actions = json["artistInviteSubmission"]["actions"]
    assert %{"body" => %{}, "href" => _, "method" => _, "label" => _} = actions["select"]
    assert %{"body" => %{}, "href" => _, "method" => _, "label" => _} = actions["unapprove"]
    refute actions["decline"]
    refute actions["unselect"]
    refute actions["approve"]

    assert [category_post] = json["categoryPosts"]
    assert category_post["id"]
    assert category_post["status"] == "submitted"
    assert category_post["submitted_at"]

    assert json["repostedSource"]["id"] == "#{post.id}"
    assert json["repostedSource"]["author"]["id"] == "#{user.id}"
    assert json["repostedSource"]["author"]["currentUserState"]["relationshipPriority"] == "friend"

    actions = json["repostedSource"]["artistInviteSubmission"]["actions"]
    assert %{"body" => %{}, "href" => _, "method" => _, "label" => _} = actions["select"]
    assert %{"body" => %{}, "href" => _, "method" => _, "label" => _} = actions["unapprove"]
    refute actions["decline"]
    refute actions["unselect"]
    refute actions["approve"]

    assert [category_post] = json["repostedSource"]["categoryPosts"]
    assert category_post["id"]
    assert category_post["submitted_at"]
    assert category_post["featured_at"]
    assert category_post["featured_by"]["username"] == "Curator McCurator"
    assert category_post["status"] == "featured"
  end

  test "Full post representation via fragments with a repost as artist invite brand account", %{
    user: user,
    post: post,
    repost: repost,
    reposter: reposter,
  } do
    Factory.insert(:relationship, owner: reposter, subject: user, priority: "friend")
    resp = post_graphql(%{query: @fragment_query, variables: %{
      username: reposter.username,
      token: repost.token,
    }}, reposter)
    assert %{"data" => %{"post" => json}} = json_response(resp)
    assert json["id"] == "#{repost.id}"
    assert json["author"]["id"] == "#{reposter.id}"
    actions = json["artistInviteSubmission"]["actions"]
    assert %{"body" => %{}, "href" => _, "method" => _, "label" => _} = actions["select"]
    assert %{"body" => %{}, "href" => _, "method" => _, "label" => _} = actions["unapprove"]
    refute actions["decline"]
    refute actions["unselect"]
    refute actions["approve"]

    assert [category_post] = json["categoryPosts"]
    assert category_post["id"]
    assert category_post["status"] == "submitted"
    assert category_post["submitted_at"]
    refute category_post["actions"]

    assert json["repostedSource"]["id"] == "#{post.id}"
    actions = json["repostedSource"]["artistInviteSubmission"]["actions"]
    assert %{"body" => %{}, "href" => _, "method" => _, "label" => _} = actions["select"]
    assert %{"body" => %{}, "href" => _, "method" => _, "label" => _} = actions["unapprove"]
    refute actions["decline"]
    refute actions["unselect"]
    refute actions["approve"]

    assert [category_post] = json["repostedSource"]["categoryPosts"]
    assert category_post["status"] == "featured"
    refute category_post["actions"]
  end
end
