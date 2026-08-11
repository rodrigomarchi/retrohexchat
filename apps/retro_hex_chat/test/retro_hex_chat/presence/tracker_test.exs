defmodule RetroHexChat.Presence.TrackerTest do
  use ExUnit.Case, async: false

  @moduletag :unit

  alias RetroHexChat.Presence.Tracker

  test "module defines expected functions" do
    assert function_exported?(Tracker, :track_user, 3)
    assert function_exported?(Tracker, :untrack_user, 2)
    assert function_exported?(Tracker, :list_users, 1)
    assert function_exported?(Tracker, :update_away, 4)
  end

  describe "track_user + list_users" do
    test "tracking a user makes them appear in list_users" do
      topic = "test:tracker_#{System.unique_integer([:positive])}"
      assert {:ok, _ref} = Tracker.track_user(topic, "Alice")
      Process.sleep(50)

      users = Tracker.list_users(topic)
      nicks = Enum.map(users, & &1.nickname)
      assert "Alice" in nicks
    end

    test "list_users on empty topic returns empty list" do
      topic = "test:empty_#{System.unique_integer([:positive])}"
      assert Tracker.list_users(topic) == []
    end
  end

  describe "find_user/2" do
    setup do
      suffix = System.unique_integer([:positive])
      channel = "#find#{suffix}"
      {:ok, _ref} = Tracker.track_user("channel:#{channel}", "Grace", %{away: true})
      Process.sleep(50)

      %{channel: channel}
    end

    test "finds somebody in a channel the asker shares", %{channel: channel} do
      assert %{nickname: "Grace", away: true} = Tracker.find_user("Grace", [channel])
    end

    # However the nickname was typed: a hover card and `/whois` both take it
    # from whatever the reader clicked or wrote.
    test "however the nickname was typed", %{channel: channel} do
      assert %{nickname: "Grace"} = Tracker.find_user("GRACE", [channel])
    end

    test "keeps looking past channels they are not in", %{channel: channel} do
      empty = "#empty#{System.unique_integer([:positive])}"

      assert %{nickname: "Grace"} = Tracker.find_user("Grace", [empty, channel])
    end

    test "nobody, from no channel at all" do
      assert Tracker.find_user("Grace", []) == nil
    end

    test "somebody who is nowhere the asker can see", %{channel: channel} do
      assert Tracker.find_user("Ada", [channel]) == nil
    end
  end

  describe "untrack_user" do
    test "untracking removes user from list_users" do
      topic = "test:untrack_#{System.unique_integer([:positive])}"
      {:ok, _ref} = Tracker.track_user(topic, "Bob")
      Process.sleep(50)

      assert "Bob" in Enum.map(Tracker.list_users(topic), & &1.nickname)

      :ok = Tracker.untrack_user(topic, "Bob")
      Process.sleep(50)

      refute "Bob" in Enum.map(Tracker.list_users(topic), & &1.nickname)
    end
  end

  describe "update_away" do
    test "updates away status in user metadata" do
      topic = "test:away_#{System.unique_integer([:positive])}"
      {:ok, _ref} = Tracker.track_user(topic, "Charlie")
      Process.sleep(50)

      {:ok, _ref} = Tracker.update_away(topic, "Charlie", true, "Gone fishing")
      Process.sleep(50)

      [user] = Tracker.list_users(topic)
      assert user.away == true
      assert user.away_message == "Gone fishing"
    end

    test "updates away without message (3-arg form)" do
      topic = "test:away3_#{System.unique_integer([:positive])}"
      {:ok, _ref} = Tracker.track_user(topic, "Dave")
      Process.sleep(50)

      {:ok, _ref} = Tracker.update_away(topic, "Dave", true)
      Process.sleep(50)

      [user] = Tracker.list_users(topic)
      assert user.away == true
      assert user.away_message == nil
    end
  end
end
