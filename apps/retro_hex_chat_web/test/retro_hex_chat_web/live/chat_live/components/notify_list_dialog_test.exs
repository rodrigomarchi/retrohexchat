defmodule RetroHexChatWeb.ChatLive.Components.NotifyListDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Presence.NotifyList
  alias RetroHexChatWeb.ChatLive.Components.NotifyListDialog

  @moduletag :unit

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

  test "renders the add sub-form targeting the component" do
    html = dialog(%{show_notify_add_dialog: true})

    assert html =~ ~s(data-testid="notify-add-form")
    assert html =~ ~s(phx-target=)
  end
end
