defmodule RetroHexChatWeb.SpectateChannelTest do
  @moduledoc """
  A match relayed to the people watching it: who may send frames, who may
  receive them, and what the server refuses to carry.
  """
  use RetroHexChatWeb.ChannelCase, async: false

  alias RetroHexChat.Lobby
  alias RetroHexChat.Lobby.JoinToken
  alias RetroHexChat.Lobby.SessionServer
  alias RetroHexChat.Repo
  alias RetroHexChat.Services.RegisteredNick
  alias RetroHexChatWeb.UserSocket

  @moduletag :integration

  defp uid, do: System.unique_integer([:positive])

  defp registered(prefix) do
    nickname = "#{prefix}#{uid()}" |> String.slice(0, 16)

    {:ok, nick} =
      %RegisteredNick{}
      |> RegisteredNick.registration_changeset(%{nickname: nickname, password: "password123"})
      |> Repo.insert()

    nick
  end

  # A seat offered in the open, taken, connected and playing Hex Pong, the
  # creator hosting.
  defp match_in_play do
    host = registered("host")
    guest = registered("guest")

    {:ok, %{token: token}} =
      Lobby.create_open_session(host.id, metadata: %{"game_id" => "hex_pong"})

    {:ok, _claimed} = Lobby.claim_open_session(token, guest.id)
    on_exit(fn -> Lobby.close_session(token, host.id, "test_cleanup") end)

    :ok = SessionServer.join(token, host.id)
    :ok = SessionServer.join(token, guest.id)
    :ok = SessionServer.transition(token, :connected)
    :ok = SessionServer.propose_game(token, host.id, host.nickname, "hex_pong")
    :ok = SessionServer.respond_game(token, guest.id, guest.nickname, true)

    %{token: token, host: host, guest: guest}
  end

  defp watch(token) do
    {:ok, socket} = connect(UserSocket, %{})
    subscribe_and_join(socket, "spectate:#{token}", %{})
  end

  defp host_wire(token, nick) do
    {:ok, socket} = connect(UserSocket, %{})

    subscribe_and_join(socket, "spectate:#{token}", %{
      "join_token" => JoinToken.sign(token, nick.id, nick.nickname)
    })
  end

  test "the host's frames reach everybody watching, as they were sent" do
    %{token: token, host: host} = match_in_play()
    {:ok, _reply, _watcher} = watch(token)
    {:ok, _reply, host_socket} = host_wire(token, host)

    frame = <<0x80, 1, 2, 3>>
    push(host_socket, "frame", {:binary, frame})

    assert_push "frame", {:binary, ^frame}
  end

  test "the guest is no host: its frames are refused at the join" do
    %{token: token, guest: guest} = match_in_play()
    assert {:error, %{reason: "not_host"}} = host_wire(token, guest)
  end

  test "a frame too large, or past the rate, is dropped" do
    %{token: token, host: host} = match_in_play()
    {:ok, _reply, _watcher} = watch(token)
    {:ok, _reply, host_socket} = host_wire(token, host)

    push(host_socket, "frame", {:binary, :binary.copy(<<0x80>>, 5000)})
    refute_push "frame", _payload, 100

    for n <- 1..40, do: push(host_socket, "frame", {:binary, <<0x80, n>>})
    _ = :sys.get_state(host_socket.channel_pid)

    relayed = Enum.count(1..40, fn _n -> receive_frame?() end)
    assert relayed <= 30
  end

  defp receive_frame? do
    receive do
      %Phoenix.Socket.Message{event: "frame"} -> true
    after
      50 -> false
    end
  end

  test "a game starting and ending is told to whoever watches" do
    %{token: token, host: host} = match_in_play()
    {:ok, _reply, _watcher} = watch(token)

    :ok = SessionServer.end_game(token, host.id)
    assert_push "game", %{status: "idle"}
  end

  test "a session one person invited another to cannot be watched" do
    creator = registered("cre")
    peer = registered("peer")
    {:ok, %{token: token}} = Lobby.create_session(creator.id, peer.id)
    on_exit(fn -> Lobby.close_session(token, creator.id, "test_cleanup") end)

    assert {:error, %{reason: "not_watchable"}} = watch(token)
    assert {:error, %{reason: "not_found"}} = watch("no-such-session")
  end
end
