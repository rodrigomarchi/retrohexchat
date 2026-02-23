defmodule RetroHexChatWeb.Components.BotManagementDialogTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.Components.BotManagementDialog

  @moduletag :component

  @bot %{
    id: 1,
    name: "TestBot",
    nickname: "TestBot",
    description: "A test bot",
    command_prefix: "!",
    cooldown_ms: 2000,
    created_by: "admin",
    enabled: true,
    capabilities: %{
      "mention" => %{"enabled" => true, "response" => "Hi {nickname}!"},
      "dice" => %{
        "enabled" => true,
        "max_dice" => 100,
        "max_sides" => 1000,
        "default_notation" => "d20"
      }
    }
  }

  @base_assigns %{
    visible: true,
    bots: [@bot],
    selected: nil,
    channels: [],
    commands: [],
    events: [],
    stats: nil,
    active_tab: :general,
    is_admin: false,
    editing_field: nil
  }

  defp render_dialog(overrides \\ %{}) do
    assigns = Map.merge(@base_assigns, overrides)
    render_component(&BotManagementDialog.bot_management_dialog/1, assigns)
  end

  describe "rendering" do
    test "does not render when visible is false" do
      html = render_dialog(%{visible: false})
      refute html =~ "bot-management-dialog"
    end

    test "renders empty state when no bot selected" do
      html = render_dialog()
      assert html =~ "Select a bot to view details"
    end

    test "renders bot list sidebar" do
      html = render_dialog()
      assert html =~ "TestBot"
      assert html =~ "bot-mgmt-list"
    end

    test "renders general tab by default" do
      html = render_dialog(%{selected: @bot})
      assert html =~ "Identity"
      assert html =~ "TestBot"
    end

    test "renders all 5 tabs when bot selected" do
      html = render_dialog(%{selected: @bot})
      assert html =~ "General"
      assert html =~ "Capabilities"
      assert html =~ "Channels"
      assert html =~ "Commands"
      assert html =~ "Events"
    end
  end

  describe "admin vs non-admin" do
    test "admin sees new bot button" do
      html = render_dialog(%{is_admin: true})
      assert html =~ "New Bot..."
    end

    test "non-admin does not see new bot button" do
      html = render_dialog(%{is_admin: false})
      refute html =~ "New Bot..."
    end

    test "admin sees delete button when bot selected" do
      html = render_dialog(%{selected: @bot, is_admin: true})
      assert html =~ "Delete"
    end

    test "non-admin does not see delete button" do
      html = render_dialog(%{selected: @bot, is_admin: false})
      refute html =~ "bot-delete-btn"
    end

    test "admin sees edit buttons on general tab" do
      html = render_dialog(%{selected: @bot, is_admin: true})
      assert html =~ "edit-btn-description"
    end

    test "non-admin does not see edit buttons" do
      html = render_dialog(%{selected: @bot, is_admin: false})
      refute html =~ "edit-btn-description"
    end
  end

  describe "general tab" do
    test "displays bot identity" do
      html = render_dialog(%{selected: @bot})
      assert html =~ "TestBot"
      assert html =~ "A test bot"
    end

    test "displays bot behavior settings" do
      html = render_dialog(%{selected: @bot})
      assert html =~ "!"
      assert html =~ "2000ms"
    end

    test "displays stats when bot is running" do
      stats = %{messages_handled: 42, commands_processed: 10, started_at: DateTime.utc_now()}
      html = render_dialog(%{selected: @bot, stats: stats})
      assert html =~ "42"
      assert html =~ "10"
    end

    test "shows Bot offline when bot not running" do
      html = render_dialog(%{selected: @bot, stats: nil})
      assert html =~ "Bot offline"
    end

    test "shows inline edit form when editing_field is set" do
      html = render_dialog(%{selected: @bot, is_admin: true, editing_field: :description})
      assert html =~ "bot-mgmt-inline-edit"
      assert html =~ "Save"
      assert html =~ "Cancel"
    end

    test "shows capability badges" do
      html = render_dialog(%{selected: @bot})
      assert html =~ "Mentions"
      assert html =~ "Dice"
    end
  end

  describe "channels tab" do
    @channel %{channel_name: "#general", enabled: true, capability_overrides: %{}}

    test "displays channel table" do
      html = render_dialog(%{selected: @bot, active_tab: :channels, channels: [@channel]})
      assert html =~ "#general"
    end

    test "empty state when no channels" do
      html = render_dialog(%{selected: @bot, active_tab: :channels, channels: []})
      assert html =~ "No channels configured"
    end

    test "admin sees add channel form" do
      html =
        render_dialog(%{selected: @bot, active_tab: :channels, channels: [], is_admin: true})

      assert html =~ "bot-add-channel-input"
    end

    test "admin sees toggle button per channel" do
      html =
        render_dialog(%{
          selected: @bot,
          active_tab: :channels,
          channels: [@channel],
          is_admin: true
        })

      assert html =~ "bot-toggle-channel-#general"
    end
  end

  describe "commands tab" do
    @command %{
      trigger: "rules",
      response: "Read #rules",
      description: "Show rules",
      enabled: true
    }

    test "displays command table" do
      html = render_dialog(%{selected: @bot, active_tab: :commands, commands: [@command]})
      assert html =~ "rules"
      assert html =~ "Read #rules"
    end

    test "empty state when no commands" do
      html = render_dialog(%{selected: @bot, active_tab: :commands, commands: []})
      assert html =~ "No custom commands"
    end

    test "admin sees add command button" do
      html =
        render_dialog(%{selected: @bot, active_tab: :commands, commands: [], is_admin: true})

      assert html =~ "Add Command..."
    end
  end

  describe "capabilities tab" do
    test "renders fieldset per enabled capability" do
      html = render_dialog(%{selected: @bot, active_tab: :capabilities})
      assert html =~ "Dice"
    end

    test "shows toggle button per capability for admin" do
      html = render_dialog(%{selected: @bot, active_tab: :capabilities, is_admin: true})
      assert html =~ "toggle-cap-dice"
    end

    test "shows config values" do
      html = render_dialog(%{selected: @bot, active_tab: :capabilities})
      assert html =~ "100"
      assert html =~ "1000"
      assert html =~ "d20"
    end
  end

  describe "events tab" do
    test "shows empty state when no events" do
      html = render_dialog(%{selected: @bot, active_tab: :events, events: []})
      assert html =~ "No events recorded"
    end

    test "displays event hook info" do
      html = render_dialog(%{selected: @bot, active_tab: :events})
      assert html =~ "Greet on join"
      assert html =~ "Mention response"
    end
  end
end
