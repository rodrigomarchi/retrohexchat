defmodule RetroHexChatWeb.SpaceChannelTest do
  use RetroHexChatWeb.ChannelCase, async: false

  alias RetroHexChat.Services.NickServ
  alias RetroHexChat.VirtualSpace.{JoinToken, Queries, Registry, SessionServer}
  alias RetroHexChatWeb.UserSocket

  @moduletag :integration

  setup do
    Application.put_env(:retro_hex_chat, :virtual_space_step_ms, 0)
    on_exit(fn -> Application.delete_env(:retro_hex_chat, :virtual_space_step_ms) end)
    :ok
  end

  defp uid, do: System.unique_integer([:positive])

  # Drives the socket's participant to a target tile with valid input steps.
  defp walk_channel_to(socket, session, key, {tx, ty}) do
    {:ok, state} = SessionServer.get_state(session.token)
    %{x: x, y: y} = state.participants[key]

    step =
      cond do
        x < tx -> %{"dx" => 1, "dy" => 0}
        x > tx -> %{"dx" => -1, "dy" => 0}
        y < ty -> %{"dx" => 0, "dy" => 1}
        y > ty -> %{"dx" => 0, "dy" => -1}
        true -> nil
      end

    if step do
      push(socket, "space_input", Map.put(step, "seq", uid()))
      assert_push "space_delta", %{}
      walk_channel_to(socket, session, key, {tx, ty})
    else
      :ok
    end
  end

  defp register_and_identify(nick) do
    NickServ.register(nick, "pass123")
    {:ok, _} = NickServ.identify(nick, "pass123")
    RetroHexChat.Repo.get_by!(RetroHexChat.Services.RegisteredNick, nickname: nick)
  end

  defp insert_space(creator, attrs \\ %{}) do
    base = %{
      token: "chspace-#{uid()}",
      channel_name: "#space-ch-#{uid()}",
      creator_id: creator.id,
      creator_nick: creator.nickname,
      title: "HQ",
      expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
    }

    {:ok, session} = Queries.insert_session(Map.merge(base, attrs))

    on_exit(fn ->
      case Registry.lookup(session.token) do
        {:ok, pid} -> GenServer.stop(pid, :normal)
        _ -> :ok
      end
    end)

    session
  end

  defp join_space(user, session) do
    {:ok, socket} = connect(UserSocket, %{})
    join_token = JoinToken.sign(session.token, user.id, user.nickname)
    subscribe_and_join(socket, "space:#{session.token}", %{"join_token" => join_token})
  end

  describe "join" do
    test "a valid join_token gets a space_init reply carrying the full map and snapshot" do
      creator = register_and_identify("chc#{uid()}")
      session = insert_space(creator)

      assert {:ok, space_init, _socket} = join_space(creator, session)

      self_key = "registered:#{creator.id}"
      assert space_init.version == 1
      assert space_init.token == session.token
      assert space_init.self_key == self_key

      # The full canonical map is serialized inline (no client-side map copy).
      assert space_init.map.id == "tavern_cafe_v1"
      assert is_list(space_init.map.collision)
      assert is_list(space_init.map.seats)
      assert space_init.map.tile_size == 16

      # Snapshot follows the wire protocol: server_time + participants keyed by key.
      assert is_integer(space_init.snapshot.server_time)
      assert Map.has_key?(space_init.snapshot.participants, self_key)
      assert space_init.snapshot.participants[self_key].nickname == creator.nickname
    end

    test "a tampered join_token is refused" do
      creator = register_and_identify("cht#{uid()}")
      session = insert_space(creator)

      {:ok, socket} = connect(UserSocket, %{})
      forged = JoinToken.sign(session.token, creator.id, creator.nickname) <> "x"

      assert {:error, %{reason: "invalid_token"}} =
               subscribe_and_join(socket, "space:#{session.token}", %{"join_token" => forged})
    end

    test "a join_token for another space is refused" do
      creator = register_and_identify("cho#{uid()}")
      session_a = insert_space(creator)
      session_b = insert_space(creator)

      {:ok, socket} = connect(UserSocket, %{})
      wrong = JoinToken.sign(session_b.token, creator.id, creator.nickname)

      assert {:error, %{reason: "invalid_token"}} =
               subscribe_and_join(socket, "space:#{session_a.token}", %{"join_token" => wrong})
    end

    test "a join beyond capacity is refused with a clear error" do
      creator = register_and_identify("chf#{uid()}")
      other = register_and_identify("chg#{uid()}")
      session = insert_space(creator, %{max_participants: 1})

      assert {:ok, _init, _socket} = join_space(creator, session)

      assert {:error, %{reason: "space_full"}} = join_space(other, session)
    end
  end

  describe "presence broadcasts" do
    test "a second join reaches the first participant's socket" do
      creator = register_and_identify("chb#{uid()}")
      other = register_and_identify("chd#{uid()}")
      session = insert_space(creator)

      assert {:ok, _init, _socket} = join_space(creator, session)
      assert {:ok, _init2, _socket2} = join_space(other, session)

      assert_push "space_participant_joined", %{nickname: nickname}
      assert nickname == other.nickname
    end
  end

  describe "movement" do
    test "a valid space_input push moves the participant and broadcasts a delta" do
      creator = register_and_identify("chm#{uid()}")
      session = insert_space(creator)

      {:ok, init, socket} = join_space(creator, session)
      self_key = init.self_key
      %{x: x0, y: y0} = init.snapshot.participants[self_key]

      push(socket, "space_input", %{"seq" => 1, "dx" => 1, "dy" => 0})

      assert_push "space_delta", %{seq_ack: seq_ack, updates: updates}
      assert seq_ack[self_key] == 1
      assert updates[self_key].x == x0 + 1
      assert updates[self_key].dir == "right"

      {:ok, state} = SessionServer.get_state(session.token)
      assert {state.participants[self_key].x, state.participants[self_key].y} == {x0 + 1, y0}
    end
  end

  describe "chat" do
    test "a space_chat_bubble push broadcasts space_message with normalized text" do
      creator = register_and_identify("chc#{uid()}")
      session = insert_space(creator)

      {:ok, _init, socket} = join_space(creator, session)

      push(socket, "space_chat_bubble", %{"text" => "  hi   there  "})

      assert_push "space_message", %{text: "hi there", nickname: nickname}
      assert nickname == creator.nickname
    end
  end

  describe "interactions" do
    test "a space_interact use on a board pushes a space_modal to the requester" do
      creator = register_and_identify("chi#{uid()}")
      session = insert_space(creator)

      {:ok, init, socket} = join_space(creator, session)

      # Walk adjacent to the menu_board at (12,10): spawn is near it.
      walk_channel_to(socket, session, init.self_key, {12, 11})

      push(socket, "space_interact", %{"seq" => 1, "kind" => "use", "target_id" => "menu_board"})

      assert_push "space_modal", %{asset: "board_menu_v1", title: "Tavern menu"}
    end
  end

  describe "leave" do
    test "closing the channel marks the participant offline in the SessionServer" do
      creator = register_and_identify("chl#{uid()}")
      session = insert_space(creator)

      {:ok, init, socket} = join_space(creator, session)
      key = init.self_key

      Process.unlink(socket.channel_pid)
      :ok = close(socket)

      # close/1 is synchronous for the channel, but the leave cast to the
      # SessionServer is async; get_state serializes behind it.
      wait_until(fn ->
        case SessionServer.get_state(session.token) do
          {:ok, state} -> state.participants[key].online? == false
          _ -> false
        end
      end)

      {:ok, state} = SessionServer.get_state(session.token)
      participant = state.participants[key]
      refute participant.online?
      assert participant.x
    end
  end

  defp wait_until(fun, retries \\ 50) do
    cond do
      fun.() ->
        :ok

      retries == 0 ->
        flunk("condition never became true")

      true ->
        Process.sleep(10)
        wait_until(fun, retries - 1)
    end
  end
end
