defmodule RetroHexChatWeb.ChatLive.Components.BotManagementDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.BotManagementDialog

  @moduletag :unit

  defp dialog(overrides) do
    assigns = Map.merge(%{id: BotManagementDialog.id()}, overrides)
    render_component(BotManagementDialog, assigns)
  end

  test "exposes a stable id" do
    assert BotManagementDialog.id() == "bot-management-dialog"
  end

  test "hides the management dialog when closed (design-system toggles the hidden class)" do
    html = dialog(%{})

    assert html =~ ~s(id="bot-management-dialog-mount")
    # the design-system dialog always renders content; closed = the `hidden` class
    assert html =~ "group/dialog hidden"
  end

  test "renders the bot list when the management dialog is shown" do
    bots = [
      %{name: "TriviaBot", nickname: "TriviaBot", enabled: true},
      %{name: "DiceBot", nickname: "DiceBot", enabled: false}
    ]

    html = dialog(%{show_bot: true, bots: bots, is_admin: true})

    assert html =~ ~s(data-testid="bot-list")
    assert html =~ ~s(data-testid="bot-item-TriviaBot")
    assert html =~ ~s(data-testid="bot-item-DiceBot")
  end

  test "derives the add-command bot name from the selected bot" do
    selected = %{name: "TriviaBot", nickname: "TriviaBot", enabled: true}
    html = dialog(%{show_add_command: true, selected: selected})

    assert html =~ "TriviaBot"
  end
end
