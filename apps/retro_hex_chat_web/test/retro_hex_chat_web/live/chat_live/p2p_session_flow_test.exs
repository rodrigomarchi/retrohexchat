defmodule RetroHexChatWeb.ChatLive.P2PSessionFlowTest do
  @moduledoc """
  In-chat P2P session flow (F2 of docs/plans/p2p-chat-integracao.md):
  invite → accept/decline via the PM card, cancel via the status bar, and the
  one-session-at-a-time switch. Asserts on synchronous LiveView state
  (`:sys.get_state`) and persisted domain rows — never on async stream diffs.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Lobby
  alias RetroHexChat.Services.RegisteredNick

  defp register(nickname) do
    {:ok, nick} =
      %RegisteredNick{}
      |> RegisteredNick.registration_changeset(%{nickname: nickname, password: "password123"})
      |> RetroHexChat.Repo.insert()

    nick
  end

  defp mount_pair(conn, nick_a, nick_b) do
    a = register(nick_a)
    b = register(nick_b)

    {:ok, view_a, _} = live(chat_conn(conn, nick_a, pre_identified: true), "/chat")
    {:ok, view_b, _} = live(chat_conn(conn, nick_b, pre_identified: true), "/chat")

    %{a: a, b: b, view_a: view_a, view_b: view_b}
  end

  defp p2p_assigns(view), do: :sys.get_state(view.pid).socket.assigns.p2p_session

  defp flush(view), do: :sys.get_state(view.pid)

  defp invite(ctx) do
    submit_command_sync(ctx.view_a, "/p2p #{ctx.b.nickname}")
    session = Lobby.active_session_for_user(ctx.a.id)
    assert session, "expected /p2p to create a session"
    session
  end

  describe "invite → accept" do
    test "creator holds :invite_sent and the peer's accept joins both", %{conn: conn} do
      ctx = mount_pair(conn, "p2pfa#{uid()}", "p2pfb#{uid()}")
      session = invite(ctx)

      assert %{state: :invite_sent, role: :creator} = p2p_assigns(ctx.view_a)
      assert render(ctx.view_a) =~ "status-bar-p2p"

      render_click(ctx.view_b, "p2p_accept_invite", %{"token" => session.token})
      assert %{state: :joining, role: :peer} = p2p_assigns(ctx.view_b)

      # The creator joins on the peer's lobby_peer_joined (subscribe-only
      # until then, so the standalone page can still claim the session);
      # only after that do BOTH count as joined and the status flips.
      flush(ctx.view_a)
      assert %{state: :joining} = p2p_assigns(ctx.view_a)
      assert {:ok, %{status: "lobby"}} = Lobby.get_session(session.token)
    end

    test "the invited peer sees accept/decline buttons on the PM card", %{conn: conn} do
      ctx = mount_pair(conn, "p2pfc#{uid()}", "p2pfd#{uid()}")
      invite(ctx)

      flush(ctx.view_b)
      render_click(ctx.view_b, "switch_pm", %{"nickname" => ctx.a.nickname})

      html = render(ctx.view_b)
      assert html =~ "session-card-accept"
      assert html =~ "session-card-decline"
    end
  end

  describe "decline and cancel" do
    test "declining closes the pending session and clears the creator state", %{conn: conn} do
      ctx = mount_pair(conn, "p2pfe#{uid()}", "p2pff#{uid()}")
      session = invite(ctx)

      render_click(ctx.view_b, "p2p_decline_invite", %{"token" => session.token})

      assert {:ok, %{status: "closed", closed_reason: "declined"}} =
               Lobby.get_session(session.token)

      flush(ctx.view_a)
      assert p2p_assigns(ctx.view_a) == nil
      refute render(ctx.view_a) =~ "status-bar-p2p"
    end

    test "the creator cancels a pending invite from the status bar", %{conn: conn} do
      ctx = mount_pair(conn, "p2pfg#{uid()}", "p2pfh#{uid()}")
      session = invite(ctx)

      render_click(ctx.view_a, "p2p_statusbar_stop", %{})
      flush(ctx.view_a)

      assert {:ok, %{status: "closed", closed_reason: "invite_cancelled"}} =
               Lobby.get_session(session.token)

      assert p2p_assigns(ctx.view_a) == nil
    end
  end

  describe "statistics window" do
    test "opens via the P2P menu action, shows telemetry, and closes with the session",
         %{conn: conn} do
      ctx = mount_pair(conn, "p2pfo#{uid()}", "p2pfp#{uid()}")
      session = invite(ctx)
      render_click(ctx.view_b, "p2p_accept_invite", %{"token" => session.token})
      flush(ctx.view_a)

      # Menu bar / start menu dispatch the same semantic action.
      render_click(ctx.view_a, "toolbar_action", %{"action" => "p2p_open_stats"})
      assert render(ctx.view_a) =~ "p2p-stats-window"

      # A telemetry sample from the WebRTC hook lands normalized in the panel.
      render_click(ctx.view_a, "lobby_stats", %{"connection" => %{"rtt_ms" => 42}})
      assert p2p_assigns(ctx.view_a).stats.connection.rtt_ms == 42

      # Clicking the status-bar area focuses the open P2P windows (no crash,
      # window stays open).
      render_click(ctx.view_a, "p2p_statusbar_click", %{})
      assert render(ctx.view_a) =~ "p2p-stats-window"

      # Ending the session tears the window down with it.
      render_click(ctx.view_a, "p2p_statusbar_stop", %{})
      render_click(ctx.view_a, "p2p_confirm_end", %{})
      flush(ctx.view_a)
      assert p2p_assigns(ctx.view_a) == nil
      refute render(ctx.view_a) =~ "p2p-stats-window"
    end
  end

  describe "files window" do
    test "mounts with the session, reacts to ft_* events, and feeds the summary",
         %{conn: conn} do
      ctx = mount_pair(conn, "p2pfq#{uid()}", "p2pfr#{uid()}")
      session = invite(ctx)
      render_click(ctx.view_b, "p2p_accept_invite", %{"token" => session.token})
      flush(ctx.view_a)

      # The window (and its island/hook) is always mounted while joined.
      assert render(ctx.view_b) =~ "p2p-files-window"

      # The WebRTC hook reports the link up; the panel unlocks on :connected.
      render_click(ctx.view_b, "lobby_connected", %{})
      assert %{state: :connected} = p2p_assigns(ctx.view_b)

      # An incoming offer flows hook → host adapter → island, opens the
      # window and mirrors the C2 summary up to the host.
      render_click(ctx.view_b, "file_transfer_ready", %{})

      render_click(ctx.view_b, "ft_offer_received", %{
        "file_name" => "relatorio.pdf",
        "formatted_size" => "1.2 MB"
      })

      flush(ctx.view_b)

      assert %{file_summary: %{status: "offer_received", file_name: "relatorio.pdf"}} =
               p2p_assigns(ctx.view_b)

      assert render(ctx.view_b) =~ "relatorio.pdf"
    end
  end

  describe "one session at a time (switch)" do
    test "accepting a second invite asks to switch and ends the first session", %{conn: conn} do
      ctx = mount_pair(conn, "p2pfi#{uid()}", "p2pfj#{uid()}")
      c = register("p2pfk#{uid()}")
      {:ok, view_c, _} = live(chat_conn(conn, c.nickname, pre_identified: true), "/chat")

      # A ↔ B session up and joined (A joins upon B's accept).
      session_ab = invite(ctx)
      render_click(ctx.view_b, "p2p_accept_invite", %{"token" => session_ab.token})
      flush(ctx.view_a)
      assert %{state: :joining} = p2p_assigns(ctx.view_b)

      # C invites B while B is busy — the invite must be delivered normally.
      submit_command_sync(view_c, "/p2p #{ctx.b.nickname}")
      session_cb = Lobby.active_session_for_user(c.id)
      assert session_cb

      # Accepting stashes the target and opens the confirm; nothing ends yet.
      flush(ctx.view_b)
      render_click(ctx.view_b, "p2p_accept_invite", %{"token" => session_cb.token})
      assert %{state: :joining} = p2p_assigns(ctx.view_b)
      assert {:ok, %{status: "lobby"}} = Lobby.get_session(session_ab.token)

      # Confirming ends A↔B and joins C↔B.
      render_click(ctx.view_b, "p2p_confirm_switch", %{})

      assert {:ok, %{status: "closed"}} = Lobby.get_session(session_ab.token)
      assert %{state: :joining, token: token} = p2p_assigns(ctx.view_b)
      assert token == session_cb.token

      flush(ctx.view_a)
      assert p2p_assigns(ctx.view_a) == nil
    end

    test "an outgoing /p2p while busy confirms before the invite PM is sent", %{conn: conn} do
      ctx = mount_pair(conn, "p2pfl#{uid()}", "p2pfm#{uid()}")
      c = register("p2pfn#{uid()}")
      {:ok, _view_c, _} = live(chat_conn(conn, c.nickname, pre_identified: true), "/chat")

      session_ab = invite(ctx)
      render_click(ctx.view_b, "p2p_accept_invite", %{"token" => session_ab.token})
      flush(ctx.view_a)

      # A tries to invite C while in a session with B: session B stays alive
      # until the switch is confirmed.
      submit_command_sync(ctx.view_a, "/p2p #{c.nickname}")
      assert %{token: token_ab} = p2p_assigns(ctx.view_a)
      assert token_ab == session_ab.token
      assert {:ok, %{status: "lobby"}} = Lobby.get_session(session_ab.token)

      render_click(ctx.view_a, "p2p_confirm_switch", %{})

      assert {:ok, %{status: "closed"}} = Lobby.get_session(session_ab.token)
      assert %{state: :invite_sent, role: :creator, token: new_token} = p2p_assigns(ctx.view_a)
      assert new_token != session_ab.token
    end
  end
end
