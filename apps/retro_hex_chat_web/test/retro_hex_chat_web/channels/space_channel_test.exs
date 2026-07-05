defmodule RetroHexChatWeb.SpaceChannelTest do
  use RetroHexChatWeb.ChannelCase, async: false

  alias RetroHexChat.Services.NickServ
  alias RetroHexChat.VirtualSpace.{JoinToken, Queries, Registry, SessionServer}
  alias RetroHexChatWeb.UserSocket

  @moduletag :integration

  defp uid, do: System.unique_integer([:positive])

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
    test "a valid join_token gets a space_init reply with the snapshot" do
      creator = register_and_identify("chc#{uid()}")
      session = insert_space(creator)

      assert {:ok, space_init, _socket} = join_space(creator, session)

      assert space_init.participant.key == "registered:#{creator.id}"
      assert space_init.snapshot.map_id == "tavern_cafe_v1"
      assert Enum.any?(space_init.snapshot.participants, &(&1.key == space_init.participant.key))
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

  describe "leave" do
    test "closing the channel marks the participant offline in the SessionServer" do
      creator = register_and_identify("chl#{uid()}")
      session = insert_space(creator)

      {:ok, init, socket} = join_space(creator, session)
      key = init.participant.key

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
