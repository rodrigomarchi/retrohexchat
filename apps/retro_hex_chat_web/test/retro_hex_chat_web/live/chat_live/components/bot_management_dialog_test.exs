defmodule RetroHexChatWeb.ChatLive.Components.BotManagementDialogTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.BotManagementDialog
  alias RetroHexChatWeb.Components.UI.BotManagementDialog, as: UI

  @moduletag :unit

  defp dialog(overrides) do
    assigns = Map.merge(%{id: BotManagementDialog.id()}, overrides)
    render_component(BotManagementDialog, assigns)
  end

  defp panel(overrides) do
    assigns =
      %{id: "bot-management-dialog", show: true, windowed: true}
      |> Map.merge(overrides)
      |> Enum.to_list()

    render_component(&UI.bot_management_dialog/1, assigns)
  end

  defp bot(overrides) do
    Map.merge(
      %{
        name: "Cassandra",
        nickname: "Cassandra",
        command_prefix: "!",
        description: "Bearer of advisories",
        enabled: true,
        cooldown_ms: 1000,
        capabilities: %{},
        channel_configs: [],
        custom_commands: []
      },
      Map.new(overrides)
    )
  end

  test "exposes a stable id" do
    assert BotManagementDialog.id() == "bot-management-dialog"
  end

  test "hides the management dialog when closed (design-system toggles the hidden class)" do
    html = dialog(%{})

    assert html =~ ~s(id="bot-management-dialog-mount")
    # the design-system dialog always renders content; closed = the `hidden` class
    assert html =~ ~r/class="[^"]*group\/dialog[^"]*hidden[^"]*"/
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

  describe "the roster" do
    test "answers what a bot is and where it works before anything is clicked" do
      html =
        panel(%{
          bots: [
            bot(
              description: "Bearer of advisories nobody reads in time",
              capabilities: %{"rss" => %{"enabled" => true}, "dice" => %{"enabled" => false}},
              channel_configs: [%{channel_name: "#security"}],
              custom_commands: [%{trigger: "sources"}, %{trigger: "patch"}]
            )
          ],
          running: ["Cassandra"]
        })

      assert html =~ "Bearer of advisories nobody reads in time"
      assert html =~ "#security"
      assert html =~ "RSS"
      assert html =~ "2 commands"
      # a disabled capability is not advertised as something the bot does
      refute html =~ ">Dice<"
    end

    test "separates a bot that is down from one that was turned off" do
      bots = [
        bot(name: "Up", nickname: "Up"),
        bot(name: "Down", nickname: "Down"),
        bot(name: "Off", nickname: "Off", enabled: false)
      ]

      html = panel(%{bots: bots, running: ["Up"]})

      assert html =~ "Running"
      assert html =~ "Stopped"
      assert html =~ "Disabled"
      assert html =~ "bm-dot--running"
      assert html =~ "bm-dot--stopped"
      assert html =~ "bm-dot--disabled"
    end

    test "a selection replaces the roster with the bot, and offers the way back" do
      selected = bot([])

      roster = panel(%{bots: [selected], selected: nil})
      detail = panel(%{bots: [selected], selected: selected, is_admin: true})

      assert roster =~ ~s(data-testid="bot-list")
      refute roster =~ ~s(data-testid="bot-back")

      refute detail =~ ~s(data-testid="bot-list")
      assert detail =~ ~s(data-testid="bot-back")
      assert detail =~ ~s(phx-click="bot_back")
    end
  end

  describe "the detail screen" do
    test "reports the bot's own prefix rather than the default" do
      html = panel(%{selected: bot(command_prefix: "."), is_admin: true})

      assert html =~ ~r/data-testid="bot-prefix"[^>]*>\s*\.\s*</
    end

    test "reports what the running process actually counted" do
      stats = %{messages: 1234, commands: 56, uptime: "3 days"}
      html = panel(%{selected: bot([]), stats: stats})

      assert html =~ "1234"
      assert html =~ "56"
      assert html =~ "3 days"
    end

    test "a bot with no process says so instead of reporting zero traffic" do
      html = panel(%{selected: bot([]), stats: nil})

      assert html =~ "No process is running for this bot"
      refute html =~ ~r/data-testid="bot-messages"[^>]*>\s*0\s*</
    end

    test "renders configured text through the IRC renderer instead of leaking colour digits" do
      # \x03 04 is what `/bot set … greeting \c04…` stores; printed raw the byte
      # vanishes in the browser and the digits stay behind as "04 [Cassandra]".
      greeting = <<0x03>> <> "04[Cassandra] welcome" <> <<0x0F>>

      html =
        panel(%{
          selected:
            bot(capabilities: %{"greeter" => %{"enabled" => true, "greeting" => greeting}})
        })

      assert html =~ "[Cassandra] welcome"
      refute html =~ "04[Cassandra]"
    end

    test "names each capability's configuration keys as the console would take them" do
      html =
        panel(%{
          selected:
            bot(
              capabilities: %{
                "greeter" => %{
                  "enabled" => true,
                  "greeting_delivery" => "private_notice",
                  "repeat_window_sec" => 43_200
                }
              }
            ),
          is_admin: true
        })

      assert html =~ "greeting_delivery"
      assert html =~ "private_notice"
      # 43200 seconds is a window, and reads as one
      assert html =~ "12h"
      assert html =~ "/bot set Cassandra"
    end

    test "an event log row says what happened, where and when" do
      event = %{
        id: 7,
        event_type: "channel_user_joined",
        channel: "#security",
        inserted_at: DateTime.utc_now()
      }

      html = panel(%{selected: bot([]), events: [{"events-7", event}]})

      assert html =~ "channel user joined"
      assert html =~ "#security"
    end
  end

  describe "the RSS feeds panel" do
    defp bot_with_feeds(feeds) do
      %{
        name: "Gazeta",
        nickname: "Gazeta",
        enabled: true,
        capabilities: %{"rss" => %{"enabled" => true, "feeds" => feeds}}
      }
    end

    test "invites a first feed when there are none" do
      html = dialog(%{show_bot: true, selected: bot_with_feeds([]), is_admin: true})

      assert html =~ ~s(data-testid="rss-feeds")
      assert html =~ "No feeds yet"
      assert html =~ ~s(data-testid="rss-add-feed")
    end

    test "shows where each feed posts and when it was last checked" do
      feed = %{
        "id" => "f1",
        "url" => "https://example.com/atom.xml",
        "channel" => "#news",
        "title" => "Example Daily",
        "last_polled_at" => "2026-07-29T12:00:00Z",
        "last_error" => nil
      }

      html = dialog(%{show_bot: true, selected: bot_with_feeds([feed]), is_admin: true})

      assert html =~ ~s(data-testid="rss-feed-f1")
      assert html =~ "Example Daily"
      assert html =~ "#news"
      assert html =~ "2026-07-29T12:00:00Z"
      assert html =~ ~s(data-testid="rss-remove-f1")
    end

    test "surfaces why the last poll failed" do
      feed = %{
        "id" => "f2",
        "url" => "https://example.com/atom.xml",
        "channel" => "#news",
        "last_error" => "example.com does not resolve (nxdomain)"
      }

      html = dialog(%{show_bot: true, selected: bot_with_feeds([feed]), is_admin: true})

      assert html =~ ~s(data-testid="rss-feed-error")
      assert html =~ "nxdomain"
    end

    test "a feed list is never rendered as a bare item count" do
      feed = %{"id" => "f3", "url" => "https://example.com/f", "channel" => "#news"}
      html = dialog(%{show_bot: true, selected: bot_with_feeds([feed]), is_admin: true})

      refute html =~ "1 item"
    end

    test "an onlooker gets no controls" do
      feed = %{"id" => "f4", "url" => "https://example.com/f", "channel" => "#news"}
      html = dialog(%{show_bot: true, selected: bot_with_feeds([feed]), is_admin: false})

      assert html =~ ~s(data-testid="rss-feed-f4")
      refute html =~ ~s(data-testid="rss-remove-f4")
      refute html =~ ~s(data-testid="rss-add-feed")
    end
  end
end
