defmodule RetroHexChatWeb.Components.UI.SpaceBuildPaletteTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.SpaceBuildPalette

  alias RetroHexChat.VirtualSpace

  @moduletag :unit

  test "has a key for every kind in the catalog, in tabs, with the furniture open" do
    html = render_component(&space_build_palette/1, %{conversation: "channel"})
    {:ok, map} = VirtualSpace.get_map("construct")

    for kind <- Map.keys(map.catalog) do
      assert html =~ ~s(data-construct-kind="#{kind}")
    end

    for group <- ~w(furniture structure fun floor) do
      assert html =~ ~s(data-construct-tab="#{group}")
    end

    [_, open] = Regex.run(~r/data-construct-tab="(\w+)"\s+data-selected="true"/, html)
    assert open == "furniture"
  end

  test "paints with every material, and erases" do
    html = render_component(&space_build_palette/1, %{conversation: "channel"})
    {:ok, map} = VirtualSpace.get_map("construct")

    for %{id: id, tile: tile} <- map.materials do
      assert html =~ ~s(data-construct-material="#{id}")
      assert html =~ ~s(data-construct-tile="#{tile}")
    end

    assert html =~ ~s(data-construct-material="none")
  end

  test "a private conversation's Construct has no board" do
    html = render_component(&space_build_palette/1, %{conversation: "direct_message"})

    refute html =~ ~s(data-construct-kind="board")
    assert html =~ ~s(data-construct-kind="screen")
  end

  test "turn and remove are the kit's wooden keys, disabled until a piece is picked" do
    html = render_component(&space_build_palette/1, %{conversation: "channel"})

    for {attr, icon} <- [{"data-construct-rotate", "turn"}, {"data-construct-remove", "remove"}] do
      [button] = Regex.run(~r/<button[^>]*#{attr}[^>]*>.*?<\/button>/s, html)
      assert button =~ "disabled"
      assert button =~ "space-build-tool--action"
      assert button =~ "space-icon--#{icon}"
    end

    # Disabled is etched by the global rule, never faded.
    refute html =~ "opacity"
    refute html =~ "bg-black"
  end
end
