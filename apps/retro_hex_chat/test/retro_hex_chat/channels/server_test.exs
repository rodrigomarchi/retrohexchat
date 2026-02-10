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
    test "first user becomes operator" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      assert {:ok, state} = Server.join(channel, "founder")
      assert state.member_count == 1
      assert "founder" in state.operators
      assert {"founder", :operator} in state.members
    end

    test "second user gets regular role" do
      channel = unique_channel()
      {:ok, _pid} = start_channel(channel)

      {:ok, _} = Server.join(channel, "founder")
      {:ok, state} = Server.join(channel, "user2")

      assert state.member_count == 2
      assert {"founder", :operator} in state.members
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

      assert {:error, "You must be a channel operator to kick users"} =
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

      assert {:error, "You must be a channel operator to change modes"} =
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

      assert {:error, "You must be a channel operator to ban users"} =
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

      # First user is operator
      {:ok, state} = Server.get_state(channel)
      assert "op_user" in state.operators

      :ok = Server.rename_user(channel, "op_user", "op_renamed")

      {:ok, state} = Server.get_state(channel)
      assert "op_renamed" in state.operators
      refute "op_user" in state.operators
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

      # First user is operator
      {:ok, _} = Server.join(channel, "op")

      ref = Process.monitor(pid)

      # Op self-kicks: removes only member → channel shuts down
      assert :ok = Server.kick(channel, "op", "op", "self-kick")

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
end
