defmodule RetroHexChatWeb.App.PlayMatchTest do
  @moduledoc """
  A multiplayer match at `/play/:game/:token`.

  The surface is the same `P2PLive` the chat renders and `/p2p/:token` serves;
  what this file asserts is the half only a match has — a seat that is empty
  until somebody follows the link, a starting room with a game in it instead of
  devices, and the door refusing the person who arrived second.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Games.Catalog
  alias RetroHexChat.Lobby
  alias RetroHexChat.Lobby.Registry
  alias RetroHexChat.Services.NickServ
  alias RetroHexChat.Services.RegisteredNick

  @game "hex_pong"
  @setup_defaults %{"audio" => "false", "video" => "false", "turn_only" => "false"}

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

  defp match_lobby(creator, opts \\ []) do
    {:ok, %{session: session}} =
      Lobby.create_open_session(
        creator.id,
        Keyword.merge([metadata: %{"game_id" => @game}], opts)
      )

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

  describe "the host's room, before anybody has taken the seat" do
    setup %{conn: conn} do
      host = register("MHost") |> identify()
      session = match_lobby(host)

      {:ok, view, html} =
        conn |> chat_conn(host.nickname) |> live(~p"/play/#{@game}/#{session.token}")

      %{host: host, session: session, view: view, html: html}
    end

    test "the room opens on the game, not on a console", ctx do
      assert ctx.html =~ ~s(data-testid="p2p-starting-room")
      refute ctx.html =~ ~s(data-testid="p2p-session-console")
    end

    # A game has no camera to choose, and the half of the room that chooses one
    # is exactly the half a match does not have.
    test "the device half is gone and the game is in its place", ctx do
      {:ok, game} = Catalog.get_game(@game)

      assert ctx.html =~ ~s(data-testid="p2p-room-game")
      assert ctx.html =~ game.name
      refute ctx.html =~ ~s(data-testid="p2p-setup-preview")
      refute ctx.html =~ ~s(data-testid="p2p-setup-audio-input")
      refute ctx.html =~ ~s(data-testid="p2p-setup-advanced")
    end

    test "the empty seat is drawn as open, and names nobody", ctx do
      assert ctx.html =~ ~s(data-testid="p2p-room-roster")
      assert ctx.html =~ "seat open"
      assert ctx.html =~ "Press Ready when the game has your attention."

      # And once the host is ready, the wait is on the seat rather than on a
      # person: a match link has nobody to name yet.
      html = render_submit(ctx.view, "p2p_room_ready", %{"p2p_setup" => @setup_defaults})
      assert html =~ "the match starts when somebody takes the seat"
    end

    # Submitted as the browser submits it, not with hand-written params: the
    # game room has no device fields, so a form that carried none would arrive
    # without `p2p_setup` at all and `[Ready]` would quietly do nothing. Only
    # rendering the real form catches that.
    test "Ready works from the form the room actually renders", ctx do
      html =
        ctx.view
        |> form(~s(#p2p-starting-room-form))
        |> render_submit()

      assert assigns(ctx.view).p2p_session.room_ready
      assert html =~ ~s(data-testid="p2p-webrtc")

      # And a match asks for nothing to send: a game has no camera.
      assert assigns(ctx.view).setup.media == %{audio: false, video: false}
    end

    test "Start belongs to the host and waits for the seat to be taken", ctx do
      assert has_element?(ctx.view, ~s([data-testid="p2p-room-start"][disabled]))

      render_submit(ctx.view, "p2p_room_ready", %{"p2p_setup" => @setup_defaults})
      render_click(ctx.view, "lobby_webrtc_ready", %{})

      assert has_element?(ctx.view, ~s([data-testid="p2p-room-start"][disabled]))
      refute_push_event(ctx.view, "lobby_start_offer", %{})
    end

    # P7: the room does not outlive its host, and the link dies with the room
    # rather than standing until the deadline.
    test "the host can cancel the match, and the link dies with it", ctx do
      assert has_element?(ctx.view, ~s([data-testid="p2p-room-cancel"]))

      render_click(ctx.view, "p2p_room_cancel", %{})

      {:ok, closed} = Lobby.get_session(ctx.session.token)
      assert closed.status == "closed"
      assert closed.closed_reason == "invite_cancelled"
    end

    test "Share mints a game link that carries the session", ctx do
      render_click(ctx.view, "share_p2p", %{})

      assert has_element?(ctx.view, ~s([data-testid="share-url"]))
      url = assigns(ctx.view).share_url
      assert is_binary(url)

      slug = url |> String.split("/") |> List.last()
      assert {:ok, resolution} = RetroHexChat.ShareLinks.describe(slug)
      assert resolution.kind == "play"
      assert resolution.target["game_id"] == @game
      assert resolution.target["session_token"] == ctx.session.token
    end
  end

  describe "somebody follows the link" do
    setup %{conn: conn} do
      host = register("MHost") |> identify()
      guest = register("MGuest") |> identify()
      session = match_lobby(host)

      %{conn: conn, host: host, guest: guest, session: session}
    end

    test "opening the address takes the seat", ctx do
      {:ok, _view, html} =
        ctx.conn |> chat_conn(ctx.guest.nickname) |> live(~p"/play/#{@game}/#{ctx.session.token}")

      assert html =~ ~s(data-testid="p2p-starting-room")

      {:ok, claimed} = Lobby.get_session(ctx.session.token)
      assert claimed.peer_id == ctx.guest.id
      assert claimed.status in ["pending", "lobby"]
    end

    # The one link in the plan that dies by succeeding.
    test "the second arrival is told the match is full, and not who filled it", ctx do
      latecomer = register("MLate") |> identify()

      {:ok, _view, _html} =
        ctx.conn |> chat_conn(ctx.guest.nickname) |> live(~p"/play/#{@game}/#{ctx.session.token}")

      {:ok, _view, html} =
        ctx.conn
        |> chat_conn(latecomer.nickname)
        |> live(~p"/play/#{@game}/#{ctx.session.token}")

      assert html =~ ~s(data-testid="p2p-denied")
      assert html =~ "already full"
      refute html =~ ctx.guest.nickname
    end

    # Only the creator may offer, so only the creator may start — and only the
    # creator may call the whole thing off.
    test "the guest has neither Start nor Cancel", ctx do
      {:ok, guest_view, _html} =
        ctx.conn |> chat_conn(ctx.guest.nickname) |> live(~p"/play/#{@game}/#{ctx.session.token}")

      assert has_element?(guest_view, ~s([data-testid="p2p-room-ready"]))
      refute has_element?(guest_view, ~s([data-testid="p2p-room-start"]))
      refute has_element?(guest_view, ~s([data-testid="p2p-room-cancel"]))
    end

    test "the host following their own link keeps the room and takes no seat", ctx do
      {:ok, _view, html} =
        ctx.conn |> chat_conn(ctx.host.nickname) |> live(~p"/play/#{@game}/#{ctx.session.token}")

      assert html =~ ~s(data-testid="p2p-starting-room")
      assert Lobby.get_session(ctx.session.token) |> elem(1) |> Map.get(:peer_id) == nil
    end

    test "an expired match link is not a seat", ctx do
      expired = match_lobby(ctx.host, expires_in_ms: -1_000)

      {:ok, _view, html} =
        ctx.conn |> chat_conn(ctx.guest.nickname) |> live(~p"/play/#{@game}/#{expired.token}")

      assert html =~ ~s(data-testid="p2p-denied")
      assert html =~ "expired"
    end

    test "a registered nickname that has not identified takes no seat", ctx do
      stranger = register("MStr")

      {:ok, _view, html} =
        ctx.conn |> chat_conn(stranger.nickname) |> live(~p"/play/#{@game}/#{ctx.session.token}")

      assert html =~ "identified with NickServ"
      assert Lobby.get_session(ctx.session.token) |> elem(1) |> Map.get(:peer_id) == nil
    end

    test "an unregistered nickname takes no seat", ctx do
      {:ok, _view, html} =
        ctx.conn |> chat_conn("mstr#{uid()}") |> live(~p"/play/#{@game}/#{ctx.session.token}")

      assert html =~ "registered with NickServ"
      assert Lobby.get_session(ctx.session.token) |> elem(1) |> Map.get(:peer_id) == nil
    end
  end

  # The link named the game and both sides agreed to it by being here, so the
  # match starts without a second question. Two real LiveViews, because the
  # thing being asserted is what one of them does when the other one moves.
  describe "the game the link named" do
    test "starts itself once the two are connected, with no accept step", %{conn: conn} do
      host = register("MHost") |> identify()
      guest = register("MGuest") |> identify()
      session = match_lobby(host)

      {:ok, host_view, _html} =
        conn |> chat_conn(host.nickname) |> live(~p"/play/#{@game}/#{session.token}")

      {:ok, guest_view, _html} =
        conn |> chat_conn(guest.nickname) |> live(~p"/play/#{@game}/#{session.token}")

      for view <- [host_view, guest_view] do
        render_submit(view, "p2p_room_ready", %{"p2p_setup" => @setup_defaults})
        render_click(view, "lobby_webrtc_ready", %{})
      end

      render_click(host_view, "p2p_room_start", %{})

      # The WebRTC link coming up is what puts the game on the table.
      render_click(host_view, "lobby_connected", %{})
      render_click(guest_view, "lobby_connected", %{})

      assert {:ok, state} = Lobby.session_info(session.token)
      assert state.game.status == "playing"
      assert state.game.game_id == @game
      assert state.game.host_id == host.id

      # And the console opens on the game rather than on the call.
      assert assigns(host_view).p2p_session.console_section == "games"
      assert assigns(guest_view).p2p_session.console_section == "games"
    end
  end

  describe "the address a match keeps" do
    test "the session is what says it is a match, not the path", %{conn: conn} do
      host = register("MHost") |> identify()
      session = match_lobby(host)

      # Opened at the plain P2P address, it is still the match it was made as.
      {:ok, _view, html} =
        conn |> chat_conn(host.nickname) |> live(~p"/p2p/#{session.token}")

      assert html =~ ~s(data-testid="p2p-room-game")
    end

    test "a plain session opened at a match address is still a plain session", %{conn: conn} do
      host = register("MHost") |> identify()
      peer = register("MPeer") |> identify()
      {:ok, session} = Lobby.create_session(host.id, peer.id)

      on_exit(fn ->
        case Registry.lookup(session.token) do
          {:ok, pid} -> stop_session(pid)
          {:error, :not_found} -> :ok
        end
      end)

      {:ok, _view, html} =
        conn |> chat_conn(host.nickname) |> live(~p"/play/#{@game}/#{session.token}")

      refute html =~ ~s(data-testid="p2p-room-game")
      assert html =~ ~s(data-testid="p2p-setup-preview")
    end
  end

  describe "where a match is born" do
    test "the games surface creates one and lands the host in its room", %{conn: conn} do
      host = register("MHost") |> identify()

      {:ok, view, _html} = conn |> chat_conn(host.nickname) |> live(~p"/play/#{@game}")

      assert has_element?(view, ~s([data-testid="play-create-match"]))

      assert {:error, {:live_redirect, %{to: to}}} =
               render_click(view, "create_match", %{})

      assert to =~ "/play/#{@game}/"

      token = to |> String.split("/") |> List.last()
      assert {:ok, created} = Lobby.get_session(token)
      assert created.status == "open"
      assert created.peer_id == nil
      assert created.creator_id == host.id
      assert Lobby.match_game_id(created) == @game

      on_exit(fn ->
        case Registry.lookup(token) do
          {:ok, pid} -> stop_session(pid)
          {:error, :not_found} -> :ok
        end
      end)
    end

    test "an unregistered nickname is not offered one", %{conn: conn} do
      {:ok, view, _html} = conn |> chat_conn("mstr#{uid()}") |> live(~p"/play/#{@game}")

      refute has_element?(view, ~s([data-testid="play-create-match"]))
    end
  end
end
