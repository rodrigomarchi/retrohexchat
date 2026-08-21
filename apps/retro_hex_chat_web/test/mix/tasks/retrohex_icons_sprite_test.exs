defmodule Mix.Tasks.Retrohex.Icons.SpriteTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Retrohex.Icons.Sprite
  alias RetroHexChatWeb.Icons.Registry

  @moduletag :unit

  setup_all do
    %{sprite: Sprite.build()}
  end

  describe "build/0" do
    test "wraps the whole document in a hidden <svg>", %{sprite: sprite} do
      assert String.starts_with?(sprite, "<svg ")
      assert String.ends_with?(String.trim(sprite), "</svg>")
      assert sprite =~ ~s(xmlns="http://www.w3.org/2000/svg")
    end

    test "gives every registered icon exactly one <symbol>", %{sprite: sprite} do
      for {name, _module} <- Registry.all() do
        id = Registry.sprite_id(name)
        matches = Regex.scan(~r/<symbol id="#{id}"[\s>]/, sprite)

        assert length(matches) == 1,
               "expected exactly one <symbol id=\"#{id}\">, found #{length(matches)}"
      end
    end

    test "carries a viewBox on every symbol", %{sprite: sprite} do
      symbols = Regex.scan(~r/<symbol [^>]*>/, sprite) |> List.flatten()

      assert length(symbols) == length(Registry.all())
      assert Enum.all?(symbols, &(&1 =~ ~s(viewBox=")))
    end

    test "leaves no nested <svg> behind", %{sprite: sprite} do
      # The art is authored as a full <svg> document; a leftover one inside a
      # <symbol> renders nothing and is invisible until someone looks.
      inner = String.replace(sprite, ~r{\A<svg [^>]*>|</svg>\z}, "")

      refute inner =~ "<svg"
    end

    test "keeps no id but the symbol ids", %{sprite: sprite} do
      ids = Regex.scan(~r/\bid="([^"]+)"/, sprite, capture: :all_but_first) |> List.flatten()
      registered = Enum.map(Registry.all(), fn {name, _} -> Registry.sprite_id(name) end)

      assert Enum.sort(ids) == Enum.sort(registered)
    end

    test "is deterministic" do
      assert Sprite.build() == Sprite.build()
    end

    test "strips the authoring comments and collapsed whitespace", %{sprite: sprite} do
      refute sprite =~ "<!--"
      refute sprite =~ "\n  "
    end
  end

  describe "symbol_from_svg/2" do
    # dev sets debug_heex_annotations and debug_attributes, so the art renders
    # wrapped in HEEx comments and stamped with data-phx-loc. The sprite is built
    # by assets.build, which runs in dev — none of that may reach the file.
    test "survives the HEEx debug annotations dev renders with" do
      svg = """
      <!-- <RetroHexChatWeb.Icons.People.icon_community> lib/icons/people.ex:12 -->
      <svg class="w-4" viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true" data-phx-loc="12">
        <!-- Shadow -->
        <rect x="1" y="1" width="4" height="4" fill="#000" data-phx-loc="14" />
      </svg>
      <!-- </RetroHexChatWeb.Icons.People.icon_community> -->
      """

      symbol = Sprite.symbol_from_svg(:icon_community, svg)

      assert symbol ==
               ~s(<symbol id="icon_community" viewBox="0 0 16 16" ) <>
                 ~s(shape-rendering="crispEdges">) <>
                 ~s(<rect x="1" y="1" width="4" height="4" fill="#000"/></symbol>)
    end

    test "keeps the geometry and drops what belongs to the call site" do
      svg =
        ~s(<svg class="h-4" viewBox="0 0 32 32" aria-hidden="true"><circle r="2"></circle></svg>)

      symbol = Sprite.symbol_from_svg(:icon_x, svg)

      assert symbol =~ ~s(viewBox="0 0 32 32")
      refute symbol =~ "class="
      refute symbol =~ "aria-hidden"
    end
  end

  describe "stale?/1" do
    test "an absent or divergent file is stale", %{sprite: sprite} do
      dir = Path.join(System.tmp_dir!(), "sprite-test-#{System.unique_integer([:positive])}")
      path = Path.join(dir, "sprite.svg")

      assert Sprite.stale?(path)

      File.mkdir_p!(dir)
      File.write!(path, "<svg></svg>")
      assert Sprite.stale?(path)

      File.write!(path, sprite)
      refute Sprite.stale?(path)

      File.rm_rf!(dir)
    end
  end
end
