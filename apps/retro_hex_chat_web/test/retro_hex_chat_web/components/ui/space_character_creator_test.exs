defmodule RetroHexChatWeb.Components.UI.SpaceCharacterCreatorTest do
  @moduledoc """
  The creator names everything the catalog offers: a colour that grows in a
  palette without a name would show as a swatch nobody can hear, and a piece
  without a label would show its id.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  @moduletag :unit

  alias RetroHexChat.VirtualSpace.CharacterCatalog, as: Catalog
  alias RetroHexChat.VirtualSpace.CharacterRecipe
  alias RetroHexChatWeb.CharacterPortrait
  alias RetroHexChatWeb.Components.UI.SpaceCharacterCreator, as: Creator

  # Somebody in a wide hat, which would hide their hair and face.
  @hatted "c1.b-av.s-2.o-tun-0-3.h-lng-2.w-adv-3-8.f-gls-3"

  defp render_tab(tab, recipe \\ Catalog.default()) do
    render_component(&Creator.space_character_creator/1,
      id: "c",
      recipe: recipe,
      tab: tab,
      title: "Make your character"
    )
  end

  test "a part with one choice has no tab, and the creator opens on the first that has" do
    assert Catalog.bodies() |> length() == 1
    refute "body" in Creator.tabs()
    html = render_tab("body")
    refute html =~ ~s(data-testid="space-creator-tab-body")
    assert html =~ ~s(data-testid="space-creator-panel-#{hd(Creator.tabs())}")
  end

  test "each piece is pictured on the character being made, wearing it" do
    for {tab, field, ids, view} <- [
          {"outfit", "outfit", Catalog.outfits_for("av"), :figure},
          {"hat", "hat", ["0" | Map.keys(Catalog.headwear())], :head}
        ] do
      html = render_tab(tab, @hatted)

      for id <- ids do
        {:ok, wearing} = CharacterRecipe.put(@hatted, field, id)
        assert html =~ ~s(src="#{CharacterPortrait.path(wearing, view)}"), "#{field} #{id}"
      end
    end
  end

  test "a hair or a face item is pictured bareheaded, where a hat would hide it" do
    {:ok, bare} = CharacterRecipe.put(@hatted, "hat", "0")

    for {field, ids} <- [{"hair", ["0" | Catalog.hair()]}, {"face", ["0" | Catalog.face()]}] do
      html = render_tab(field, @hatted)

      for id <- ids do
        {:ok, wearing} = CharacterRecipe.put(bare, field, id)
        assert html =~ ~s(src="#{CharacterPortrait.path(wearing, :head)}"), "#{field} #{id}"
      end
    end
  end

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
