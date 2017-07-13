defmodule Ello.V2.ArtistInviteSubmissionView do
  use Ello.V2.Web, :view
  use Ello.V2.JSONAPI
  alias Ello.V2.{
    PostView,
    CategoryView,
    UserView,
    AssetView,
  }

  def stale_checks(_, %{data: submissions}) do
    [etag: etag(submissions)]
  end

  def render("index.json", %{data: submissions} = opts) do
    posts     = submissions |> Enum.map(&(&1.post)) |> Enum.reject(&is_nil/1)
    reposts   = posts |> Enum.map(&(&1.reposted_source)) |> Enum.reject(&is_nil/1)
    all_posts = posts ++ reposts
    users     = Enum.map(all_posts, &(&1.author))
    assets    = Enum.flat_map(all_posts, &(&1.assets))
    categories = Enum.flat_map(all_posts ++ users, &(&1.categories))

    json_response()
    |> render_resource(:artist_invite_submissions, submissions, __MODULE__, opts)
    |> include_linked(:posts, all_posts, PostView, opts)
    |> include_linked(:users, users, UserView, opts)
    |> include_linked(:categories, categories, CategoryView, opts)
    |> include_linked(:assets, assets, AssetView, opts)
  end

  def render("artist_invite_submission.json", %{artist_invite_submission: submission} = opts) do
    render_self(submission, __MODULE__, opts)
  end

  def attributes,          do: [:created_at, :updated_at]
  def computed_attributes, do: [:status]

  # TODO: action links
  def links(submission, _conn) do
    %{
      post: %{
        id:   "#{submission.post_id}",
        type: "posts",
        href: "/api/v2/posts/#{submission.post_id}",
      }
    }
  end

  # TODO: test/verify this logic
  def status(submission, %{assigns: %{
    current_user: %{is_staff: true},
  }}), do: submission.status
  def status(submission, %{assigns: %{
    invite:       %{brand_account_id: user_id},
    current_user: %{id: user_id},
  }}), do: submission.status
  def status(_, _), do: nil
end
