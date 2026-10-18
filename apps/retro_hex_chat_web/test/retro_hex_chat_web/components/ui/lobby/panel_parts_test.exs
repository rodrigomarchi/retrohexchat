defmodule RetroHexChatWeb.Components.UI.Lobby.PanelPartsTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.Lobby.PanelParts

  @moduletag :unit

  test "a panel before the connection says Offline and what connecting allows" do
    html =
      render_component(&disconnected_section/1,
        title: "Games",
        icon: :icon_joystick,
        text: "Connect to play a game.",
        testid: "p2p-games-disconnected",
        header_testid: "p2p-games-activity-header"
      )

    assert html =~ ~s(data-testid="p2p-games-disconnected")
    assert html =~ ~s(data-testid="p2p-games-activity-header")
    assert html =~ "Offline"
    assert html =~ "Connect to play a game."
  end

  defp card(assigns) do
    ~H"""
    <.state_card data-testid="lobby-game-consent">
      <:icon><span data-testid="pic"></span></:icon>
      <p>Ana wants to play</p>
      <:actions><button data-testid="accept">Accept</button></:actions>
    </.state_card>
    """
  end

  test "a state card carries the picture, the words and the answers" do
    html = render_component(&card/1, %{})

    for id <- ~w(lobby-game-consent pic accept) do
      assert html =~ ~s(data-testid="#{id}")
    end

    assert html =~ "Ana wants to play"
  end
end
