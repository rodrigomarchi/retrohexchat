defmodule RetroHexChatWeb.Components.UI.NicklistItemTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.Nicklist

  @moduletag :unit

  defp row(attrs) do
    [nick: "ana", status: "online", role: :regular]
    |> Keyword.merge(attrs)
    |> then(&render_component(fn assigns -> nicklist_item(assigns) end, &1))
    |> Floki.parse_fragment!()
  end

  test "a player in a match carries the game's badge, named in its title" do
    [badge] =
      row(playing_game: "hex_tennis_quick")
      |> Floki.find(~s([data-testid="nicklist-playing-ana"]))

    assert Floki.attribute(badge, "data-game-id") == ["hex_tennis_quick"]
    assert Floki.attribute(badge, "title") == ["Playing Hex Tennis: Quick Match"]
  end

  test "nobody playing draws no badge" do
    assert row([]) |> Floki.find(~s([data-testid="nicklist-playing-ana"])) == []
  end
end
