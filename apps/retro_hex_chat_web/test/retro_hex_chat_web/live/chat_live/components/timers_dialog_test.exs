defmodule RetroHexChatWeb.ChatLive.Components.TimersDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.TimersDialog

  @moduletag :unit

  test "id/0 is stable" do
    assert TimersDialog.id() == "timers-dialog"
  end

  test "renders the bare panel (the desktop window provides the chrome)" do
    html = render_component(TimersDialog, id: TimersDialog.id())

    assert html =~ ~s(data-testid="timers-panel")
    refute html =~ "phx-show-modal"
  end

  test "renders timer rows from the passthrough map" do
    timers = %{"morning" => %{type: :repeat, interval: 60, command: "/me stretches"}}

    html = render_component(TimersDialog, id: TimersDialog.id(), timers: timers)

    assert html =~ ~s(data-testid="timer-row-morning")
    assert html =~ "morning"
    # Stop carries the selected timer to the parent.
    assert html =~ "timers_dialog_stop"
  end
end
