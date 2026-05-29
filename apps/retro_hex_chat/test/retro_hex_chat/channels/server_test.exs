defmodule RetroHexChat.Channels.ServerTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Channels.{Registry, Server, Supervisor}

  defp unique_channel do
    "#test-#{System.unique_integer([:positive])}"
  end

  defp wait_until(fun, _interval, 0) do
    unless fun.(), do: flunk("Condition not met after retries")
  end

  defp wait_until(fun, interval, retries) do
    if fun.() do
      :ok
    else
      Process.sleep(interval)
      wait_until(fun, interval, retries - 1)
    end
  end

  defp start_channel(channel_name) do
    {:ok, pid} = Supervisor.start_child(channel_name)

    on_exit(fn ->
      if Process.alive?(pid), do: Supervisor.stop_child(pid)
    end)

    {:ok, pid}
  end

  describe "join/3" do
    test "first user becomes owner" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      assert {:ok, state} = Server.join(channel, "founder")
      assert state.member_count == 1
      assert "founder" in state.owners
      assert {"founder", :owner} in state.members
    end

    test "second user gets regular role" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "founder")
      {:ok, state} = Server.join(channel, "user2")

      assert state.member_count == 2
      assert {"founder", :owner} in state.members
      assert {"user2", :regular} in state.members
    end

    test "returns error when user is already in channel" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "user1")
      assert {:error, "Already in channel"} = Server.join(channel, "user1")
    end

    test "returns error when user is banned" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")
      :ok = Server.ban(channel, "op", "banned_user")

      assert {:error, "You are banned from " <> _} = Server.join(channel, "banned_user")
    end
  end

  describe "part/3" do
    test "removes user from channel" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "user1")
      {:ok, _} = Server.join(channel, "user2")

      assert :ok = Server.part(channel, "user2")

      {:ok, state} = Server.get_state(channel)
      assert state.member_count == 1
      refute {"user2", :regular} in state.members
    end

    test "returns error when user is not in channel" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "user1")
      assert {:error, "Not in channel"} = Server.part(channel, "ghost")
    end

    test "returns error when channel process is gone" do
      assert {:error, "Channel not found"} = Server.part(unique_channel(), "ghost")
    end

    test "stops channel process when last user leaves" do
      channel = unique_channel()
      {:ok, pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "lonely")

      # Subscribe to monitor the process
      ref = Process.monitor(pid)

      :ok = Server.part(channel, "lonely")

      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1000

      # Wait for Registry to clean up after process termination.
      # The Elixir Registry uses its own monitor, so cleanup is asynchronous.
      wait_until(fn -> Registry.lookup(channel) == {:error, :not_found} end, 100, 20)
      assert {:error, :not_found} = Registry.lookup(channel)
    end

    test "broadcasts user_left via PubSub" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "channel:#{channel}")

      {:ok, _} = Server.join(channel, "user1")
      {:ok, _} = Server.join(channel, "user2")

      # Consume join messages
      assert_receive {:user_joined, _}
      assert_receive {:user_joined, _}

      :ok = Server.part(channel, "user2", "goodbye")
      assert_receive {:user_left, %{nickname: "user2", reason: "goodbye"}}
    end
  end

  describe "get_state/1" do
    test "returns channel state as a map" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "user1")

      assert {:ok, state} = Server.get_state(channel)
      assert state.name == channel
      assert state.topic == ""
      assert state.member_count == 1
      assert is_list(state.members)
      assert is_list(state.operators)
      assert is_list(state.bans)
      assert %DateTime{} = state.created_at
    end

    test "returns error for nonexistent channel" do
      assert {:error, :not_found} =
               Server.get_state("#nonexistent-#{System.unique_integer([:positive])}")
    end
  end

  describe "kick/4" do
    test "operator can kick a user" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")
      {:ok, _} = Server.join(channel, "target")

      assert :ok = Server.kick(channel, "op", "target", "misbehaving")

      {:ok, state} = Server.get_state(channel)
      assert state.member_count == 1
      refute {"target", :regular} in state.members
    end

    test "non-operator cannot kick" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")
      {:ok, _} = Server.join(channel, "regular")
      {:ok, _} = Server.join(channel, "target")

      assert {:error, "Insufficient privileges"} =
               Server.kick(channel, "regular", "target")
    end

    test "cannot kick user not in channel" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")

      assert {:error, "User ghost is not in channel"} =
               Server.kick(channel, "op", "ghost")
    end

    test "broadcasts user_kicked via PubSub" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "channel:#{channel}")

      {:ok, _} = Server.join(channel, "op")
      {:ok, _} = Server.join(channel, "target")

      # Consume join messages
      assert_receive {:user_joined, _}
      assert_receive {:user_joined, _}

      :ok = Server.kick(channel, "op", "target", "bye")
      assert_receive {:user_kicked, %{operator: "op", target: "target", reason: "bye"}}
    end
  end

  describe "set_topic/3" do
    test "member can set topic" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "user1")

      assert :ok = Server.set_topic(channel, "user1", "Welcome!")

      {:ok, state} = Server.get_state(channel)
      assert state.topic == "Welcome!"
    end

    test "non-member cannot set topic" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "user1")

      assert {:error, "You are not in this channel"} =
               Server.set_topic(channel, "outsider", "Hacked!")
    end

    test "with topic_lock mode, only operator can set topic" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")
      {:ok, _} = Server.join(channel, "regular")

      # Set topic lock mode
      :ok = Server.set_mode(channel, "op", "+t")

      # Regular user cannot change topic
      assert {:error, "You must be a channel operator to change the topic"} =
               Server.set_topic(channel, "regular", "nope")

      # Operator can still change topic
      assert :ok = Server.set_topic(channel, "op", "Locked topic")

      {:ok, state} = Server.get_state(channel)
      assert state.topic == "Locked topic"
    end

    test "broadcasts topic_changed via PubSub" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "channel:#{channel}")

      {:ok, _} = Server.join(channel, "user1")
      assert_receive {:user_joined, _}

      :ok = Server.set_topic(channel, "user1", "New topic")
      assert_receive {:topic_changed, %{nickname: "user1", topic: "New topic"}}
    end
  end

  describe "set_mode/4" do
    test "operator can set modes" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")

      assert :ok = Server.set_mode(channel, "op", "+t")

      {:ok, state} = Server.get_state(channel)
      assert state.modes =~ "t"
    end

    test "non-operator cannot set modes" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")
      {:ok, _} = Server.join(channel, "regular")

      assert {:error, "Insufficient privileges to set channel modes"} =
               Server.set_mode(channel, "regular", "+t")
    end

    test "broadcasts mode_changed via PubSub" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "channel:#{channel}")

      {:ok, _} = Server.join(channel, "op")
      assert_receive {:user_joined, _}

      :ok = Server.set_mode(channel, "op", "+m")

      assert_receive {:mode_changed, %{nickname: "op", mode_string: "+m", params: []}}
    end

    test "+o grants operator role to user" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")
      {:ok, _} = Server.join(channel, "user2")

      :ok = Server.set_mode(channel, "op", "+o", ["user2"])

      {:ok, state} = Server.get_state(channel)
      assert "user2" in state.operators
    end

    test "-o removes operator role from user" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")
      {:ok, _} = Server.join(channel, "user2")

      :ok = Server.set_mode(channel, "op", "+o", ["user2"])
      :ok = Server.set_mode(channel, "op", "-o", ["user2"])

      {:ok, state} = Server.get_state(channel)
      refute "user2" in state.operators
    end

    test "+v grants voiced role to user" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")
      {:ok, _} = Server.join(channel, "user2")

      :ok = Server.set_mode(channel, "op", "+v", ["user2"])

      {:ok, state} = Server.get_state(channel)
      assert {"user2", :voiced} in state.members
    end

    test "-v removes voiced role from user" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")
      {:ok, _} = Server.join(channel, "user2")

      :ok = Server.set_mode(channel, "op", "+v", ["user2"])
      :ok = Server.set_mode(channel, "op", "-v", ["user2"])

      {:ok, state} = Server.get_state(channel)
      assert {"user2", :regular} in state.members
    end

    test "+o on non-member returns error" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")

      assert {:error, "User ghost is not in channel"} =
               Server.set_mode(channel, "op", "+o", ["ghost"])
    end
  end

  describe "ban/4" do
    test "operator can ban a user" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")

      assert :ok = Server.ban(channel, "op", "troll")

      {:ok, state} = Server.get_state(channel)
      assert "troll" in state.bans
    end

    test "non-operator cannot ban" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")
      {:ok, _} = Server.join(channel, "regular")

      assert {:error, "Insufficient privileges"} =
               Server.ban(channel, "regular", "someone")
    end

    test "banned user cannot join" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")
      :ok = Server.ban(channel, "op", "troll")

      assert {:error, "You are banned from " <> _} = Server.join(channel, "troll")
    end

    test "ban removes user from channel membership" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")
      {:ok, _} = Server.join(channel, "troll")

      :ok = Server.ban(channel, "op", "troll", "spamming")

      {:ok, state} = Server.get_state(channel)
      nicks = Enum.map(state.members, fn {nick, _} -> nick end)
      refute "troll" in nicks
      assert state.member_count == 1
    end

    test "banned user cannot send messages after ban" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")
      {:ok, _} = Server.join(channel, "troll")

      :ok = Server.ban(channel, "op", "troll", "spam")

      assert {:error, _} = Server.send_message(channel, "troll", "Should fail")
    end

    test "broadcasts user_banned via PubSub" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "channel:#{channel}")

      {:ok, _} = Server.join(channel, "op")
      assert_receive {:user_joined, _}

      :ok = Server.ban(channel, "op", "troll", "spam")
      assert_receive {:user_banned, %{operator: "op", target: "troll", reason: "spam"}}
    end

    test "operator cannot ban owner" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "owner")
      {:ok, _} = Server.join(channel, "regular")

      :ok = Server.set_mode(channel, "owner", "+o", ["regular"])

      assert {:error, msg} = Server.ban(channel, "regular", "owner")
      assert msg =~ "equal or higher rank"
    end

    test "cannot ban yourself" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")

      assert {:error, msg} = Server.ban(channel, "op", "op")
      assert msg =~ "cannot ban yourself"
    end
  end

  describe "ban/4 via mode +b" do
    test "+b bans a user" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")

      :ok = Server.set_mode(channel, "op", "+b", ["troll"])

      {:ok, state} = Server.get_state(channel)
      assert "troll" in state.bans
    end

    test "-b unbans a user" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")

      :ok = Server.ban(channel, "op", "troll")

      {:ok, state} = Server.get_state(channel)
      assert "troll" in state.bans

      :ok = Server.set_mode(channel, "op", "-b", ["troll"])

      {:ok, state} = Server.get_state(channel)
      refute "troll" in state.bans
    end
  end

  describe "rename_user/3" do
    test "updates member nick in state" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "old_nick")
      {:ok, _} = Server.join(channel, "other")

      assert :ok = Server.rename_user(channel, "old_nick", "new_nick")

      {:ok, state} = Server.get_state(channel)
      nicks = Enum.map(state.members, fn {nick, _} -> nick end)
      assert "new_nick" in nicks
      refute "old_nick" in nicks
    end

    test "send_message works with new nick after rename" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "channel:#{channel}")

      {:ok, _} = Server.join(channel, "rename_user")
      assert_receive {:user_joined, _}

      :ok = Server.rename_user(channel, "rename_user", "renamed_user")

      assert :ok = Server.send_message(channel, "renamed_user", "Hello after rename!")

      assert_receive %{
        event: "new_message",
        payload: %{author: "renamed_user", content: "Hello after rename!"}
      }
    end

    test "send_message with old nick fails after rename" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "pre_rename")
      :ok = Server.rename_user(channel, "pre_rename", "post_rename")

      assert {:error, _} = Server.send_message(channel, "pre_rename", "Should fail")
    end

    test "preserves role after rename" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op_user")

      # First user is owner
      {:ok, state} = Server.get_state(channel)
      assert "op_user" in state.owners

      :ok = Server.rename_user(channel, "op_user", "op_renamed")

      {:ok, state} = Server.get_state(channel)
      assert "op_renamed" in state.owners
      refute "op_user" in state.owners
    end
  end

  describe "send_message/4" do
    test "member can send a message" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "channel:#{channel}")

      {:ok, _} = Server.join(channel, "user1")
      assert_receive {:user_joined, _}

      assert :ok = Server.send_message(channel, "user1", "Hello!")

      assert_receive %{
        event: "new_message",
        payload: %{author: "user1", content: "Hello!", type: :message, channel: ^channel}
      }
    end

    test "non-member cannot send a message" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "user1")

      assert {:error, "You are not in this channel"} =
               Server.send_message(channel, "outsider", "Hello!")
    end

    test "regular user cannot send in moderated channel" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")
      {:ok, _} = Server.join(channel, "regular")
      :ok = Server.set_mode(channel, "op", "+m")

      assert {:error, msg} = Server.send_message(channel, "regular", "blocked")
      assert msg =~ "moderated"
    end
  end

  describe "ban/4 idempotent" do
    test "banning an already banned user is idempotent" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")
      :ok = Server.ban(channel, "op", "troll")
      assert :ok = Server.ban(channel, "op", "troll")

      {:ok, state} = Server.get_state(channel)
      assert "troll" in state.bans
    end
  end

  describe "set_topic/3 with topic_lock" do
    test "regular user cannot set topic when topic_lock is on" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")
      {:ok, _} = Server.join(channel, "regular")
      :ok = Server.set_mode(channel, "op", "+t")

      assert {:error, msg} = Server.set_topic(channel, "regular", "nope")
      assert msg =~ "operator"
    end
  end

  describe "rename_user/3 edge cases" do
    test "renaming a non-member is a graceful no-op" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)
      {:ok, _} = Server.join(channel, "user1")

      # Should not crash
      assert :ok = Server.rename_user(channel, "ghost", "new_ghost")

      {:ok, state} = Server.get_state(channel)
      nicks = Enum.map(state.members, fn {nick, _} -> nick end)
      refute "new_ghost" in nicks
      assert "user1" in nicks
    end
  end

  describe "voiced user in moderated channel" do
    test "voiced user can send message in +m channel" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "channel:#{channel}")

      {:ok, _} = Server.join(channel, "op")
      {:ok, _} = Server.join(channel, "voiced_user")
      assert_receive {:user_joined, _}
      assert_receive {:user_joined, _}

      :ok = Server.set_mode(channel, "op", "+m")
      :ok = Server.set_mode(channel, "op", "+v", ["voiced_user"])

      assert :ok = Server.send_message(channel, "voiced_user", "I can speak!")

      assert_receive %{
        event: "new_message",
        payload: %{author: "voiced_user", content: "I can speak!"}
      }
    end
  end

  describe "mode enforcement via Server" do
    test "join blocked when channel is full (+l)" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")
      :ok = Server.set_mode(channel, "op", "+l", ["2"])
      {:ok, _} = Server.join(channel, "user2")

      assert {:error, "Channel is full (+l)"} = Server.join(channel, "user3")
    end

    test "join allowed after removing user limit (-l)" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")
      :ok = Server.set_mode(channel, "op", "+l", ["2"])
      {:ok, _} = Server.join(channel, "user2")

      assert {:error, "Channel is full (+l)"} = Server.join(channel, "user3")

      :ok = Server.set_mode(channel, "op", "-l")
      assert {:ok, _} = Server.join(channel, "user3")
    end

    test "join blocked on invite-only channel (+i)" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")
      :ok = Server.set_mode(channel, "op", "+i")

      assert {:error, "Channel is invite-only (+i)"} = Server.join(channel, "user2")
    end

    test "join allowed after removing invite-only (-i)" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")
      :ok = Server.set_mode(channel, "op", "+i")

      assert {:error, "Channel is invite-only (+i)"} = Server.join(channel, "user2")

      :ok = Server.set_mode(channel, "op", "-i")
      assert {:ok, _} = Server.join(channel, "user2")
    end

    test "join blocked without channel key (+k)" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")
      :ok = Server.set_mode(channel, "op", "+k", ["secret"])

      assert {:error, "Bad channel key (+k)"} = Server.join(channel, "user2")
      assert {:error, "Bad channel key (+k)"} = Server.join(channel, "user2", "wrong")
    end

    test "join allowed with correct channel key (+k)" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")
      :ok = Server.set_mode(channel, "op", "+k", ["secret"])

      assert {:ok, _} = Server.join(channel, "user2", "secret")
    end

    test "removing channel key (-k) allows keyless join" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")
      :ok = Server.set_mode(channel, "op", "+k", ["secret"])

      assert {:error, "Bad channel key (+k)"} = Server.join(channel, "user2")

      :ok = Server.set_mode(channel, "op", "-k")
      assert {:ok, _} = Server.join(channel, "user2")
    end

    test "send_message with type :action broadcasts correctly" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "channel:#{channel}")

      {:ok, _} = Server.join(channel, "actor")
      assert_receive {:user_joined, _}

      assert :ok = Server.send_message(channel, "actor", "dances", :action)

      assert_receive %{
        event: "new_message",
        payload: %{author: "actor", content: "dances", type: :action, channel: ^channel}
      }
    end
  end

  describe "kick last member of unregistered channel" do
    test "kick that empties unregistered channel causes shutdown" do
      channel = unique_channel()
      {:ok, pid} = start_channel(channel)

      # Owner joins, then a regular user joins
      {:ok, _} = Server.join(channel, "owner")
      {:ok, _} = Server.join(channel, "target")

      ref = Process.monitor(pid)

      # Owner kicks target, then parts — channel empties and shuts down
      assert :ok = Server.kick(channel, "owner", "target", "bye")
      assert :ok = Server.part(channel, "owner", nil)

      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1000
      wait_until(fn -> Registry.lookup(channel) == {:error, :not_found} end, 100, 20)
    end
  end

  describe "get_state modes string" do
    test "get_state shows +k in modes after setting channel key" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")
      :ok = Server.set_mode(channel, "op", "+k", ["secret"])

      {:ok, state} = Server.get_state(channel)
      assert state.modes =~ "k"
    end

    test "get_state shows +l in modes after setting user limit" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")
      :ok = Server.set_mode(channel, "op", "+l", ["25"])

      {:ok, state} = Server.get_state(channel)
      assert state.modes =~ "l"
    end
  end

  describe "state initialization (T008)" do
    test "new channel has nil topic metadata and empty exception sets" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")
      {:ok, state} = Server.get_state(channel)

      assert state.topic_set_by == nil
      assert state.topic_set_at == nil
      assert state.ban_exceptions == []
      assert state.invite_exceptions == []
    end
  end

  describe "set_topic metadata (T009)" do
    test "stores topic_set_by and topic_set_at" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")
      :ok = Server.set_topic(channel, "op", "Hello world")

      {:ok, state} = Server.get_state(channel)
      assert state.topic == "Hello world"
      assert state.topic_set_by == "op"
      assert %DateTime{} = state.topic_set_at
    end

    test "broadcasts set_at in topic_changed event" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "channel:#{channel}")

      {:ok, _} = Server.join(channel, "op")
      assert_receive {:user_joined, _}

      :ok = Server.set_topic(channel, "op", "New topic")

      assert_receive {:topic_changed,
                      %{
                        channel: ^channel,
                        nickname: "op",
                        topic: "New topic",
                        set_at: %DateTime{}
                      }}
    end
  end

  describe "get_state extended fields (T010)" do
    test "includes modes_detail map" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")
      :ok = Server.set_mode(channel, "op", "+m")
      :ok = Server.set_mode(channel, "op", "+k", ["secret"])

      {:ok, state} = Server.get_state(channel)

      assert %{
               moderated: true,
               invite_only: false,
               topic_lock: false,
               key: "secret",
               limit: nil
             } = state.modes_detail
    end

    test "includes topic_set_by and topic_set_at" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")
      :ok = Server.set_topic(channel, "op", "My topic")

      {:ok, state} = Server.get_state(channel)
      assert state.topic_set_by == "op"
      assert %DateTime{} = state.topic_set_at
    end

    test "includes ban_exceptions and invite_exceptions" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")
      {:ok, state} = Server.get_state(channel)

      assert is_list(state.ban_exceptions)
      assert is_list(state.invite_exceptions)
    end
  end

  describe "ban exceptions override bans (T036)" do
    test "banned user with ban exception can join" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")
      :ok = Server.ban(channel, "op", "excepted_user")
      :ok = Server.add_ban_exception(channel, "op", "excepted_user")

      assert {:ok, _} = Server.join(channel, "excepted_user")
    end

    test "banned user without exception still rejected" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")
      :ok = Server.ban(channel, "op", "troll")

      assert {:error, "You are banned from " <> _} = Server.join(channel, "troll")
    end
  end

  describe "invite exceptions bypass invite-only (T041)" do
    test "invite-only rejects user not in invite_exceptions" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")
      :ok = Server.set_mode(channel, "op", "+i", [])

      assert {:error, "Channel is invite-only" <> _} = Server.join(channel, "outsider")
    end

    test "invite-only allows user in invite_exceptions" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")
      :ok = Server.set_mode(channel, "op", "+i", [])
      :ok = Server.add_invite_exception(channel, "op", "vip_user")

      assert {:ok, _} = Server.join(channel, "vip_user")
    end
  end

  # ── US1: Extended User Hierarchy ────────────────────────────

  describe "first joiner becomes owner (T010)" do
    test "first joiner of unregistered channel gets :owner role" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, state} = Server.join(channel, "founder")
      assert {"founder", :owner} in state.members
    end

    test "second joiner gets :regular role" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "founder")
      {:ok, state} = Server.join(channel, "user")
      assert {"user", :regular} in state.members
    end
  end

  describe "set_mode +q/+h owner and half-operator (T010)" do
    test "owner can set +q on another user" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "owner")
      {:ok, _} = Server.join(channel, "alice")

      assert :ok = Server.set_mode(channel, "owner", "+q", ["alice"])
      {:ok, state} = Server.get_state(channel)
      assert "alice" in state.owners
    end

    test "operator cannot set +q" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "owner")
      {:ok, _} = Server.join(channel, "op")
      {:ok, _} = Server.join(channel, "alice")

      :ok = Server.set_mode(channel, "owner", "+o", ["op"])

      assert {:error, _} = Server.set_mode(channel, "op", "+q", ["alice"])
    end

    test "operator can set +h on a user" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "owner")
      {:ok, _} = Server.join(channel, "op")
      {:ok, _} = Server.join(channel, "alice")

      :ok = Server.set_mode(channel, "owner", "+o", ["op"])
      assert :ok = Server.set_mode(channel, "op", "+h", ["alice"])
      {:ok, state} = Server.get_state(channel)
      assert "alice" in state.half_operators
    end
  end

  describe "kick rank enforcement (T010)" do
    test "half-operator can kick regular user" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "owner")
      {:ok, _} = Server.join(channel, "halfop")
      {:ok, _} = Server.join(channel, "user")

      :ok = Server.set_mode(channel, "owner", "+h", ["halfop"])

      assert :ok = Server.kick(channel, "halfop", "user", "bye")
    end

    test "half-operator cannot kick operator" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "owner")
      {:ok, _} = Server.join(channel, "halfop")
      {:ok, _} = Server.join(channel, "op")

      :ok = Server.set_mode(channel, "owner", "+h", ["halfop"])
      :ok = Server.set_mode(channel, "owner", "+o", ["op"])

      assert {:error, _} = Server.kick(channel, "halfop", "op", "nope")
    end

    test "operator cannot kick owner" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "owner")
      {:ok, _} = Server.join(channel, "op")

      :ok = Server.set_mode(channel, "owner", "+o", ["op"])

      assert {:error, _} = Server.kick(channel, "op", "owner", "nope")
    end

    test "owner can kick operator" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "owner")
      {:ok, _} = Server.join(channel, "op")

      :ok = Server.set_mode(channel, "owner", "+o", ["op"])

      assert :ok = Server.kick(channel, "owner", "op", "bye")
    end
  end

  describe "half-operator mode permission enforcement (T010)" do
    test "half-operator can set +v" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "owner")
      {:ok, _} = Server.join(channel, "halfop")
      {:ok, _} = Server.join(channel, "user")

      :ok = Server.set_mode(channel, "owner", "+h", ["halfop"])

      assert :ok = Server.set_mode(channel, "halfop", "+v", ["user"])
    end

    test "half-operator cannot set +m" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "owner")
      {:ok, _} = Server.join(channel, "halfop")

      :ok = Server.set_mode(channel, "owner", "+h", ["halfop"])

      assert {:error, _} = Server.set_mode(channel, "halfop", "+m", [])
    end
  end

  # ── US2: +n No External Messages ────────────────────────────

  describe "server +n mode (T019)" do
    test "non-member message blocked with +n" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "owner")
      :ok = Server.set_mode(channel, "owner", "+n", [])

      # Non-member tries to send (not joined)
      assert {:error, _} = Server.send_message(channel, "outsider", "hello")
    end

    test "member message succeeds with +n" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "owner")
      :ok = Server.set_mode(channel, "owner", "+n", [])

      assert :ok = Server.send_message(channel, "owner", "hello members")
    end
  end

  # ── US3: Knock ──────────────────────────────────────────────

  describe "server knock/3 (T025)" do
    test "knock on invite-only channel succeeds" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")
      :ok = Server.set_mode(channel, "op", "+i", [])

      assert :ok = Server.knock(channel, "visitor", "Let me in!")
    end

    test "knock on non-invite-only channel fails" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")

      assert {:error, "Channel is not invite-only"} = Server.knock(channel, "visitor", nil)
    end

    test "knock when +K is set fails" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")
      :ok = Server.set_mode(channel, "op", "+iK", [])

      assert {:error, "Knocking is disabled" <> _} = Server.knock(channel, "visitor", nil)
    end

    test "knock when user is banned fails" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")
      :ok = Server.set_mode(channel, "op", "+i", [])
      :ok = Server.ban(channel, "op", "baduser", nil)

      assert {:error, "You are banned" <> _} = Server.knock(channel, "baduser", nil)
    end

    test "knock when already a member fails" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "op")
      {:ok, _} = Server.join(channel, "member")
      :ok = Server.set_mode(channel, "op", "+i", [])

      assert {:error, "You are already in that channel"} =
               Server.knock(channel, "member", nil)
    end
  end

  # ── US4: Strip Colors and Registered Only ───────────────────

  describe "server +c strip colors (T031)" do
    test "message with color codes arrives stripped" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "owner")
      :ok = Server.set_mode(channel, "owner", "+c", [])

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "channel:#{channel}")

      :ok = Server.send_message(channel, "owner", "\x03Hello\x03 \x02bold\x02")

      assert_receive %{event: "new_message", payload: payload}
      refute payload.content =~ "\x03"
      refute payload.content =~ "\x02"
    end

    test "message without +c is not stripped" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "owner")

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "channel:#{channel}")

      :ok = Server.send_message(channel, "owner", "\x02bold\x02")

      assert_receive %{event: "new_message", payload: payload}
      assert payload.content =~ "\x02"
    end
  end

  describe "server +R registered only (T032)" do
    test "unregistered user join blocked with +R" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "owner")
      :ok = Server.set_mode(channel, "owner", "+R", [])

      assert {:error, "You must be registered" <> _} =
               Server.join(channel, "unregistered", nil, identified: false)
    end

    test "registered user join succeeds with +R" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "owner")
      :ok = Server.set_mode(channel, "owner", "+R", [])

      assert {:ok, _} = Server.join(channel, "registered", nil, identified: true)
    end
  end

  # ── US5: Join Throttle ──────────────────────────────────────

  describe "server +j join throttle (T036)" do
    test "joins within limit succeed" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "owner")
      :ok = Server.set_mode(channel, "owner", "+j", ["3:60"])

      assert {:ok, _} = Server.join(channel, "user1")
      assert {:ok, _} = Server.join(channel, "user2")
    end

    test "join exceeding limit blocked" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "owner")
      :ok = Server.set_mode(channel, "owner", "+j", ["2:60"])

      # owner join counts + 2 more = 3 total timestamps, limit is 2
      {:ok, _} = Server.join(channel, "user1")

      assert {:error, "Channel join throttle active" <> _} =
               Server.join(channel, "user2")
    end

    test "invalid +j params ignored gracefully" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "owner")

      # Invalid params are silently ignored (no throttle set)
      assert :ok = Server.set_mode(channel, "owner", "+j", ["invalid"])
      {:ok, state} = Server.get_state(channel)
      refute state.modes_detail.join_throttle
    end
  end

  # ── US6: Welcome Messages ────────────────────────────────────────

  describe "set_welcome/3" do
    test "sets welcome message" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "owner")

      assert :ok = Server.set_welcome(channel, "Welcome to our channel!", "owner")

      {:ok, result} = Server.get_welcome(channel)
      assert result.message == "Welcome to our channel!"
      assert result.set_by == "owner"
    end

    test "broadcasts {:welcome_changed, ...}" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "channel:#{channel}")

      {:ok, _} = Server.join(channel, "owner")
      assert_receive {:user_joined, _}

      :ok = Server.set_welcome(channel, "New welcome", "owner")

      assert_receive {:welcome_changed,
                      %{channel: ^channel, message: "New welcome", set_by: "owner"}}
    end

    test "overwrites existing welcome" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "owner")

      :ok = Server.set_welcome(channel, "First welcome", "owner")
      {:ok, result1} = Server.get_welcome(channel)
      assert result1.message == "First welcome"

      :ok = Server.set_welcome(channel, "Second welcome", "op")
      {:ok, result2} = Server.get_welcome(channel)
      assert result2.message == "Second welcome"
      assert result2.set_by == "op"
    end
  end

  describe "get_welcome/1" do
    test "returns nil when no welcome set" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "owner")

      assert {:ok, nil} = Server.get_welcome(channel)
    end

    test "returns welcome after set" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "owner")

      :ok = Server.set_welcome(channel, "Test welcome", "owner")

      {:ok, result} = Server.get_welcome(channel)
      assert result.message == "Test welcome"
      assert result.set_by == "owner"
    end
  end

  describe "clear_welcome/2" do
    test "clears the welcome" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "owner")

      :ok = Server.set_welcome(channel, "Temporary welcome", "owner")
      {:ok, result} = Server.get_welcome(channel)
      assert result.message == "Temporary welcome"

      assert :ok = Server.clear_welcome(channel, "owner")

      assert {:ok, nil} = Server.get_welcome(channel)
    end

    test "broadcasts {:welcome_changed, ...} with nil message" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "channel:#{channel}")

      {:ok, _} = Server.join(channel, "owner")
      assert_receive {:user_joined, _}

      :ok = Server.set_welcome(channel, "Welcome", "owner")
      assert_receive {:welcome_changed, _}

      :ok = Server.clear_welcome(channel, "owner")

      assert_receive {:welcome_changed, %{channel: ^channel, message: nil}}
    end

    test "clearing when no welcome is set is idempotent" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "owner")

      assert {:ok, nil} = Server.get_welcome(channel)

      assert :ok = Server.clear_welcome(channel, "owner")

      assert {:ok, nil} = Server.get_welcome(channel)
    end
  end
end
