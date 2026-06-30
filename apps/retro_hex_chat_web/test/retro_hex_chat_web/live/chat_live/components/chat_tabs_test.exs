defmodule RetroHexChatWeb.ChatLive.Components.ChatTabsTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.ChatTabs

  @moduletag :unit

  defp tabs(overrides) do
    assigns =
      Map.merge(
        %{
          channels: [],
          pm_conversations: [],
          unread_counts: %{},
          status_unread: false,
          show_status_tab: false,
          active_channel: nil,
          active_pm: nil,
          nick_color_fn: fn _nick -> "nick-color-1" end
        },
        overrides
      )

    render_component(&ChatTabs.chat_tabs/1, assigns)
  end

  test "always renders the status tab first and it is not closeable" do
    html = tabs(%{show_status_tab: true})

    assert html =~ "Status"
    # status tab is active when show_status_tab is on
    assert html =~ ~s(aria-selected="true")
  end

  test "renders a tab per channel and PM" do
    html =
      tabs(%{
        channels: ["#lobby"],
        pm_conversations: ["bob"],
        active_channel: "#lobby"
      })

    assert html =~ "#lobby"
    assert html =~ "bob"
    # the active channel tab is selected (status tab is off)
    assert html =~ ~s(phx-value-label="#lobby")
    assert html =~ ~s(phx-value-label="bob")
  end

  test "marks a channel unread when its count is positive" do
    html =
      tabs(%{
        channels: ["#lobby"],
        unread_counts: %{"#lobby" => 3}
      })

    assert html =~ ~s(data-unread="true")
  end

  test "marks a PM unread via the pm: key and applies the nick color" do
    html =
      tabs(%{
        pm_conversations: ["bob"],
        unread_counts: %{"pm:bob" => 1},
        nick_color_fn: fn "bob" -> "nick-color-7" end
      })

    assert html =~ ~s(data-unread="true")
    assert html =~ "nick-color-7"
  end
end
