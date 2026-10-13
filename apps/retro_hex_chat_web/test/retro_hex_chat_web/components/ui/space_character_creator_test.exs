defmodule RetroHexChatWeb.Components.UI.SpaceCharacterCreatorTest do
  @moduledoc """
  The creator names everything the catalog offers: a colour that grows in a
  palette without a name would show as a swatch nobody can hear, and a piece
  without a label would show its id.
  """
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.VirtualSpace.CharacterCatalog, as: Catalog
  alias RetroHexChatWeb.Components.UI.SpaceCharacterCreator, as: Creator

  test "every colour of every palette has a name" do
    for palette <- ~w(skin hair fabric) do
      assert length(Creator.colour_labels(palette)) == Catalog.palette_size(palette), palette
    end
  end

  test "every piece has a label of its own" do
    for id <- Catalog.bodies(), do: refute(Creator.body_label(id) == id, id)
    for id <- Map.keys(Catalog.outfits()), do: refute(Creator.outfit_label(id) == id, id)
    for id <- Catalog.hair(), do: refute(Creator.hair_label(id) == id, id)
    for id <- Map.keys(Catalog.headwear()), do: refute(Creator.headwear_label(id) == id, id)
    for id <- Catalog.face(), do: refute(Creator.face_label(id) == id, id)
  end
end
