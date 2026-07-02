defmodule RetroHexChatWeb.ChatLive.Components.PerformDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.{AutoJoinList, PerformList}
  alias RetroHexChatWeb.ChatLive.Components.PerformDialog

  @moduletag :unit

  defp session(perform_list \\ PerformList.new(), autojoin_list \\ AutoJoinList.new()) do
    "Nick"
    |> Session.new()
    |> Session.set_perform_list(perform_list)
    |> Session.set_autojoin_list(autojoin_list)
  end

  defp dialog(overrides) do
    base = %{id: PerformDialog.id(), session: session()}
    render_component(PerformDialog, Map.merge(base, overrides))
  end

  test "exposes a stable id" do
    assert PerformDialog.id() == "perform-dialog"
  end

  test "renders the bare panel with both tab panels" do
    html = dialog(%{})

    assert html =~ ~s(data-testid="perform-panel")
    refute html =~ "phx-show-modal"
    assert html =~ "No commands configured"
    assert html =~ "No auto-join channels"
  end

  test "renders perform entries from the session, password-masked" do
    {:ok, list} = PerformList.add_entry(PerformList.new(), "/ns identify hunter2")

    html =
      render_component(PerformDialog, %{
        id: PerformDialog.id(),
        session: session(list),
        perform_selected: 0
      })

    assert html =~ "/ns identify ***"
    refute html =~ "hunter2"
  end

  test "renders autojoin entries from the session" do
    {:ok, list} = AutoJoinList.add_entry(AutoJoinList.new(), "#lobby", nil)

    html =
      render_component(PerformDialog, %{
        id: PerformDialog.id(),
        session: session(PerformList.new(), list)
      })

    assert html =~ "#lobby"
  end

  test "renders the perform add sub-form when its flag is set" do
    html = dialog(%{show_perform_add_dialog: true})

    assert html =~ ~s(data-testid="perform-add-dialog")
    assert html =~ ~s(phx-target=)
  end
end
