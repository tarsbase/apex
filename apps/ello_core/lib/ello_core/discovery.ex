defmodule Ello.Core.Discovery do
  import Ecto.Query
  alias Ello.Core.{Repo, Network, Discovery}
  alias Discovery.{Category, Promotional}
  alias Network.User

  @moduledoc """
  Responsible for retreiving and loading categories and related data.

  Handles database queryies, preloading relations, and fetching cached values.
  """

  @doc "Find a single category by slug or id - including promotionals"
  @spec category(String.t | integer, current_user :: User.t | nil) :: Category.t
  def category(id_or_slug, current_user \\ nil)
  def category(slug, current_user) when is_binary(slug) do
    Category
    |> Repo.get_by!(slug: slug)
    |> include_promotionals(current_user)
    |> load_images
  end
  def category(id, current_user) when is_number(id) do
    Category
    |> Repo.get!(id)
    |> include_promotionals(current_user)
    |> load_images
  end

  def categories_by_ids([]), do: []
  def categories_by_ids(ids) when is_list(ids) do
    Category
    |> where([c], c.id in ^ids)
    |> include_inactive_categories(false)
    |> include_meta_categories(false)
    |> Repo.all
    |> load_images
  end

  @type categorizable :: User.t | Post.t | [User.t | Post.t]

  @doc """
  Fetches the categories for a user or post

  Given a user or post struct (or list of users or posts), this function will
  fetch all the categories and include them in the struct (or list of structs).
  """
  @spec put_belongs_to_many_categories(categorizables :: categorizable | nil) :: categorizable | nil
  def put_belongs_to_many_categories(nil), do: nil
  def put_belongs_to_many_categories([]), do: []
  def put_belongs_to_many_categories(%{} = categorizable),
    do: hd(put_belongs_to_many_categories([categorizable]))
  def put_belongs_to_many_categories(categorizables) do
    categories = categorizables
                 |> Enum.flat_map(&(&1.category_ids))
                 |> Discovery.categories_by_ids
                 |> Enum.group_by(&(&1.id))
    Enum.map categorizables, fn
      %{category_ids: []} = categorizable -> categorizable
      categorizable ->
        categorizable_categories = categories
                          |> Map.take(categorizable.category_ids)
                          |> Map.values
                          |> List.flatten
        Map.put(categorizable, :categories, categorizable_categories)
    end
  end

  @doc """
  Return all Categories with related promotionals their user.

  By default neither "meta" categories nor "inactive" categories are included
  in the results. Pass `meta: true` or `inactive: true` as opts to include them.
  """
  @spec categories(current_user :: User.t, opts :: Keyword.t) :: [Category.t]
  def categories(current_user \\ nil, opts \\ []) do
    Category
    |> include_inactive_categories(opts[:inactive])
    |> include_meta_categories(opts[:meta])
    |> priority_order
    |> Repo.all
    |> include_promotionals(current_user)
    |> load_images
  end

  # Category Scopes
  defp priority_order(q),
    do: order_by(q, [:level, :order])

  defp include_inactive_categories(q, true), do: q
  defp include_inactive_categories(q, _),
    do: where(q, [c], not is_nil(c.level))

  defp include_meta_categories(q, true), do: q
  defp include_meta_categories(q, _),
    do: where(q, [c], c.level != "meta" or is_nil(c.level))

  defp include_promotionals(categories, current_user) do
    Repo.preload(categories, promotionals: [user: &Network.users(&1, current_user)])
  end

  defp load_images(categories) when is_list(categories) do
    Enum.map(categories, &load_images/1)
  end
  defp load_images(%Category{promotionals: promos} = category) when is_list(promos) do
    category
    |> Category.load_images
    |> Map.put(:promotionals, Enum.map(promos, &Promotional.load_images/1))
  end
  defp load_images(%Category{} = category) do
    Category.load_images(category)
  end
end
