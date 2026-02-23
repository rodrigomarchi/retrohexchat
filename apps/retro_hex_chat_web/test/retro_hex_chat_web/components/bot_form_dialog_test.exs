defmodule RetroHexChatWeb.Components.BotFormDialogTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.BotFormDialog

  @moduletag :component

  describe "new_bot_dialog/1" do
    test "renders when visible" do
      html = render_component(&BotFormDialog.new_bot_dialog/1, visible: true)
      assert html =~ "New Bot"
      assert html =~ "new-bot-name"
    end

    test "does not render when not visible" do
      html = render_component(&BotFormDialog.new_bot_dialog/1, visible: false)
      refute html =~ "new-bot-dialog"
    end

    test "renders identity fields" do
      html = render_component(&BotFormDialog.new_bot_dialog/1, visible: true)
      assert html =~ "Bot Name"
      assert html =~ "Nickname"
      assert html =~ "Description"
    end

    test "renders capability checkboxes" do
      html = render_component(&BotFormDialog.new_bot_dialog/1, visible: true)
      assert html =~ "Respond to mentions"
      assert html =~ "Greet new users"
      assert html =~ "Dice/RNG"
      assert html =~ "Auto-Moderation"
      assert html =~ "Trivia/Quiz"
      assert html =~ "Scheduler"
      assert html =~ "RSS Reader"
    end

    test "disables stub capabilities" do
      html = render_component(&BotFormDialog.new_bot_dialog/1, visible: true)
      assert html =~ "Coming soon"
      assert html =~ "LLM Responses"
      assert html =~ "Script Engine"
      assert html =~ "Game AI"
    end
  end

  describe "add_command_dialog/1" do
    test "renders when visible" do
      html =
        render_component(&BotFormDialog.add_command_dialog/1,
          visible: true,
          bot_name: "TestBot"
        )

      assert html =~ "Add Command"
      assert html =~ "cmd-trigger"
      assert html =~ "cmd-response"
      assert html =~ "cmd-description"
    end

    test "does not render when not visible" do
      html =
        render_component(&BotFormDialog.add_command_dialog/1,
          visible: false,
          bot_name: "TestBot"
        )

      refute html =~ "add-command-dialog"
    end

    test "includes bot_name as hidden field" do
      html =
        render_component(&BotFormDialog.add_command_dialog/1,
          visible: true,
          bot_name: "TestBot"
        )

      assert html =~ "TestBot"
    end
  end
end
