defmodule RetroHexChatWeb.GroupCallChannelTest do
  use RetroHexChatWeb.ChannelCase, async: false

  alias RetroHexChat.Channels.Registry, as: ChannelRegistry
  alias RetroHexChat.Channels.{Server, Supervisor}
  alias RetroHexChat.GroupCall
  alias RetroHexChat.GroupCall.{JoinToken, Registry}
  alias RetroHexChat.Repo
  alias RetroHexChat.Services.RegisteredNick
  alias RetroHexChatWeb.UserSocket

  @moduletag :integration

  setup do
    previous_port_range = Application.get_env(:retro_hex_chat, :sfu_ice_port_range)
    previous_signal_limit = Application.get_env(:retro_hex_chat, :group_call_signal_rate_limit)
    Application.put_env(:retro_hex_chat, :sfu_ice_port_range, [0])

    on_exit(fn ->
      restore_env(:sfu_ice_port_range, previous_port_range)
      restore_env(:group_call_signal_rate_limit, previous_signal_limit)
    end)

    :ok
  end

  defp restore_env(key, nil), do: Application.delete_env(:retro_hex_chat, key)
  defp restore_env(key, value), do: Application.put_env(:retro_hex_chat, key, value)

  defp uid, do: System.unique_integer([:positive])
  defp unique_channel, do: "#gcchan#{uid()}"
  defp unique_nick(prefix), do: "#{prefix}#{uid()}" |> String.slice(0, 16)

  defp create_registered_nick(nickname) do
    {:ok, nick} =
      %RegisteredNick{}
      |> RegisteredNick.registration_changeset(%{nickname: nickname, password: "password123"})
      |> Repo.insert()

    nick
  end

  defp start_channel(channel) do
    {:ok, pid} = Supervisor.start_child(channel)

    on_exit(fn ->
      case ChannelRegistry.lookup(channel) do
        {:ok, ^pid} -> Supervisor.stop_child(pid)
        _ -> :ok
      end
    end)

    {:ok, pid}
  end

  defp create_call(channel, nick) do
    {:ok, _pid} = start_channel(channel)
    {:ok, _state} = Server.join(channel, nick.nickname, nil, identified: true)

    {:ok, %{room: room, token: token}} =
      GroupCall.create_channel_call(channel, %{user_id: nick.id, nickname: nick.nickname})

    on_exit(fn ->
      case Registry.lookup_room({:room, token}) do
        {:ok, pid} -> GenServer.stop(pid, :normal)
        {:error, :not_found} -> :ok
      end
    end)

    room
  end

  describe "join" do
    test "rejects a missing join token" do
      {:ok, socket} = connect(UserSocket, %{})

      assert {:error, %{reason: "invalid_token"}} =
               subscribe_and_join(socket, "group_call:missing", %{})
    end

    test "rejects a token signed for another room" do
      channel = unique_channel()
      nick = create_registered_nick(unique_nick("alice"))
      room = create_call(channel, nick)
      join_token = JoinToken.sign("other-token", channel, nick.id, nick.nickname)
      {:ok, socket} = connect(UserSocket, %{})

      assert {:error, %{reason: "invalid_token"}} =
               subscribe_and_join(socket, "group_call:#{room.token}", %{
                 "join_token" => join_token
               })
    end

    test "joins, accepts group_call_join and receives the server SDP offer" do
      channel = unique_channel()
      nick = create_registered_nick(unique_nick("alice"))
      room = create_call(channel, nick)
      join_token = JoinToken.sign(room.token, channel, nick.id, nick.nickname)

      {:ok, socket} = connect(UserSocket, %{})

      assert {:ok, init, socket} =
               subscribe_and_join(socket, "group_call:#{room.token}", %{
                 "join_token" => join_token
               })

      assert init.version == 1
      assert init.room.token == room.token

      ref = push(socket, "group_call_join", %{"client_info" => %{"browser" => "test"}})
      assert_reply ref, :ok, %{participant_id: participant_id}

      assert_push "group_call_joined", %{participant: %{id: ^participant_id}}, 1_000
      assert_push "group_call_offer", %{participant_id: ^participant_id, sdp: sdp}, 1_000
      assert sdp =~ "v=0"
    end

    test "rate limits repeated signaling messages" do
      Application.put_env(:retro_hex_chat, :group_call_signal_rate_limit, {1, 60_000})

      channel = unique_channel()
      nick = create_registered_nick(unique_nick("alice"))
      room = create_call(channel, nick)
      join_token = JoinToken.sign(room.token, channel, nick.id, nick.nickname)

      {:ok, socket} = connect(UserSocket, %{})

      assert {:ok, _init, socket} =
               subscribe_and_join(socket, "group_call:#{room.token}", %{
                 "join_token" => join_token
               })

      ref = push(socket, "group_call_join", %{"client_info" => %{"browser" => "test"}})
      assert_reply ref, :ok, %{participant_id: participant_id}

      assert_push "group_call_offer", %{participant_id: ^participant_id, sdp: _sdp}, 1_000

      ref = push(socket, "group_call_answer", %{"sdp" => "v=0\r\n"})
      assert_reply ref, :ok

      ref = push(socket, "group_call_answer", %{"sdp" => "v=0\r\n"})
      assert_reply ref, :error, %{code: "answer_failed", message: message}
      assert message =~ "Rate limited"
    end
  end
end
