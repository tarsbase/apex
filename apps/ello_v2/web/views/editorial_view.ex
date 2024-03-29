defmodule Ello.V2.EditorialView do
  use Ello.V2.Web, :view
  use Ello.V2.JSONAPI
  alias Ello.Core.Network
  alias Ello.V2.{
    PostView,
    CategoryView,
    UserView,
    AssetView,
    ImageView,
  }

  def stale_checks(_, %{data: editorials}) do
    [etag: etag(editorials)]
  end

  def render("index.json", %{data: editorials} = opts) do
    posts     = editorials |> Enum.map(&(&1.post)) |> Enum.reject(&is_nil/1)
    reposts   = posts |> Enum.map(&(&1.reposted_source)) |> Enum.reject(&is_nil/1)
    all_posts = posts ++ reposts
    users     = Enum.map(all_posts, &(&1.author))
    assets    = Enum.flat_map(all_posts, &(&1.assets))
    categories = Enum.flat_map(all_posts ++ users, &(&1.categories))

    json_response()
    |> render_resource(:editorials, editorials, __MODULE__, opts)
    |> include_linked(:posts, all_posts, PostView, opts)
    |> include_linked(:users, users, UserView, opts)
    |> include_linked(:categories, categories, CategoryView, opts)
    |> include_linked(:assets, assets, AssetView, opts)
  end

  def render("editorial.json", %{editorial: editorial} = opts) do
    editorial
    |> render_self(__MODULE__, opts)
    |> add_subtitle(editorial)
    |> add_url(editorial)
    |> add_path(editorial)
  end

  def attributes, do: []
  def computed_attributes, do: [
    :title,
    :kind,
    :one_by_one_image,
    :one_by_two_image,
    :two_by_one_image,
    :two_by_two_image,
  ]

  def links(%{kind: "post"} = ed, _conn) do
    %{
      post: %{
        id: "#{ed.post_id}",
        type: "posts",
        href: "/api/v2/posts/#{ed.post_id}",
      }
    }
  end
  def links(%{kind: "curated_posts"} = ed, _conn) do
    query = ed.content["post_tokens"]
            |> Enum.map(&("token[]=#{&1}"))
            |> Enum.join("&")
    %{
      post_stream: %{
        type: "posts",
        href: "/api/v2/editorials/posts/?#{query}",
      }
    }
  end
  def links(%{kind: "category"} = ed, _conn) do
    %{
      post_stream: %{
        type: "posts",
        href: "/api/v2/categories/#{ed.content["slug"]}/posts/trending?stream_source=editorial&per_page=#{per_page()}&images_only=true",
      }
    }
  end
  def links(%{kind: "artist_invite"} = ed, _conn) do
    %{
      post_stream: %{
        type: "posts",
        href: "/api/v2/artist_invites/~#{ed.content["slug"]}/submission_posts?stream_source=editorial&per_page=#{per_page()}&images_only=true&status=approved",
      }
    }
  end
  def links(%{kind: "following"}, %{assigns: %{current_user: user}}) when not is_nil(user) do
    case Network.following_ids(user, 1) do
      list when length(list) > 0 ->
        %{
          post_stream: %{
            type: "posts",
            href: "/api/v2/following/posts/trending?stream_source=editorial&per_page=#{per_page()}&images_only=true",
          }
        }
      _ -> links(%{kind: "following"}, %{})
    end
  end
  def links(%{kind: "following"}, _conn) do
    %{
      post_stream: %{
        type: "posts",
        href: "/api/v2/discover/posts/trending?stream_source=editorial&per_page=#{per_page()}&images_only=true",
      }
    }
  end
  def links(_, _), do: nil

  def title(ed, _), do: ed.content["title"]

  def kind(%{kind: kind}, _) when kind in ["category", "curated_posts", "following", "artist_invite"],
    do: "post_stream"
  def kind(%{kind: "invite_join"}, %{assigns: %{current_user: user}}) when not is_nil(user), do: "invite"
  def kind(%{kind: "invite_join"}, _), do: "join"
  def kind(%{kind: kind}, _), do: kind

  defp add_subtitle(json, %{kind: kind} = ed)
    when kind in ["external", "sponsored", "post", "internal"],
    do: Map.merge(json, %{
      subtitle:          ed.content["plaintext_subtitle"],
      rendered_subtitle: ed.content["rendered_subtitle"]
    })
  defp add_subtitle(json, _), do: json

  defp add_url(json, %{kind: "external"} = ed),
    do: Map.put(json, :url, ed.content["url"])
  defp add_url(json, %{kind: "sponsored"} = ed),
    do: Map.put(json, :url, ed.content["url"])
  defp add_url(json, _), do: json

  defp add_path(json, %{kind: "internal"} = ed),
    do: Map.put(json, :path, ed.content["path"])
  defp add_path(json, _), do: json

  def one_by_one_image(%{one_by_one_image_struct: nil}, _conn) do
    %{}
  end
  def one_by_one_image(editorial, conn) do
    render(ImageView, "image.json", image: editorial.one_by_one_image_struct, conn: conn)
  end

  def one_by_two_image(%{one_by_two_image_struct: nil} = e, conn) do
    one_by_one_image(e, conn)
  end
  def one_by_two_image(editorial, conn) do
    render(ImageView, "image.json", image: editorial.one_by_two_image_struct, conn: conn)
  end

  def two_by_one_image(%{two_by_one_image_struct: nil} = e, conn) do
    one_by_one_image(e, conn)
  end
  def two_by_one_image(editorial, conn) do
    render(ImageView, "image.json", image: editorial.two_by_one_image_struct, conn: conn)
  end

  def two_by_two_image(%{two_by_two_image_struct: nil} = e, conn) do
    one_by_one_image(e, conn)
  end
  def two_by_two_image(editorial, conn) do
    render(ImageView, "image.json", image: editorial.two_by_two_image_struct, conn: conn)
  end

  defp per_page do
    Application.get_env(:ello_v2, :editorial_stream_kind_size, 5)
  end
end
