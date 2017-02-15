defmodule Ello.Core.AttachmentTest do
  use Ello.Core.Case
  alias Ello.Core.{Content.Asset.Attachment,Image}

  test "Attachment.from_asset/1 - builds an Image" do
    asset = Factory.build(:asset)
    image = Attachment.from_asset(asset)

    assert %Image{versions: versions} = image
    optimized_test = asset.attachment_metadata["optimized"]
    assert Enum.any?(versions, fn(version) ->
      version.name == "optimized"
      && version.size == optimized_test["size"]
      && version.width == optimized_test["width"]
      && version.height == optimized_test["height"]
      && version.height == optimized_test["height"]
      && version.type == optimized_test["type"]
    end)
  end

end
