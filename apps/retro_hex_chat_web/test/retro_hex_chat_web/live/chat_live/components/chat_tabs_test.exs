defmodule RetroHexChatWeb.ChatLive.Components.ChatTabsTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.ChatTabs

  @moduletag :unit

  defp tabs(overrides) do
    assigns =
      Map.merge(
        %{
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

  defp tab_labels(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find(~s([data-testid="tab-bar"] [role="tab"]))
    |> Floki.attribute("phx-value-label")
  end

  defp selection(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find(~s([data-testid="tab-bar"] [role="tab"]))
    |> Enum.map(fn tab ->
      {Floki.attribute(tab, "phx-value-label") |> List.first(),
       Floki.attribute(tab, "aria-selected") |> List.first()}
    end)
  end

  test "renders the status tab alone when nothing is focused" do
    html = tabs(%{show_status_tab: true})

    assert tab_labels(html) == ["Status"]
    assert html =~ ~s(aria-selected="true")
  end

  test "renders the focused channel next to status" do
    html = tabs(%{active_channel: "#lobby"})

    assert tab_labels(html) == ["Status", "#lobby"]
  end

  test "renders the focused PM next to status" do
    html = tabs(%{active_pm: "bob"})

    assert tab_labels(html) == ["Status", "bob"]
  end

  test "the PM wins the bar when a channel is still behind it" do
    html = tabs(%{active_channel: "#lobby", active_pm: "bob"})

    assert tab_labels(html) == ["Status", "bob"]
  end

  test "status takes selection from the conversation it covers" do
    covered = tabs(%{active_channel: "#lobby", show_status_tab: true})
    focused = tabs(%{active_channel: "#lobby", show_status_tab: false})

    assert tab_labels(covered) == ["Status", "#lobby"]
    assert selection(covered) == [{"Status", "true"}, {"#lobby", "false"}]
    assert selection(focused) == [{"Status", "false"}, {"#lobby", "true"}]
  end

  test "marks the focused channel unread when its count is positive" do
    html = tabs(%{active_channel: "#lobby", unread_counts: %{"#lobby" => 3}})

    assert html =~ ~s(data-unread="true")
  end

  test "marks a PM unread via the pm: key and applies the nick color" do
    html =
      tabs(%{
        active_pm: "bob",
        unread_counts: %{"pm:bob" => 1},
        nick_color_fn: fn "bob" -> "nick-color-7" end
      })

    assert html =~ ~s(data-unread="true")
    assert html =~ "nick-color-7"
  end

  test "a channel that is joined but not focused never reaches the bar" do
    html = tabs(%{active_channel: "#lobby", unread_counts: %{"#offscreen" => 9}})

    assert tab_labels(html) == ["Status", "#lobby"]
    refute html =~ "#offscreen"
  end

  test "marks the P2P peer PM tab through pending, connecting and connected states" do
    cases = [
      {:invite_sent, "pending", "P2P invite pending"},
      {:joining, "connecting", "P2P session connecting"},
      {:connected, "connected", "P2P session active"}
    ]

    for {state, visual_state, title} <- cases do
      html = tabs(%{active_pm: "bob", p2p_peer: "BOB", p2p_state: state})

      assert html =~ ~s(data-testid="tab-p2p-glyph")
      assert html =~ ~s(data-p2p-state="#{visual_state}")
      assert html =~ title
    end
  end

  test "passes P2P activity facets into the peer PM tab glyph" do
    html =
      tabs(%{
        active_pm: "bob",
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

  test "does not glyph a P2P session belonging to someone other than the focused PM" do
    html = tabs(%{active_pm: "eve", p2p_peer: "BOB", p2p_state: :connected})

    assert tab_labels(html) == ["Status", "eve"]
    refute html =~ ~s(data-testid="tab-p2p-glyph")
  end

  test "glyphs a group call on the focused channel" do
    html =
      tabs(%{
        active_channel: "#lobby",
        group_call_channels: MapSet.new(["#lobby"]),
        group_call_summaries: %{"#lobby" => %{participant_count: 2}}
      })

    assert html =~ ~s(data-testid="tab-group-call-glyph")
  end
end
