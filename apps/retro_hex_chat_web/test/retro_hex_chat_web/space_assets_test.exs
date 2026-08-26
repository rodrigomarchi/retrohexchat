defmodule RetroHexChatWeb.SpaceAssetsTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.VirtualSpace
  alias RetroHexChatWeb.SpaceAssets

  @moduletag :unit

  describe "sheet_urls/0" do
    test "names one sheet per class, plus the shared fx strip" do
      urls = SpaceAssets.sheet_urls()

      expected = Enum.map(VirtualSpace.avatars(), &"av_iso_#{&1}") ++ ["fx_combat"]
      assert Enum.sort(Map.keys(urls)) == Enum.sort(expected)
    end

    test "keys match the ids the client atlas asks sheets by" do
      # The atlas looks a sheet up by `av_iso_<class>` / `fx_combat`; a key that
      # drifts from that leaves the client silently on its built-in path.
      assert %{"av_iso_hero" => hero, "fx_combat" => fx} = SpaceAssets.sheet_urls()
      assert hero =~ "/images/space/avatars/iso_hero"
      assert fx =~ "/images/space/fx"
    end

    test "every url points at a webp" do
      for {id, url} <- SpaceAssets.sheet_urls() do
        assert url =~ ~r/\.webp(\?|$)/, "#{id} is not a webp: #{url}"
      end
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
