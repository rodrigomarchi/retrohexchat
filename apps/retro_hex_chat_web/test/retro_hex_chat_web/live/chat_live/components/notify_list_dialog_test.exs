defmodule RetroHexChatWeb.ChatLive.Components.NotifyListDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChat.Accounts.{NickLocales, Session}
  alias RetroHexChat.Presence.NotifyList
  alias RetroHexChat.Services.NickServ
  alias RetroHexChatWeb.ChatLive.Components.NotifyListDialog

  @moduletag :unit

  # A registered nickname whose language is on its row, as it is for somebody
  # who opened the chat in Portuguese and left.
  defp speaker(prefix) do
    nickname = "#{prefix}#{System.unique_integer([:positive])}"
    {:ok, _nick} = NickServ.register(nickname, "password123")
    :ok = NickLocales.remember(nickname, "pt_BR", store: true)
    nickname
  end

  defp session(notify_list \\ NotifyList.new()) do
    "Nick" |> Session.new() |> Session.set_notify_list(notify_list)
  end

  defp dialog(overrides) do
    base = %{id: NotifyListDialog.id(), session: session()}
    render_component(NotifyListDialog, Map.merge(base, overrides))
  end

  test "renders tracked-nick rows from the session" do
    {:ok, list} = NotifyList.add_entry(NotifyList.new(), "Nick", "Buddy", "a note")

    html =
      render_component(NotifyListDialog, %{
        id: NotifyListDialog.id(),
        session: session(list)
      })

    assert html =~ ~s(data-testid="notify-list-row-Buddy")
    assert html =~ "Buddy"
  end

  test "draws each tracked nickname's language flag beside it" do
    nickname = speaker("Ntf")
    {:ok, list} = NotifyList.add_entry(NotifyList.new(), "Nick", nickname, nil)
    html = dialog(%{session: session(list)})

    assert [_flag] =
             html
             |> Floki.parse_fragment!()
             |> Floki.find(
               ~s([data-testid="notify-list-row-#{nickname}"] [data-testid="nick-flag"][data-locale="pt_BR"])
             )
  end

  test "renders the add sub-form targeting the component" do
    html = dialog(%{show_notify_add_dialog: true})

    assert html =~ ~s(data-testid="notify-add-form")
    assert html =~ ~s(phx-target=)
  end
end
