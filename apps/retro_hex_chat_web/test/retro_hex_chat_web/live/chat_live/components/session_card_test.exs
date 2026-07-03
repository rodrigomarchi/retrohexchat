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
            closed_reason: "peer left",
            duration_seconds: 522
          })
        )

      assert html =~ "P2P lobby ended"
      assert html =~ "01/01 14:22"
      assert html =~ "08m 42s"
      assert html =~ "peer left"
      refute html =~ "Open lobby"
      refute html =~ "Join"
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
