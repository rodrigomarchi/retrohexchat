defmodule RetroHexChatWeb.ChatLive.Components.AutojoinDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.AutoJoinList
  alias RetroHexChatWeb.ChatLive.Components.AutojoinDialog

  @moduletag :unit

  defp session(autojoin_list \\ AutoJoinList.new()) do
    "Nick"
    |> Session.new()
    |> Session.set_autojoin_list(autojoin_list)
  end

  defp dialog(overrides) do
    base = %{id: AutojoinDialog.id(), session: session()}
    render_component(AutojoinDialog, Map.merge(base, overrides))
  end

  test "exposes a stable id" do
    assert AutojoinDialog.id() == "autojoin-dialog"
  end

  test "renders the bare panel without dialog chrome" do
    html = dialog(%{})

    assert html =~ ~s(data-testid="autojoin-panel")
    refute html =~ "phx-show-modal"
    assert html =~ "No auto-join channels"
  end

  test "renders entries from the session and masks the key" do
    {:ok, list} = AutoJoinList.add_entry(AutoJoinList.new(), "#secret", "hunter2")

    html = render_component(AutojoinDialog, %{id: AutojoinDialog.id(), session: session(list)})

    assert html =~ "#secret"
    assert html =~ "***"
    refute html =~ "hunter2"
  end

  test "renders the add sub-form when its flag is set" do
    html = dialog(%{show_add_dialog: true})

    assert html =~ ~s(data-testid="autojoin-add-dialog")
    assert html =~ ~s(phx-target=)
  end
end
