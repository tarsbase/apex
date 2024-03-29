defmodule Ello.V2.ArtistInviteControllerTest do
  use Ello.V2.ConnCase, async: false

  setup %{conn: conn} do
    archer = Script.insert(:archer)
    brand  = Factory.insert(:user)
    staff  = Factory.insert(:user, %{is_staff: true})
    a_inv1 = Factory.insert(:artist_invite, %{status: "open"})
    a_inv2 = Factory.insert(:artist_invite, %{status: "preview"})
    a_inv3 = Factory.insert(:artist_invite, %{status: "preview", brand_account: brand})
    {:ok,
      unauth_conn: conn,
      conn: auth_conn(conn, archer),
      staff_conn: auth_conn(conn, staff),
      brand_conn: auth_conn(conn, brand),
      a_inv1: a_inv1,
      a_inv2: a_inv2,
      a_inv3: a_inv3,
    }
  end

  test "GET /v2/artist_invites - public token", %{unauth_conn: conn} do
    conn = conn
           |> public_conn
           |> get(artist_invite_path(conn, :index))
    assert conn.status == 200
  end

  test "GET /v2/artist_invites - user token", %{conn: conn} do
    conn = get(conn, artist_invite_path(conn, :index))
    assert conn.status == 200
  end

  @tag :json_schema
  test "GET /v2/artist_invites - json schema", %{conn: conn} do
    conn = get(conn, artist_invite_path(conn, :index))
    json_response(conn, 200)
    assert :ok = validate_json("artist_invite", json_response(conn, 200))
  end

  test "GET /v2/artist_invites - staff can preview artist invites", %{staff_conn: conn, a_inv1: a_inv1, a_inv2: a_inv2, a_inv3: a_inv3} do
    conn = get(conn, artist_invite_path(conn, :index), %{preview: "true"})

    assert %{"artist_invites" => artist_invites} = json_response(conn, 200)
    assert Enum.member?(artist_invite_ids(artist_invites), "#{a_inv1.id}")
    assert Enum.member?(artist_invite_ids(artist_invites), "#{a_inv2.id}")
    assert Enum.member?(artist_invite_ids(artist_invites), "#{a_inv3.id}")
  end


  test "GET /v2/artist_invites - pagination", %{staff_conn: conn, a_inv1: a_inv1, a_inv2: a_inv2, a_inv3: a_inv3} do
    resp = get(conn, artist_invite_path(conn, :index), %{
      preview:  "true",
      per_page: "2",
    })

    assert %{"artist_invites" => artist_invites} = json_response(resp, 200)
    refute Enum.member?(artist_invite_ids(artist_invites), "#{a_inv1.id}")
    assert Enum.member?(artist_invite_ids(artist_invites), "#{a_inv2.id}")
    assert Enum.member?(artist_invite_ids(artist_invites), "#{a_inv3.id}")

    [link] = get_resp_header(resp, "link")
    assert [_, "2"] = Regex.run(~r/page=([^&]*)&/, link)

    resp2 = get(conn, "/api/v2/artist_invites/", %{
      "preview"  => "true",
      "per_page" => "2",
      "page"     => "2",
    })

    assert %{"artist_invites" => artist_invites2} = json_response(resp2, 200)
    assert Enum.member?(artist_invite_ids(artist_invites2), "#{a_inv1.id}")
    refute Enum.member?(artist_invite_ids(artist_invites2), "#{a_inv2.id}")
    refute Enum.member?(artist_invite_ids(artist_invites2), "#{a_inv3.id}")
  end

  test "GET /v2/artist_invites - brand accounts can preview their own artist invite", %{brand_conn: conn, a_inv1: a_inv1, a_inv2: a_inv2, a_inv3: a_inv3} do
    conn = get(conn, artist_invite_path(conn, :index), %{preview: "true"})

    assert %{"artist_invites" => artist_invites} = json_response(conn, 200)
    assert Enum.member?(artist_invite_ids(artist_invites), "#{a_inv1.id}")
    refute Enum.member?(artist_invite_ids(artist_invites), "#{a_inv2.id}")
    assert Enum.member?(artist_invite_ids(artist_invites), "#{a_inv3.id}")
  end

  test "GET /v2/artist_invites - normal users can't preview artist invites", %{conn: conn, a_inv1: a_inv1, a_inv2: a_inv2, a_inv3: a_inv3} do
    conn = get(conn, artist_invite_path(conn, :index), %{preview: "true"})

    assert %{"artist_invites" => artist_invites} = json_response(conn, 200)
    assert Enum.member?(artist_invite_ids(artist_invites), "#{a_inv1.id}")
    refute Enum.member?(artist_invite_ids(artist_invites), "#{a_inv2.id}")
    refute Enum.member?(artist_invite_ids(artist_invites), "#{a_inv3.id}")
  end

  test "GET /v2/artist_invites/:slug - public token with slug", %{unauth_conn: conn, a_inv1: a_inv1} do
    conn = conn
           |> public_conn
           |> get(artist_invite_path(conn, :show, "~#{a_inv1.slug}"))
    assert conn.status == 200
  end

  test "GET /v2/artist_invites/:id - public token with id", %{unauth_conn: conn, a_inv1: a_inv1} do
    conn = conn
           |> public_conn
           |> get(artist_invite_path(conn, :show, a_inv1.id))
    assert conn.status == 200
  end

  test "GET /v2/artist_invites/:id - user token", %{conn: conn, a_inv1: a_inv1} do
    conn = get(conn, artist_invite_path(conn, :show, a_inv1.id))
    assert conn.status == 200
  end

  @tag :json_schema
  test "GET /v2/artist_invites/:slug - json schema", %{conn: conn, a_inv1: a_inv1} do
    conn = get(conn, artist_invite_path(conn, :show, a_inv1.id))
    json_response(conn, 200)
    assert :ok = validate_json("artist_invite", json_response(conn, 200))
  end


  test "GET /v2/artist_invites/:id - staff can see artist invites in preview", %{staff_conn: conn, a_inv2: a_inv2} do
    conn = get(conn, artist_invite_path(conn, :show, "~#{a_inv2.slug}"))
    assert conn.status == 200
  end

  test "GET /v2/artist_invites/:id - brand accounts can see their own artist invite in preview", %{brand_conn: conn, a_inv3: a_inv3} do
    conn = get(conn, artist_invite_path(conn, :show, "~#{a_inv3.slug}"))
    assert conn.status == 200
  end

  test "GET /v2/artist_invites/:id - brand accounts can't preview other artist invites", %{brand_conn: conn, a_inv2: a_inv2} do
    conn = get(conn, artist_invite_path(conn, :show, "~#{a_inv2.slug}"))
    assert conn.status == 404
  end

  test "GET /v2/artist_invites/:id - normal users can't view preview artist invites", %{conn: conn, a_inv2: a_inv2} do
    conn = get(conn, artist_invite_path(conn, :show, "~#{a_inv2.slug}"))
    assert conn.status == 404
  end

  defp artist_invite_ids(artist_invites),
    do: Enum.map(artist_invites, &(&1["id"]))
end
