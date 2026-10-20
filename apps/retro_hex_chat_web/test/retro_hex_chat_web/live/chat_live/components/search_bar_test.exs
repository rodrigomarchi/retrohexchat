defmodule RetroHexChatWeb.ChatLive.Components.SearchBarTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.SearchBar

  @moduletag :unit

  defp base_assigns(overrides) do
    Enum.into(overrides, %{
      id: SearchBar.id(),
      visible: true,
      nickname: "Tester",
      active_channel: "#lobby"
    })
  end

  test "renders the search bar window when visible" do
    html = render_component(SearchBar, base_assigns(visible: true))

    assert html =~ ~s(data-testid="search-bar")
    # Defaults: empty query, no results.
    assert html =~ "0/0"
  end

  test "renders nothing visible when hidden" do
    html = render_component(SearchBar, base_assigns(visible: false))

    refute html =~ ~s(data-testid="search-bar")
    # The stable component root is still present so the parent can send_update.
    assert html =~ ~s(id="#{SearchBar.id()}")
  end
end
