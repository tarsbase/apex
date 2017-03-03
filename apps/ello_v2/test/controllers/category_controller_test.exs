defmodule Ello.V2.CategoryControllerTest do
  use Ello.V2.ConnCase

  setup %{conn: conn} do
    Script.insert(:featured_category)
    Script.insert(:lacross_category)
    spying = Script.insert(:espionage_category)
    archer = Script.insert(:archer, category_ids: [spying.id])
    {:ok, conn: auth_conn(conn, archer), unauth_conn: conn, spying: spying}
  end

  test "GET /v2/categories/:slug - without token", %{unauth_conn: conn} do
    conn = get(conn, category_path(conn, :show, "featured"))
    assert conn.status == 401
  end

  test "GET /v2/categories/:slug", %{conn: conn} do
    conn = get(conn, category_path(conn, :show, "featured"))
    assert %{"name" => "Featured"} = json_response(conn, 200)["categories"]
  end

  test "GET /v2/categories/:slug - 404", %{conn: conn} do
    conn = get(conn, category_path(conn, :show, "nopenopenope"))
    assert conn.status == 404
  end

  test "GET /v2/categories/:slug - 304", %{conn: conn} do
    resp = get(conn, category_path(conn, :show, "featured"))
    assert resp.status == 200
    [etag] = get_resp_header(resp, "etag")
    resp2 = conn
            |> put_req_header("if-none-match", etag)
            |> get(category_path(conn, :show, "featured"))
    assert resp2.status == 304
  end

  test "GET /v2/categories?all=true", %{conn: conn} do
    conn = get(conn, category_path(conn, :index), %{all: true})
    assert %{"categories" => categories} = json_response(conn, 200)
    assert Enum.member?(category_names(categories), "Lacross") == true
    assert Enum.member?(category_names(categories), "Featured") == true
    assert Enum.member?(category_names(categories), "Espionage") == true
  end

  test "GET /v2/categories?all=true - 304", %{conn: conn, spying: cat} do
    resp = get(conn, category_path(conn, :index), %{all: true})
    assert resp.status == 200
    [etag] = get_resp_header(resp, "etag")
    resp2 = conn
            |> put_req_header("if-none-match", etag)
            |> get(category_path(conn, :index), %{all: true})
    assert resp2.status == 304
    Factory.insert(:promotional, category: cat)
    resp3 = conn
            |> put_req_header("if-none-match", etag)
            |> get(category_path(conn, :index), %{all: true})
    assert resp3.status == 200
  end

  test "GET /v2/categories?meta=true", %{conn: conn} do
    conn = get(conn, category_path(conn, :index), %{meta: true})
    assert %{"categories" => categories} = json_response(conn, 200)
    assert Enum.member?(category_names(categories), "Lacross") == true
    assert Enum.member?(category_names(categories), "Featured") == true
  end

  test "GET /v2/categories", %{conn: conn} do
    conn = get(conn, category_path(conn, :index))
    assert %{"categories" => categories} = json_response(conn, 200)
    assert Enum.member?(category_names(categories), "Lacross") == true
  end

  @tag :json_schema
  test "GET /v2/categories?all=true - json schema", %{conn: conn} do
    conn = get(conn, category_path(conn, :index), %{all: true})
    assert :ok = validate_json("category", json_response(conn, 200))
  end

  @tag :json_schema
  test "GET /v2/categories/:slug - json schema", %{conn: conn} do
    conn = get(conn, category_path(conn, :show, "featured"))
    assert :ok = validate_json("category", json_response(conn, 200))
  end

  defp category_names(categories) do
    Enum.map(categories, &(&1["name"]))
  end
end
