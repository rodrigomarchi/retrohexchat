defmodule RetroHexChatWeb.SpaceAssetsTest do
  use ExUnit.Case, async: true

  alias RetroHexChatWeb.SpaceAssets

  @moduletag :unit

  describe "sheet_urls/0" do
    test "names the shared fx strip and the UI kit, by the ids the atlas asks for" do
      # A key that drifts from the atlas's own leaves the client silently on its
      # built-in path.
      assert %{"fx_combat" => fx, "ui_canvas" => ui} = SpaceAssets.sheet_urls()
      assert map_size(SpaceAssets.sheet_urls()) == 2
      assert fx =~ "/images/space/fx"
      assert ui =~ "/images/space/ui/canvas"
    end

    test "every url points at a webp" do
      for {id, url} <- SpaceAssets.sheet_urls() do
        assert url =~ ~r/\.webp(\?|$)/, "#{id} is not a webp: #{url}"
      end
    end
  end

  describe "character_catalog_url/0" do
    test "is the creator catalog's address" do
      assert SpaceAssets.character_catalog_url() =~ "/images/space/creator/catalog"
      assert SpaceAssets.character_catalog_url() =~ ".json"
    end
  end

  describe "sheet_urls_json/0" do
    test "round-trips to the same map" do
      assert Jason.decode!(SpaceAssets.sheet_urls_json()) == SpaceAssets.sheet_urls()
    end
  end

  describe "digest_map/1" do
    test "rewrites tileset sources and leaves everything else alone" do
      map = %{
        id: "somewhere",
        ground: "grass",
        tilesets: [%{id: "sheet", src: "/images/space/endoftime.webp", tile: 32, columns: 36}]
      }

      digested = SpaceAssets.digest_map(map)

      assert digested.id == "somewhere"
      assert digested.ground == "grass"
      assert [%{id: "sheet", tile: 32, columns: 36, src: src}] = digested.tilesets
      assert src =~ "/images/space/endoftime"
      assert src =~ ".webp"
    end

    test "passes through a map with no tilesets rather than raising" do
      assert SpaceAssets.digest_map(%{id: "bare"}) == %{id: "bare"}
    end
  end
end
