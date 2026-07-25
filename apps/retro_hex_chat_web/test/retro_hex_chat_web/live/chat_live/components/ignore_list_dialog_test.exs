defmodule RetroHexChatWeb.ChatLive.Components.IgnoreListDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.IgnoreList
  alias RetroHexChatWeb.ChatLive.Components.IgnoreListDialog

  @moduletag :unit

  defp dialog(overrides) do
    sess = Map.get(overrides, :session, Session.new("Nick"))
    base = %{id: IgnoreListDialog.id(), session: sess}
    render_component(IgnoreListDialog, Map.merge(base, Map.delete(overrides, :session)))
  end

  test "exposes a stable id" do
    assert IgnoreListDialog.id() == "ignore-list-dialog"
  end

  test "renders the bare panel (no modal chrome)" do
    html = dialog(%{})

    assert html =~ ~s(data-testid="ignore-list-panel")
    refute html =~ "phx-show-modal"
    assert html =~ "No ignored users. Click Add to ignore a nickname."
  end

  test "renders ignore rows from the session" do
    {:ok, list} = IgnoreList.add_entry(IgnoreList.new(), "Spammer", :all, nil)
    html = dialog(%{session: Session.set_ignore_list(Session.new("Nick"), list)})

    assert html =~ "Spammer"
    assert html =~ "Permanent"
  end

  test "renders the add sub-form targeting the component" do
    html = dialog(%{show_add_dialog: true})

    assert html =~ ~s(data-testid="control-add-form")
    assert html =~ ~s(phx-target=)
  end
end
