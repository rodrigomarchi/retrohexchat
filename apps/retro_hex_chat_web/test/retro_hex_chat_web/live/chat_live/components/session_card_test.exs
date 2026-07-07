defmodule RetroHexChatWeb.ChatLive.Components.SessionCardTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias RetroHexChatWeb.ChatLive.Components.SessionCard

  @moduletag :unit

  @created ~U[2024-01-01 14:10:00Z]
  @connected ~U[2024-01-01 14:13:00Z]
  @closed ~U[2024-01-01 14:22:00Z]

  defp card(card),
    do: render_component(&SessionCard.session_card/1, card: card, timezone: "Etc/UTC")

  defp lobby(overrides) do
    Map.merge(
      %{
        kind: :lobby,
        token: "tok123",
        href: "/lobby/tok123",
        status: "pending",
        terminal?: false,
        created_by: "rodrigo",
        peer: "alice",
        created_at: @created,
        accepted_at: nil,
        connected_at: nil,
        closed_at: nil,
        closed_reason: nil,
        duration_seconds: nil
      },
      overrides
    )
  end

  defp arcade(overrides) do
    Map.merge(
      %{
        kind: :arcade,
        token: "tokA",
        href: "/solo/tokA",
        status: "pending",
        terminal?: false,
        created_by: "rodrigo",
        created_at: @created,
        lobby_at: nil,
        started_at: nil,
        closed_at: nil,
        closed_reason: nil,
        duration_seconds: nil,
        game_id: "doom_shareware",
        game_name: "DOOM: Knee-Deep in the Dead"
      },
      overrides
    )
  end

  defp space(overrides) do
    Map.merge(
      %{
        kind: :space,
        token: "tokS",
        href: "/space/tokS",
        status: "active",
        terminal?: false,
        title: "Guild Tavern",
        creator_nick: "rodrigo",
        channel_name: "#general",
        map_id: "elfic_forest",
        participant_count: 3,
        max_participants: 20,
        created_at: @created,
        expires_at: ~U[2024-01-01 16:10:00Z],
        closed_at: nil,
        closed_reason: nil
      },
      overrides
    )
  end

  describe "virtual space card" do
    test "live space shows title, creator, channel, map, expiry and an Enter CTA" do
      html = card(space(%{}))

      assert html =~ ~s(data-session-kind="space")
      assert html =~ ~s(data-session-status="active")
      assert html =~ "Guild Tavern"
      assert html =~ "rodrigo"
      assert html =~ "#general"
      assert html =~ "Elfic Forest"
      assert html =~ "01/01 16:10"
      assert html =~ "3/20"
      assert html =~ "Enter space"
      assert html =~ ~s(href="/space/tokS")
    end

    test "an untitled space falls back to a generic title" do
      html = card(space(%{title: nil}))
      assert html =~ "Virtual space"
    end

    test "terminal space shows the close reason and drops the CTA" do
      html =
        card(
          space(%{
            status: "expired",
            terminal?: true,
            closed_at: @closed,
            closed_reason: "expired"
          })
        )

      assert html =~ ~s(data-session-status="expired")
      assert html =~ "01/01 14:22"
      refute html =~ "Enter space"
    end
  end

  describe "P2P lobby card" do
    test "pending session shows the creator, a waiting step and a Join CTA" do
      html = card(lobby(%{status: "pending"}))

      assert html =~ ~s(data-session-kind="lobby")
      assert html =~ ~s(data-session-status="pending")
      assert html =~ "P2P lobby"
      assert html =~ "rodrigo"
      assert html =~ "01/01 14:10"
      assert html =~ "Join"
      assert html =~ ~s(href="/lobby/tok123")
    end

    test "connected session shows the connected time and an Open lobby CTA" do
      html = card(lobby(%{status: "connected", connected_at: @connected}))

      assert html =~ "01/01 14:13"
      assert html =~ "Open lobby"
      refute html =~ "Join"
    end

    test "terminal session shows the close time, duration and reason, and drops the CTA" do
      html =
        card(
          lobby(%{
            status: "closed",
            terminal?: true,
            connected_at: @connected,
            closed_at: @closed,
            closed_reason: "peer_left",
            duration_seconds: 522
          })
        )

      assert html =~ "P2P lobby ended"
      assert html =~ "01/01 14:22"
      assert html =~ "08m 42s"
      assert html =~ "The other user left"
      refute html =~ "peer_left"
      refute html =~ "Open lobby"
      refute html =~ "Join"
    end

    test "humanizes an unknown close reason instead of showing the raw key" do
      html =
        card(
          lobby(%{
            status: "closed",
            terminal?: true,
            connected_at: @connected,
            closed_at: @closed,
            closed_reason: "some_new_reason",
            duration_seconds: 10
          })
        )

      assert html =~ "Some new reason"
      refute html =~ "some_new_reason"
    end
  end

  describe "Arcade card" do
    test "shows the game name and an Open Arcade CTA while live" do
      html = card(arcade(%{status: "playing", started_at: @connected}))

      assert html =~ ~s(data-session-kind="arcade")
      assert html =~ "DOOM: Knee-Deep in the Dead"
      assert html =~ "01/01 14:13"
      assert html =~ "Open Arcade"
    end

    test "finished session shows the duration and no CTA" do
      html =
        card(
          arcade(%{
            status: "finished",
            terminal?: true,
            started_at: @connected,
            closed_at: @closed,
            closed_reason: "completed",
            duration_seconds: 522
          })
        )

      assert html =~ "08m 42s"
      refute html =~ "Open Arcade"
    end
  end
end
