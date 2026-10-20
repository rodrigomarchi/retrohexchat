defmodule RetroHexChatWeb.ChatLive.Components.UrlCatcherDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChat.Accounts.NickLocales
  alias RetroHexChat.Services.NickServ
  alias RetroHexChatWeb.ChatLive.Components.UrlCatcherDialog

  @moduletag :unit

  # A registered nickname whose language is on its row, as it is for somebody
  # who opened the chat in Portuguese and left.
  defp speaker(prefix) do
    nickname = "#{prefix}#{System.unique_integer([:positive])}"
    {:ok, _nick} = NickServ.register(nickname, "password123")
    :ok = NickLocales.remember(nickname, "pt_BR", store: true)
    nickname
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

  test "draws the poster's language flag beside their nickname" do
    nickname = speaker("Url")

    entries = [
      %{
        url: "https://example.com/b",
        source: "#elixir",
        posted_by: nickname,
        timestamp: ~U[2026-06-28 10:00:00Z]
      }
    ]

    html =
      render_component(UrlCatcherDialog,
        id: UrlCatcherDialog.id(),
        entries: entries,
        timezone: "UTC"
      )

    assert [_flag] =
             html
             |> Floki.parse_fragment!()
             |> Floki.find(~s(.uc-entry-meta [data-testid="nick-flag"][data-locale="pt_BR"]))
  end
end
