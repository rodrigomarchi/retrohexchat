defmodule RetroHexChatWeb.App.P2PLiveTest do
  @moduledoc """
  The P2P session at an address of its own.

  What is asserted here is the half of the surface the chat cannot supply: a
  token in the address bar instead of a session the chat already opened, every
  gate applied here instead of upstream, and a refusal that says the policy's
  own sentence rather than a generic screen — plus the starting room, which is
  the one screen this wave added. The other half — being in a session — is the
  same module the chat renders, and `p2p_session_flow_test.exs` exercises it
  there.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Lobby
  alias RetroHexChat.Lobby.Registry
  alias RetroHexChat.Lobby.Schema.Session, as: LobbySession
  alias RetroHexChat.Services.NickServ
  alias RetroHexChat.Services.RegisteredNick
  alias RetroHexChat.ShareLinks

  defp register(prefix) do
    nickname = "#{prefix}#{uid()}" |> String.slice(0, 16)

    {:ok, nick} =
      %RegisteredNick{}
      |> RegisteredNick.registration_changeset(%{nickname: nickname, password: "password123"})
      |> RetroHexChat.Repo.insert()

    nick
  end

  defp identify(nick) do
    NickServ.restore_identified(nick.nickname)
    on_exit(fn -> NickServ.remove_identified(nick.nickname) end)
    nick
  end

  defp open_session(creator, peer) do
    {:ok, session} = Lobby.create_session(creator.id, peer.id)

    on_exit(fn ->
      case Registry.lookup(session.token) do
        {:ok, pid} -> stop_session(pid)
        {:error, :not_found} -> :ok
      end
    end)

    session
  end

  defp stop_session(pid) do
    GenServer.stop(pid, :normal)
  catch
    :exit, _reason -> :ok
  end

  defp assigns(view), do: :sys.get_state(view.pid).socket.assigns

  defp stop_liveview(view) do
    ref = Process.monitor(view.pid)
    GenServer.stop(view.pid, :normal)
    assert_receive {:DOWN, ^ref, :process, _pid, _reason}, 2_000
    :ok
  end

  defp redirected_to_connect({:error, {_kind, %{to: to}}}), do: to == "/connect"
  defp redirected_to_connect(_other), do: false

  @setup_defaults %{"audio" => "true", "video" => "true", "turn_only" => "false"}

  describe "who may open it" do
    test "no session goes to connect", %{conn: conn} do
      assert redirected_to_connect(live(conn, ~p"/p2p/whatever"))
    end

    # The most common thing a shared link is, by a wide margin: a link outlives
    # the session it names by days.
    test "a token that names no session says so", %{conn: conn} do
      nick = register("Gone") |> identify()

      {:ok, _view, html} = conn |> chat_conn(nick.nickname) |> live(~p"/p2p/nosuchtoken")

      assert html =~ "This P2P session is no longer available"
      assert html =~ ~s(data-testid="p2p-denied")
    end

    test "a closed session reads the same as one that never existed", %{conn: conn} do
      creator = register("Cr") |> identify()
      peer = register("Pe") |> identify()
      session = open_session(creator, peer)

      :ok = Lobby.close_session(session.token, creator.id, "user_closed")

      {:ok, _view, html} =
        conn |> chat_conn(creator.nickname) |> live(~p"/p2p/#{session.token}")

      assert html =~ ~s(data-testid="p2p-denied")
    end

    # Being a participant is recorded as a registered-nick id, so registration
    # alone would let whoever is currently holding the nickname walk into a
    # session that belongs to the person who owns it.
    test "a registered nickname that has not identified is refused", %{conn: conn} do
      creator = register("Cr")
      peer = register("Pe") |> identify()
      session = open_session(creator, peer)

      {:ok, _view, html} =
        conn |> chat_conn(creator.nickname) |> live(~p"/p2p/#{session.token}")

      assert html =~ ~s(data-testid="p2p-denied")
      assert html =~ "identified with NickServ"
      refute html =~ ~s(data-testid="p2p-starting-room")
    end

    test "an unregistered nickname is told so, in the policy's words", %{conn: conn} do
      creator = register("Cr") |> identify()
      peer = register("Pe") |> identify()
      session = open_session(creator, peer)

      {:ok, _view, html} =
        conn |> chat_conn("stranger#{uid()}") |> live(~p"/p2p/#{session.token}")

      assert html =~ "registered with NickServ"
    end

    test "somebody who is not in the session is refused, in the policy's words", %{conn: conn} do
      creator = register("Cr") |> identify()
      peer = register("Pe") |> identify()
      outsider = register("Out") |> identify()
      session = open_session(creator, peer)

      {:ok, _view, html} =
        conn |> chat_conn(outsider.nickname) |> live(~p"/p2p/#{session.token}")

      assert html =~ ~s(data-testid="p2p-denied")
      assert html =~ "not a participant"
      refute html =~ ~s(data-testid="p2p-starting-room")
    end
  end

  describe "the starting room" do
    setup %{conn: conn} do
      creator = register("Host") |> identify()
      peer = register("Guest") |> identify()
      session = open_session(creator, peer)

      {:ok, view, html} =
        conn |> chat_conn(creator.nickname) |> live(~p"/p2p/#{session.token}")

      %{creator: creator, peer: peer, session: session, view: view, html: html}
    end

    test "it is the first render, and the session is not armed yet", ctx do
      assert ctx.html =~ ~s(data-testid="p2p-starting-room")
      assert ctx.html =~ ~s(data-testid="p2p-room-roster")
      refute ctx.html =~ ~s(data-testid="p2p-session-console")

      # A hook mounted here would report readiness for devices nobody has
      # chosen, and readiness is half of what makes the first offer safe.
      refute ctx.html =~ ~s(data-testid="p2p-webrtc")
    end

    test "both seats are drawn and the wait names whose it is", ctx do
      assert ctx.html =~ ctx.creator.nickname
      assert ctx.html =~ ctx.peer.nickname
      assert ctx.html =~ "(host)"
      assert ctx.html =~ "Choose your devices, then press Ready."
    end

    test "Ready arms the anchor and the wait moves to the peer", ctx do
      html = render_submit(ctx.view, "p2p_room_ready", %{"p2p_setup" => @setup_defaults})

      assert html =~ ~s(data-testid="p2p-webrtc")
      assert html =~ "Waiting for #{ctx.peer.nickname} to accept the invite."
      assert assigns(ctx.view).p2p_session.room_ready
    end

    test "Start is the creator's and stays disabled until both are ready", ctx do
      assert has_element?(ctx.view, ~s([data-testid="p2p-room-start"][disabled]))

      render_submit(ctx.view, "p2p_room_ready", %{"p2p_setup" => @setup_defaults})
      render_click(ctx.view, "lobby_webrtc_ready", %{})

      # Only this side is ready, so nothing may be offered yet.
      assert has_element?(ctx.view, ~s([data-testid="p2p-room-start"][disabled]))
      refute_push_event(ctx.view, "lobby_start_offer", %{})
    end

    test "no offer is emitted before Start, and Start emits exactly one", ctx do
      render_submit(ctx.view, "p2p_room_ready", %{"p2p_setup" => @setup_defaults})
      render_click(ctx.view, "lobby_webrtc_ready", %{})

      # The peer arrives and reports ready, which fires the domain's gate.
      :ok = Lobby.join_session(ctx.session.token, ctx.peer.id)
      :ok = Lobby.mark_webrtc_ready(ctx.session.token, ctx.peer.id)

      assert_receive %{event: "lobby_start_signaling"}, 2_000
      :sys.get_state(ctx.view.pid)

      # The gate opened; the offer still waits for the host.
      refute_push_event(ctx.view, "lobby_start_offer", %{})
      assert has_element?(ctx.view, ~s([data-testid="p2p-room-start"]))
      refute has_element?(ctx.view, ~s([data-testid="p2p-room-start"][disabled]))

      render_click(ctx.view, "p2p_room_start", %{})

      assert_push_event(ctx.view, "lobby_start_offer", %{role: "creator"}, 2_000)
      assert assigns(ctx.view).p2p_session.session_started
      assert render(ctx.view) =~ ~s(data-testid="p2p-session-console")
    end

    test "the peer sees Ready but never Start", %{conn: conn} = ctx do
      {:ok, peer_view, html} =
        build_conn()
        |> chat_conn(ctx.peer.nickname, pre_identified: true)
        |> live(~p"/p2p/#{ctx.session.token}")

      _ = conn
      assert html =~ ~s(data-testid="p2p-room-ready")
      refute html =~ ~s(data-testid="p2p-room-start")
      assert %{role: :peer} = assigns(peer_view).p2p_session
    end

    test "the host cancelling before Start kills the session and the link", ctx do
      {:ok, link} =
        ShareLinks.create(%{
          kind: "p2p",
          target: %{"session_token" => ctx.session.token},
          creator_id: ctx.creator.id,
          creator_nick: ctx.creator.nickname
        })

      assert {:ok, %{live?: true}} = ShareLinks.describe(link.slug)

      render_click(ctx.view, "p2p_end_session", %{})

      assert {:ok, %{status: "closed", closed_reason: "invite_cancelled"}} =
               Lobby.get_session(ctx.session.token)

      assert {:ok, %{live?: false}} = ShareLinks.describe(link.slug)
    end
  end

  # The same rule the conference has: the room decides who is in the session,
  # not the tab. A page going away starts the rejoin grace; only an explicit
  # end is terminal.
  describe "a page going away" do
    setup %{conn: conn} do
      creator = register("Host") |> identify()
      peer = register("Guest") |> identify()
      session = open_session(creator, peer)

      {:ok, view, _html} =
        conn |> chat_conn(creator.nickname) |> live(~p"/p2p/#{session.token}")

      %{creator: creator, peer: peer, session: session, view: view}
    end

    test "an unexpected terminate does not end the session", ctx do
      render_submit(ctx.view, "p2p_room_ready", %{"p2p_setup" => @setup_defaults})
      render_click(ctx.view, "lobby_webrtc_ready", %{})

      stop_liveview(ctx.view)

      assert {:ok, %{status: status}} = Lobby.get_session(ctx.session.token)
      refute LobbySession.terminal?(status)
    end

    test "and the address still works when it comes back", ctx do
      stop_liveview(ctx.view)

      {:ok, _view, html} =
        build_conn()
        |> chat_conn(ctx.creator.nickname, pre_identified: true)
        |> live(~p"/p2p/#{ctx.session.token}")

      assert html =~ ~s(data-testid="p2p-starting-room")
      refute html =~ ~s(data-testid="p2p-denied")
    end
  end

  describe "sharing" do
    test "the host mints a link that resolves back to this session", %{conn: conn} do
      creator = register("Host") |> identify()
      peer = register("Guest") |> identify()
      session = open_session(creator, peer)

      {:ok, view, _html} =
        conn |> chat_conn(creator.nickname) |> live(~p"/p2p/#{session.token}")

      render_click(view, "share_p2p", %{})

      url = assigns(view).share_url
      assert is_binary(url)

      slug = url |> String.split("/join/") |> List.last()

      assert {:ok, %{kind: "p2p", target: %{"session_token" => token}}} =
               ShareLinks.describe(slug)

      assert token == session.token
    end
  end

  describe "a reload while the session is up" do
    test "goes straight inside instead of asking for Ready again", %{conn: conn} do
      creator = register("Host") |> identify()
      peer = register("Guest") |> identify()
      session = open_session(creator, peer)

      :ok = Lobby.join_session(session.token, creator.id)
      :ok = Lobby.join_session(session.token, peer.id)
      :ok = Lobby.transition_status(session.token, :connected)

      {:ok, view, html} =
        conn |> chat_conn(creator.nickname) |> live(~p"/p2p/#{session.token}")

      # Being sent back to the starting room mid-call would be the surface
      # losing the call it is showing.
      refute html =~ ~s(data-testid="p2p-starting-room")
      assert html =~ ~s(data-testid="p2p-session-console")
      assert html =~ ~s(data-testid="p2p-webrtc")
      assert %{session_started: true, room_ready: true} = assigns(view).p2p_session
    end
  end
end
