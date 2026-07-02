defmodule RetroHexChatWeb.ChatLive.Components.UrlCatcherDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.UrlCatcherDialog

  @moduletag :unit

  test "id/0 is stable" do
    assert UrlCatcherDialog.id() == "url-catcher-dialog"
  end

  test "renders the content panel without any frame" do
    html = render_component(UrlCatcherDialog, id: UrlCatcherDialog.id())

    # Bare panel: the desktop window provides the chrome.
    assert html =~ ~s(data-testid="url-catcher")
    refute html =~ "phx-show-modal"
  end

  test "renders the filtered/sorted entries from the passthrough log" do
    entries = [
      %{
        url: "https://example.com/a",
        source: "#elixir",
        posted_by: "Bob",
        timestamp: ~U[2026-06-28 10:00:00Z]
      }
    ]

    html =
      render_component(UrlCatcherDialog,
        id: UrlCatcherDialog.id(),
        entries: entries,
        timezone: "UTC"
      )

    assert html =~ "example.com/a"
    # View events route to the component.
    assert html =~ "url_catcher_search"
  end
end
