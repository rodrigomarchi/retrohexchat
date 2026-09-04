defmodule RetroHexChatWeb.App.DeadRenderTest do
  @moduledoc """
  A surface's first render is a paint, never a commitment.

  Every one of these addresses is fetched twice — once as plain HTML, once over
  the socket — because that is what a LiveView `mount/3` does. So a write in
  `mount/3` runs for anybody who merely *fetches* the page: a speculative
  prefetch, an extension, a link scanner behind an authenticated proxy, or a
  person who pressed Escape before the socket opened.

  Two writes used to live there, and each had its own consequence. Claiming a
  match seat burned the link with nobody in it. Joining a session with
  `takeover: true` handed the seat to the HTTP request process — dead before the
  browser connected — which is the takeover contract firing for a prefetch, and
  the displaced window is somebody's running call.

  These tests use `get/2` on purpose. `live/2` always connects, so the connected
  mount repairs whatever the dead one did and the whole class becomes invisible.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Lobby
  alias RetroHexChat.Lobby.Registry
  alias RetroHexChat.Services.NickServ
  alias RetroHexChat.Services.RegisteredNick

  @game "hex_pong"

  defp register(prefix) do
    nickname = "#{prefix}#{uid()}" |> String.slice(0, 16)

    {:ok, nick} =
      %RegisteredNick{}
      |> RegisteredNick.registration_changeset(%{nickname: nickname, password: "password123"})
      |> RetroHexChat.Repo.insert()

    NickServ.restore_identified(nick.nickname)
    on_exit(fn -> NickServ.remove_identified(nick.nickname) end)
    nick
  end

  defp stop_session_later(token) do
    on_exit(fn ->
      case Registry.lookup(token) do
        {:ok, pid} ->
          try do
            GenServer.stop(pid, :normal)
          catch
            :exit, _reason -> :ok
          end

        _absent ->
          :ok
      end
    end)
  end

  defp connections(token) do
    case Registry.lookup(token) do
      {:ok, pid} -> :sys.get_state(pid).connections
      _absent -> :no_server
    end
  end

  describe "a match address" do
    setup do
      host = register("DrHost")
      guest = register("DrGuest")

      {:ok, %{session: session}} =
        Lobby.create_open_session(host.id, metadata: %{"game_id" => @game})

      stop_session_later(session.token)
      %{host: host, guest: guest, session: session}
    end

    test "fetching it does not take the seat", ctx do
      %{conn: conn, guest: guest, session: session} = ctx

      conn
      |> chat_conn(guest.nickname)
      |> get(~p"/play/#{@game}/#{session.token}")
      |> then(&assert(&1.status == 200))

      assert {:ok, %{status: "open", peer_id: nil}} = Lobby.get_session(session.token)
    end

    test "opening it over the socket does take the seat", ctx do
      %{conn: conn, guest: guest, session: session} = ctx

      {:ok, _view, _html} =
        conn |> chat_conn(guest.nickname) |> live(~p"/play/#{@game}/#{session.token}")

      assert {:ok, %{status: "pending", peer_id: peer_id}} = Lobby.get_session(session.token)
      assert peer_id == guest.id
    end

    # A claim is not reversible: `open` is the only status the link is followable
    # in, and the session it becomes runs forward to `expired` or `closed` and
    # never back. That is why the seat must not be taken by a fetch — nothing
    # returns the link to the state it was shared in.
    test "a claimed seat never returns the link to open", ctx do
      %{conn: conn, guest: guest, session: session} = ctx

      {:ok, _view, _html} =
        conn |> chat_conn(guest.nickname) |> live(~p"/play/#{@game}/#{session.token}")

      assert {:ok, claimed} = Lobby.get_session(session.token)
      refute claimed.status == "open"
      refute Lobby.open_session?(claimed)
    end
  end

  describe "a P2P session address" do
    setup do
      creator = register("DrCreator")
      peer = register("DrPeer")

      {:ok, %{session: session}} = Lobby.create_session(creator.id, peer.id)
      stop_session_later(session.token)
      %{creator: creator, peer: peer, session: session}
    end

    # The sharpest of the two: `attach_session/5` joins with `takeover: true`, so
    # a fetch that reached it would move the seat out of whichever window is
    # holding it — and into a process that is already gone.
    test "fetching it does not attach a connection or displace the holder", ctx do
      %{conn: conn, peer: peer, session: session} = ctx

      assert %{peer: nil, creator: nil} = connections(session.token)

      conn
      |> chat_conn(peer.nickname)
      |> get(~p"/p2p/#{session.token}")
      |> then(&assert(&1.status == 200))

      assert %{peer: nil, creator: nil} = connections(session.token)
    end

    test "opening it over the socket does attach the connection", ctx do
      %{conn: conn, peer: peer, session: session} = ctx

      {:ok, _view, _html} = conn |> chat_conn(peer.nickname) |> live(~p"/p2p/#{session.token}")

      assert %{peer: %{pid: pid}} = connections(session.token)
      assert is_pid(pid)
    end
  end

  # The refusals must not need a socket either: a page that only says "you may
  # not" on connect is a page that flashes the room at somebody who was refused.
  describe "a refusal survives the dead render" do
    test "a stranger at a running match is told the seat is gone", %{conn: conn} do
      host = register("DrFullH")
      first = register("DrFullA")
      late = register("DrFullL")

      {:ok, %{session: session}} =
        Lobby.create_open_session(host.id, metadata: %{"game_id" => @game})

      stop_session_later(session.token)

      {:ok, _claimed} = Lobby.claim_open_session(session.token, first.id)

      html =
        conn
        |> chat_conn(late.nickname)
        |> get(~p"/play/#{@game}/#{session.token}")
        |> html_response(200)

      assert html =~ ~s(data-testid="p2p-denied")
    end
  end
end
