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
