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
          pm_tabs: [],
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

  test "renders a tab per channel and open PM" do
    html =
      tabs(%{
        channels: ["#lobby"],
        pm_tabs: ["bob"],
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
        pm_tabs: ["bob"],
        unread_counts: %{"pm:bob" => 1},
        nick_color_fn: fn "bob" -> "nick-color-7" end
      })

    assert html =~ ~s(data-unread="true")
    assert html =~ "nick-color-7"
  end

  test "marks the P2P peer PM tab through pending, connecting and connected states" do
    cases = [
      {:invite_sent, "pending", "P2P invite pending"},
      {:joining, "connecting", "P2P session connecting"},
      {:connected, "connected", "P2P session active"}
    ]

    for {state, visual_state, title} <- cases do
      html =
        tabs(%{
          pm_tabs: ["bob", "eve"],
          p2p_peer: "BOB",
          p2p_state: state
        })

      assert html =~ ~s(data-testid="tab-p2p-glyph")
      assert html =~ ~s(data-p2p-state="#{visual_state}")
      assert html =~ title
    end
  end

  test "passes P2P activity facets into the peer PM tab glyph" do
    html =
      tabs(%{
        pm_tabs: ["bob", "eve"],
        p2p_session: %{
          peer_nick: "BOB",
          state: :connected,
          call_summary: %{duration: "00:01:00"},
          file_summary: %{status: "sending"},
          game_summary: %{active?: true},
          turn_only: true,
          turn_configured: true
        }
      })

    assert html =~ ~s(data-testid="tab-p2p-glyph")
    assert html =~ ~s(data-p2p-status="live")
    assert html =~ ~s(data-p2p-facets="call,file,game,relay")
  end

  test "does not render sidebar-only PM conversations as tabs" do
    html =
      tabs(%{
        pm_conversations: ["alice"],
        pm_tabs: []
      })

    refute html =~ ~s(phx-value-type="pm")
    refute html =~ ~s(phx-value-label="alice")
  end
end
