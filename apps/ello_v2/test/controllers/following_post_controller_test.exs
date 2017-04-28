defmodule Ello.V2.FollowingPostControllerTest do
  use Ello.V2.ConnCase, async: false
  alias Ello.Core.Repo
  alias Ello.Stream
  alias Ello.Stream.Item
  alias Ello.Core.{Redis}

  setup %{conn: conn} do
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    Stream.Client.Test.start
    Stream.Client.Test.reset

    user = Factory.insert(:user)
    following_user = Factory.insert(:user)
    post = Factory.insert(:post, author: following_user)
    nudity_post = Factory.insert(:post, author: following_user, has_nudity: true)
    nsfw_post = Factory.insert(:post, author: following_user, is_adult_content: true)
    my_post = Factory.insert(:post, author: user)
    Factory.insert(:love, post: post, user: user)
    roshi_items = [
      %Item{id: "#{post.id}", stream_id: "#{following_user.id}", ts: DateTime.utc_now},
      %Item{id: "#{my_post.id}", stream_id: "#{user.id}", ts: DateTime.utc_now},
      %Item{id: "#{nudity_post.id}", stream_id: "#{following_user.id}", ts: DateTime.utc_now},
      %Item{id: "#{nsfw_post.id}", stream_id: "#{following_user.id}", ts: DateTime.utc_now},
    ]
    Stream.Client.add_items(roshi_items)

    redis_key = "user:#{user.id}:followed_users_id_cache"
    Redis.command(["SADD", redis_key, following_user.id])

    on_exit fn ->
      Redis.command(["DEL", redis_key])
    end

    {:ok, [
        conn: auth_conn(conn, user),
        unauth_conn: conn,
        user: user,
        post: post,
        my_post: my_post,
        nudity_post: nudity_post,
        nsfw_post: nsfw_post,
    ]}
  end

  test "GET /v2/following/posts/recent", %{conn: conn, post: post, my_post: my_post, nsfw_post: nsfw_post, nudity_post: nudity_post} do
    response = conn
               |> assign(:allow_nsfw, true)
               |> assign(:allow_nudity, true)
               |> get(following_post_path(conn, :index))
    assert response.status == 200
    json = json_response(response, 200)
    returned_ids = Enum.map(json["posts"], &(String.to_integer(&1["id"])))
    assert post.id in returned_ids
    assert my_post.id in returned_ids
    assert nsfw_post.id in returned_ids
    assert nudity_post.id in returned_ids
    assert Enum.find(json["posts"], &(&1["id"] == "#{post.id}"))["loved"]
  end

  test "GET /v2/following/posts/recent - fails for unauth requests", %{unauth_conn: conn} do
    response = get(conn, following_post_path(conn, :index))
    assert response.status == 401
  end

  test "GET /v2/following/posts/recent - nsfw filtered", %{conn: conn, post: post, my_post: my_post, nsfw_post: nsfw_post, nudity_post: nudity_post} do
    response = conn
               |> assign(:allow_nsfw, false)
               |> assign(:allow_nudity, true)
               |> get(following_post_path(conn, :index))
    assert response.status == 200
    json = json_response(response, 200)
    returned_ids = Enum.map(json["posts"], &(String.to_integer(&1["id"])))
    assert post.id in returned_ids
    assert my_post.id in returned_ids
    refute nsfw_post.id in returned_ids
    assert nudity_post.id in returned_ids
  end

  test "GET /v2/following/posts/recent - nudity filtered", %{conn: conn, post: post, my_post: my_post, nsfw_post: nsfw_post, nudity_post: nudity_post} do
    response = conn
               |> assign(:allow_nsfw, false)
               |> assign(:allow_nudity, false)
               |> get(following_post_path(conn, :index))
    assert response.status == 200
    json = json_response(response, 200)
    returned_ids = Enum.map(json["posts"], &(String.to_integer(&1["id"])))
    assert post.id in returned_ids
    assert my_post.id in returned_ids
    refute nsfw_post.id in returned_ids
    refute nudity_post.id in returned_ids
  end

  @tag :json_schema
  test "GET /v2/following/posts/recent - json schema", %{conn: conn} do
    conn = get(conn, following_post_path(conn, :index))
    assert :ok = validate_json("post", json_response(conn, 200))
  end

end