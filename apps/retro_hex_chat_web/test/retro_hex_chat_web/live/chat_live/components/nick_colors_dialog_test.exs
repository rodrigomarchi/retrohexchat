defmodule RetroHexChatWeb.ChatLive.Components.NickColorsDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChat.Accounts.{NickColors, Session}
  alias RetroHexChatWeb.ChatLive.Components.NickColorsDialog

  @moduletag :unit

  defp dialog(overrides) do
    sess = Map.get(overrides, :session, Session.new("Nick"))
    base = %{id: NickColorsDialog.id(), session: sess}
    render_component(NickColorsDialog, Map.merge(base, Map.delete(overrides, :session)))
  end

  test "exposes a stable id" do
    assert NickColorsDialog.id() == "nick-colors-dialog"
  end

  test "renders the bare panel (no modal chrome)" do
    html = dialog(%{})

    assert html =~ ~s(data-testid="nick-colors-panel")
    refute html =~ "phx-show-modal"
    assert html =~ "No custom colors set. Nicknames use automatic colors."
  end

  test "renders nick-color rows from the session" do
    {:ok, colors} = NickColors.add_entry(NickColors.new(), "ColorBud", 4)
    html = dialog(%{session: Session.set_nick_colors(Session.new("Nick"), colors)})

    assert html =~ "ColorBud"
    assert html =~ "irc-bg-4"
  end

  test "renders the add sub-form targeting the component" do
    html = dialog(%{show_add_dialog: true})

    assert html =~ ~s(data-testid="nick-color-add-form")
    assert html =~ ~s(phx-target=)
  end
end
