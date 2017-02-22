defmodule Ello.V2.UserPostControllerTest do
  use Ello.V2.ConnCase, async: false
  alias Ello.Core.Repo

  setup %{conn: conn} do
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})

    user = Factory.insert(:user)
    author = Factory.insert(:user)
    {:ok, earlier_date} = DateTime.utc_now
                  |> DateTime.to_unix
                  |> Kernel.-(3600)
                  |> DateTime.from_unix
    posts = [
      Factory.insert(:post, %{author: author, created_at: earlier_date}),
      Factory.insert(:post, %{author: author, created_at: earlier_date}),
      Factory.insert(:post, %{author: author, created_at: earlier_date}),
      Factory.insert(:post, %{author: author, created_at: earlier_date}),
      Factory.insert(:post, %{author: author, created_at: earlier_date}),
      Factory.insert(:post, %{author: author, created_at: DateTime.utc_now}),
      Factory.insert(:post, %{author: author, created_at: DateTime.utc_now}),
      Factory.insert(:post, %{author: author, created_at: DateTime.utc_now}),
      Factory.insert(:post, %{author: author, created_at: DateTime.utc_now}),
    ]
    post = hd(posts)
    {:ok, conn: auth_conn(conn, user), user: user, author: author, posts: posts, post: post}
  end

  test "GET /v2/users/:id/posts", %{conn: conn, author: author} do
    conn = get(conn, user_post_path(conn, :index, author))
    assert conn.status == 200
  end

  test "GET /v2/users/:id/posts - returns page headers", %{conn: conn, author: author} do
    conn = get(conn, user_post_path(conn, :index, author), %{per_page: 2})
    assert get_resp_header(conn, "x-total-pages") == ["5"]
    assert get_resp_header(conn, "x-total-count") == ["9"]
    assert get_resp_header(conn, "x-total-pages-remaining") == ["5"]
  end

  test "GET /v2/users/:id/posts - returns page headers with before date", %{conn: conn, author: author} do
    {:ok, one_sec_ago} = DateTime.utc_now |> DateTime.to_unix |> Kernel.-(1) |> DateTime.from_unix
    %{
      year: year, month: month, day: day,
      hour: hour, minute: minute, second: second
    } = one_sec_ago

    year = String.pad_leading("#{year}", 2, "0")
    month = String.pad_leading("#{month}", 2, "0")
    day = String.pad_leading("#{day}", 2, "0")
    hour = String.pad_leading("#{hour}", 2, "0")
    minute = String.pad_leading("#{minute}", 2, "0")
    second = String.pad_leading("#{second}", 2, "0")

    before = "#{year}-#{month}-#{day}T#{hour}:#{minute}:#{second}Z"
    conn = get(conn, user_post_path(conn, :index, author), %{per_page: 2, before: before})
    assert get_resp_header(conn, "x-total-pages") == ["5"]
    assert get_resp_header(conn, "x-total-count") == ["9"]
    assert get_resp_header(conn, "x-total-pages-remaining") == ["3"]
  end

  test "GET /v2/users/:id/posts 404s", %{conn: conn} do
    conn = get(conn, user_post_path(conn, :index, "404"))
    assert conn.status == 404
  end

end
