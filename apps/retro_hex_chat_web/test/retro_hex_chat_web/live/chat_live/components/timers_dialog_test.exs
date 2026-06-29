defmodule RetroHexChatWeb.ChatLive.Components.TimersDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.TimersDialog

  @moduletag :unit

  test "id/0 is stable" do
    assert TimersDialog.id() == "timers-dialog"
  end

  test "is hidden with no show-trigger by default" do
    html = render_component(TimersDialog, id: TimersDialog.id())

    assert html =~ "Timers"
    refute html =~ "timers-dialog-show-trigger"
  end

  test "opens via the :open action" do
    html = render_component(TimersDialog, id: TimersDialog.id(), action: {:open})

    assert html =~ "timers-dialog-show-trigger"
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
