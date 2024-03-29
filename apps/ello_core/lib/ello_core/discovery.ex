defmodule Ello.Core.Discovery do
  import Ecto.Query
  alias Ello.Core.{Repo, Network}
  alias __MODULE__.{Category, Editorial, Preload, Promotional, PagePromotional, CategoryPost}
  alias Network.{User, CategoryUser}

  @moduledoc """
  Responsible for retreiving and loading categories and related data.

  Handles database queryies, preloading relations, and fetching cached values.
  """

  @typedoc """
  All Ello.Core.Discovery public functions expect to receive a map of options.
  Those options should always include `current_user`, `allow_nsfw`, and
  `allow_nudity`. Any extra options should be included in the same map.
  """
  @type options :: %{
    required(:current_user) => User.t | nil,
    required(:allow_nsfw)   => boolean,
    required(:allow_nudity) => boolean,
    optional(:id_or_slug)   => integer | String.t,
    optional(:promotionals) => boolean,
    optional(:skip_images)  => boolean,
    optional(any)           => any
  }

  @doc """
  Find a single category by slug or id

  Options:

    * id_or_slug -   integer id or binary slug to fetch.
    * images -       build image - default true.
    * promotionals - include promotionals - default false.
  """
  @spec category(options) :: Category.t
  def category(%{id_or_slug: slug} = options) when is_binary(slug) do
    Category
    |> include_inactive_categories(options[:inactive])
    |> Repo.get_by(slug: slug)
    |> Preload.categories(options)
  end
  def category(%{id_or_slug: id} = options) when is_number(id) do
    Category
    |> include_inactive_categories(options[:inactive])
    |> Repo.get(id)
    |> Preload.categories(options)
  end

  @doc """
  Return C (filtered by other options)ategories.

  Fetch options:

    * ids -          fetch by ids - if not present all categories returned (filtered by other options).
    * inactive -     include inactive category
    * meta -         include meta categories
    * primary -      only return primary categories
    * query -        search by category name
    * administered - only return categories adiminstered by the current user
  """
  @spec categories(options) :: [Category.t]
  def categories(%{ids: nil} = options), do: categories(Map.put(options, :ids, []))
  def categories(%{ids: ids, promo: true} = options) do
    Category
    |> where([c], c.id in ^ids or c.level == "promo")
    |> include_inactive_categories(options[:inactive])
    |> include_meta_categories(options[:meta])
    |> priority_order
    |> Repo.all
    |> Preload.categories(options)
  end
  def categories(%{ids: ids} = options) do
    Category
    |> where([c], c.id in ^ids)
    |> include_inactive_categories(options[:inactive])
    |> include_meta_categories(options[:meta])
    |> priority_order
    |> Repo.all
    |> Preload.categories(options)
  end
  def categories(%{creator_types: true} = options) do
    Category
    |> where(is_creator_type: true)
    |> Repo.all
    |> Preload.categories(options)
  end
  def categories(%{primary: true} = options) do
    Category
    |> where([c], c.level == "primary" or c.level == "promo")
    |> Repo.all
    |> Preload.categories(options)
  end
  def categories(options) do
    Category
    |> include_inactive_categories(options[:inactive])
    |> include_meta_categories(options[:meta])
    |> search_by_name(options[:query])
    |> administered_only(options[:administered], options[:current_user])
    |> priority_order
    |> Repo.all
    |> Preload.categories(options)
  end

  def category_posts(%{post_ids: ids} = options) do
    CategoryPost
    |> join(:left, [cp], category in assoc(cp, :category))
    |> where([cp, c], not is_nil(c.level))
    |> where([cp, c], cp.post_id in ^ids)
    |> Repo.all
    |> Preload.category_posts(options)
  end
  def category_posts(%{ids: ids} = options) do
    CategoryPost
    |> join(:left, [cp], category in assoc(cp, :category))
    |> where([cp, c], cp.id in ^ids)
    |> Repo.all
    |> Preload.category_posts(options)
  end

  def category_users(%{category_ids: ids, roles: roles} = options) do
    roles = Enum.map(roles, &to_string/1)
    CategoryUser
    |> where([cu], cu.category_id in ^ids)
    |> where([cu], cu.role in ^roles)
    |> Repo.all
    |> Preload.category_users(options)
  end
  def category_users(%{category_ids: ids} = options) do
    CategoryUser
    |> where([cu], cu.category_id in ^ids)
    |> Repo.all
    |> Preload.category_users(options)
  end
  def category_users(%{user_ids: ids, roles: roles} = options) do
    roles = Enum.map(roles, &to_string/1)
    CategoryUser
    |> join(:left, [cu], category in assoc(cu, :category))
    |> where([cu, c], cu.user_id in ^ids)
    |> where([cu, c], cu.role in ^roles)
    |> where([cu, c], not is_nil(c.level))
    |> Repo.all
    |> Preload.category_users(options)
  end
  def category_users(%{user_ids: ids} = options) do
    CategoryUser
    |> join(:left, [cu], category in assoc(cu, :category))
    |> where([cu], cu.user_id in ^ids)
    |> where([cu, c], not is_nil(c.level))
    |> Repo.all
    |> Preload.category_users(options)
  end
  def category_users(%{ids: ids} = options) do
    CategoryUser
    |> join(:left, [cu], category in assoc(cu, :category))
    |> where([cu], cu.id in ^ids)
    |> where([cu, c], not is_nil(c.level))
    |> Repo.all
    |> Preload.category_users(options)
  end

  @doc """
  Return Editorials

  Fetch options:

    * preview -  return staff preview or publicly published list of editorials?
    * before -   pagination cursor
    * per_page - how many per page.
    * kinds    - filter by kinds
  """
  @spec editorials(options) :: [Editorial.t]
  def editorials(%{preview: false} = options) do
    Editorial
    |> where([e], not is_nil(e.published_position))
    |> filter_kinds(options[:kinds])
    |> order_by(desc: :published_position)
    |> editorial_cursor(options)
    |> limit(^options[:per_page])
    |> Repo.all
    |> Preload.editorials(options)
    |> filter_missing_posts
  end
  def editorials(%{preview: true} = options) do
    Editorial
    |> where([e], not is_nil(e.preview_position))
    |> filter_kinds(options[:kinds])
    |> order_by(desc: :preview_position)
    |> editorial_cursor(options)
    |> limit(^options[:per_page])
    |> Repo.all
    |> Preload.editorials(options)
    |> filter_missing_posts
  end

  defp filter_kinds(query, nil), do: query
  defp filter_kinds(query, []), do: query
  defp filter_kinds(query, kinds) do
    where(query, [e], e.kind in ^kinds)
  end

  defp filter_missing_posts(editorials) do
    Enum.reject editorials, fn
      %{kind: "post", post: nil} -> true
      _ -> false
    end
  end

  defp editorial_cursor(query, %{before: nil}), do: query
  defp editorial_cursor(query, %{preview: true, before: before}) do
    case editorial_before(before) do
      nil    -> query
      before -> where(query, [e], e.preview_position < ^before)
    end
  end
  defp editorial_cursor(query, %{preview: false, before: before}) do
    case editorial_before(before) do
      nil    -> query
      before -> where(query, [e], e.published_position < ^before)
    end
  end

  defp editorial_before(before), do: String.replace(before, ~r"\D", "")

  @doc """
  Return Category Promotionals

  Fetch options:

    * slug - the category from which to get the promotion
    * per_page - how many to get - pagination not supported, just a limit
  """
  @spec promotionals(options) :: [Promotional.t]
  def promotionals(%{slug: slug, per_page: per_page} = options) do
    Promotional
    |> join(:left, [promotional], category in assoc(promotional, :category))
    |> where([promotional, category], category.slug == ^slug)
    |> limit(^per_page)
    |> Repo.all
    |> Preload.promotionals(options)
  end

  @doc """
  Return Page Promotionals

  Fetch options:

    * slug - the category from which to get the promotion
    * per_page - how many to get - pagination not supported, just a limit
  """
  @spec page_promotionals(options) :: [PagePromotional.t]
  def page_promotionals(%{per_page: per_page} = options) do
    PagePromotional
    |> page_promotional_by_kind(options[:kind])
    |> page_promotional_by_login_status(options[:kind], options[:current_user])
    |> limit(^per_page)
    |> Repo.all
    |> Preload.page_promotionals(options)
  end

  defp page_promotional_by_kind(q, :editorial), do: where(q, is_editorial: true)
  defp page_promotional_by_kind(q, :artist_invite), do: where(q, is_artist_invite: true)
  defp page_promotional_by_kind(q, :authentication), do: where(q, is_authentication: true)
  defp page_promotional_by_kind(q, _),
    do: where(q, is_artist_invite: false, is_editorial: false, is_authentication: false)

  defp page_promotional_by_login_status(q, :generic, nil), do: where(q, is_logged_in: false)
  defp page_promotional_by_login_status(q, :generic, _), do: where(q, is_logged_in: true)
  defp page_promotional_by_login_status(q, _, _), do: q

  # Category Scopes
  defp priority_order(q),
    do: order_by(q, [:level, :order])

  defp include_inactive_categories(q, true), do: q
  defp include_inactive_categories(q, _),
    do: where(q, [c], not is_nil(c.level))

  defp include_meta_categories(q, true), do: q
  defp include_meta_categories(q, _),
    do: where(q, [c], c.level != "meta" or is_nil(c.level))

  defp search_by_name(q, nil), do: q
  defp search_by_name(q, term) do
    term = "%#{term}%"
    where(q, [c], ilike(c.name, ^term))
  end

  @admin_roles ["curator", "moderator"]
  defp administered_only(q, _, %{is_staff: true}), do: q
  defp administered_only(query, true, %{id: user_id}) do
    query
    |> join(:left, [c], category_user in assoc(c, :category_users))
    |> where([c, cu], cu.user_id == ^user_id)
    |> where([c, cu], cu.role in @admin_roles)
  end
  defp administered_only(q, _, _user), do: q
end
