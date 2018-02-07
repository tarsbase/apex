defmodule Ello.V3.Resolvers.FindPostTest do
  use Ello.V3.Case

  setup do
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})

    cat1 = Script.insert(:lacross_category)
    user = Factory.insert(:user)
    post = Factory.insert(:post, author: user)
    a_inv = Factory.insert(:artist_invite, %{id: 1, status: "closed"})
    Factory.insert(:artist_invite_submission, post: post, artist_invite: a_inv, status: "approved")
    reposter = Factory.insert(:user)
    repost = Factory.insert(:post, reposted_source: post, author: reposter, category_ids: [cat1.id])
    Factory.insert(:artist_invite_submission, post: repost, artist_invite: a_inv, status: "approved")
    {:ok, %{user: user, post: post, repost: repost, reposter: reposter}}
  end

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
            }
          }
        }
      }
    """

    resp = post_graphql(%{query: query, variables: %{username: reposter.username, token: repost.token}})
    assert %{"data" => %{"post" => json}} = json_response(resp)

    assert json["id"] == "#{repost.id}"
    assert json["author"]["id"] == "#{reposter.id}"
    assert hd(json["summary"])["kind"] == "text"
    assert hd(json["summary"])["data"] == "<p>Phrasing!</p>"
    assert json["postStats"]["lovesCount"] == 0
    assert json["postStats"]["viewsCount"] == 0
    assert json["postStats"]["commentsCount"] == 0
    assert json["postStats"]["repostsCount"] == 0
    assert json["currentUserState"]["reposted"] == false
    assert json["currentUserState"]["loved"] == false
    assert json["currentUserState"]["watching"] == false

    assert json["repostedSource"]["id"] == "#{post.id}"
    assert json["repostedSource"]["author"]["id"] == "#{user.id}"
    assert hd(json["repostedSource"]["summary"])["data"] == "<p>Phrasing!</p>"
    assert hd(json["repostedSource"]["summary"])["kind"] == "text"
    assert json["repostedSource"]["postStats"]["lovesCount"] == 0
    assert json["repostedSource"]["postStats"]["viewsCount"] == 0
    assert json["repostedSource"]["postStats"]["commentsCount"] == 0
    assert json["repostedSource"]["postStats"]["repostsCount"] == 0
    assert json["repostedSource"]["currentUserState"]["reposted"] == false
    assert json["repostedSource"]["currentUserState"]["loved"] == false
    assert json["repostedSource"]["currentUserState"]["watching"] == false
  end

  test "Full post representation via fragments with a repost", %{user: user, post: post, repost: repost, reposter: reposter} do
    fragment_query = """
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
    resp = post_graphql(%{query: fragment_query, variables: %{username: reposter.username, token: repost.token}})
    assert %{"data" => %{"post" => json}} = json_response(resp)
    assert json["id"] == "#{repost.id}"
    assert json["author"]["id"] == "#{reposter.id}"
    assert json["repostedSource"]["id"] == "#{post.id}"
    assert json["repostedSource"]["author"]["id"] == "#{user.id}"
  end
end
