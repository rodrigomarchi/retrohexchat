defmodule RetroHexChat.Games.ActivityTest do
  use ExUnit.Case, async: false

  alias Phoenix.Tracker.Shard
  alias RetroHexChat.Games.Activity
  alias RetroHexChat.Nickname
  alias RetroHexChat.Presence.Tracker
  alias RetroHexChat.Topics

  @moduletag :unit

  # Each player is a process of its own, as each page playing a match is.
  defp player(fun) do
    test = self()

    pid =
      spawn(fn ->
        fun.()
        send(test, :tracked)

        receive do
          :stop -> :ok
        end
      end)

    assert_receive :tracked
    pid
  end

  defp nick, do: "act#{System.unique_integer([:positive])}"

  test "a player is listed while their match runs, under its game" do
    ana = nick()
    pid = player(fn -> :ok = Activity.playing(ana, "hex_tennis_quick") end)

    assert %{game_id: "hex_tennis_quick", nickname: ^ana} =
             Activity.now()[Nickname.key(ana)]

    assert ana in Activity.playing_in("hex_tennis")
    refute ana in Activity.playing_in("hex_pong")

    send(pid, :stop)
  end

  test "starting another game moves the player, and stopping takes them off" do
    beto = nick()

    pid =
      player(fn ->
        :ok = Activity.playing(beto, "hex_pong")
        :ok = Activity.playing(beto, "hex_raid")
        :ok = Activity.stopped(beto)
      end)

    refute Map.has_key?(Activity.now(), Nickname.key(beto))
    send(pid, :stop)
  end

  test "a page that goes away takes its player off the list by itself" do
    caio = nick()
    pid = player(fn -> :ok = Activity.playing(caio, "hex_pong") end)
    ref = Process.monitor(pid)

    send(pid, :stop)
    assert_receive {:DOWN, ^ref, :process, ^pid, _reason}

    # Presence cleans up after the process from the tracker shard's own
    # mailbox; a synchronous call to that shard is what orders this read after
    # the cleanup.
    shard =
      Shard.name_for_topic(Tracker, Topics.games_playing(), 1)

    _ = :sys.get_state(shard)

    refute Map.has_key?(Activity.now(), Nickname.key(caio))
  end
end
