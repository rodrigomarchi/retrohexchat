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

    for group <- ~w(furniture structure fun fair fantasy floor) do
      assert html =~ ~s(data-construct-tab="#{group}")
    end

    # Every tab with kinds in it has a key in the palette, so no kind the
    # catalog files under a tab is left without one.
    for group <- map.catalog |> Map.values() |> Enum.map(& &1.group) |> Enum.uniq() do
      assert html =~ ~s(data-construct-tab="#{group}"), group
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

  test "the Office opens on its own tab, keeps every other, and says its own refusals" do
    html = render_component(&space_build_palette/1, %{conversation: "channel", room: "office"})

    [_, open] = Regex.run(~r/data-construct-tab="(\w+)"\s+data-selected="true"/, html)
    assert open == "office"

    for kind <- ~w(reception_desk cubicle_partition trash_bin tall_plant chair tree) do
      assert html =~ ~s(data-construct-kind="#{kind}")
    end

    assert html =~ "data-refused-fixed"
    assert html =~ "The office is full."
  end

  test "the Game Room opens on the gamer tab and says its own refusals" do
    html = render_component(&space_build_palette/1, %{conversation: "channel", room: "game_room"})

    [_, open] = Regex.run(~r/data-construct-tab="(\w+)"\s+data-selected="true"/, html)
    assert open == "gamer"

    for kind <- ~w(pool_table beanbag racing_arcade chair reception_desk) do
      assert html =~ ~s(data-construct-kind="#{kind}")
    end

    assert html =~ "This furniture belongs to the game room and cannot be moved."
    assert html =~ "The game room is full."
  end

  test "a private conversation's Construct has no board" do
    html = render_component(&space_build_palette/1, %{conversation: "direct_message"})

    refute html =~ ~s(data-construct-kind="board")
    assert html =~ ~s(data-construct-kind="screen")
  end

  test "turn and remove are the kit's wooden keys, disabled until a piece is picked" do
    html = render_component(&space_build_palette/1, %{conversation: "channel"})

    for attr <- ["data-construct-rotate", "data-construct-remove"] do
      [button] = Regex.run(~r/<button[^>]*#{attr}[^>]*>.*?<\/button>/s, html)
      assert button =~ "disabled"
    end
  end

  test "the pieces wait behind a Build key, in a drawer that opens shut" do
    html = render_component(&space_build_palette/1, %{conversation: "channel"})

    assert html =~ ~s(data-open="false")
    [toggle] = Regex.run(~r/<button[^>]*data-construct-toggle[^>]*>/s, html)
    assert toggle =~ ~s(aria-expanded="false")
    assert toggle =~ ~s(aria-controls="construct-drawer")
    assert html =~ ~s(id="construct-drawer")
    assert html =~ ~s(data-testid="construct-close")
  end

  test "every tab says its group by an icon, and by name to a screen reader" do
    html = render_component(&space_build_palette/1, %{conversation: "channel"})

    for group <- ~w(furniture office garden gamer structure fun eot floor) do
      [tab] = Regex.run(~r/<button[^>]*data-construct-tab="#{group}"[^>]*>.*?<\/button>/s, html)
      assert tab =~ ~r/aria-label="[^"]+"/
    end
  end

  test "the card of what is in hand starts hidden, with turn, remove and drop" do
    html = render_component(&space_build_palette/1, %{conversation: "channel"})

    [card] = Regex.run(~r/<div[^>]*data-construct-holding.*?<\/div>/s, html)
    assert card =~ "hidden"
    assert card =~ ~s(data-testid="construct-rotate")
    assert card =~ ~s(data-testid="construct-remove")
    assert card =~ ~s(data-testid="construct-drop")
  end

  test "a touch screen gets a hint without a right-click in it" do
    html = render_component(&space_build_palette/1, %{conversation: "channel"})

    [_, touch] = Regex.run(~r/data-touch-hint="([^"]+)"/, html)
    refute touch =~ "right-click"
    assert touch =~ "Turn"
  end
end
