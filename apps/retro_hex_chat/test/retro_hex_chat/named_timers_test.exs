defmodule RetroHexChat.NamedTimersTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.NamedTimers

  defp state, do: %{timers: %{}, session: :whatever}

  describe "schedule/3" do
    test "wakes the process with the name it was given" do
      NamedTimers.schedule(state(), :lobby_expiry, 5)

      assert_receive {:timeout, :lobby_expiry}, 200
    end

    test "keeps the handle under its name so it can be reached again" do
      scheduled = NamedTimers.schedule(state(), :lobby_expiry, 1_000)

      assert is_reference(scheduled.timers.lobby_expiry)
    end

    test "leaves the rest of the state alone" do
      scheduled = NamedTimers.schedule(state(), :lobby_expiry, 1_000)

      assert scheduled.session == :whatever
    end

    test "a name can be anything a message can carry" do
      NamedTimers.schedule(state(), {:rejoin_grace, :guest}, 5)

      assert_receive {:timeout, {:rejoin_grace, :guest}}, 200
    end

    test "rescheduling a pending name wakes the process once, not twice" do
      state()
      |> NamedTimers.schedule(:lobby_expiry, 30)
      |> NamedTimers.schedule(:lobby_expiry, 30)

      assert_receive {:timeout, :lobby_expiry}, 200
      refute_receive {:timeout, :lobby_expiry}, 100
    end

    test "rescheduling replaces the handle rather than keeping both" do
      first = NamedTimers.schedule(state(), :lobby_expiry, 1_000)
      second = NamedTimers.schedule(first, :lobby_expiry, 1_000)

      assert map_size(second.timers) == 1
      assert second.timers.lobby_expiry != first.timers.lobby_expiry
    end
  end

  describe "cancel/2" do
    test "a cancelled deadline never arrives" do
      state()
      |> NamedTimers.schedule(:lobby_expiry, 30)
      |> NamedTimers.cancel(:lobby_expiry)

      refute_receive {:timeout, :lobby_expiry}, 150
    end

    test "the name is gone once nothing is pending under it" do
      cancelled =
        state()
        |> NamedTimers.schedule(:lobby_expiry, 1_000)
        |> NamedTimers.cancel(:lobby_expiry)

      assert cancelled.timers == %{}
    end

    test "cancelling a name that was never set is not an error" do
      assert NamedTimers.cancel(state(), :never_scheduled) == state()
    end

    test "the other deadlines keep running" do
      remaining =
        state()
        |> NamedTimers.schedule(:lobby_warning, 30)
        |> NamedTimers.schedule(:lobby_expiry, 1_000)
        |> NamedTimers.cancel(:lobby_expiry)

      assert Map.keys(remaining.timers) == [:lobby_warning]
      assert_receive {:timeout, :lobby_warning}, 200
    end
  end

  describe "cancel_all/1" do
    test "no deadline survives the session that held it" do
      state()
      |> NamedTimers.schedule(:lobby_warning, 30)
      |> NamedTimers.schedule(:lobby_expiry, 30)
      |> NamedTimers.schedule({:rejoin_grace, :host}, 30)
      |> NamedTimers.cancel_all()

      refute_receive {:timeout, _name}, 150
    end

    test "leaves nothing pending behind" do
      emptied =
        state()
        |> NamedTimers.schedule(:lobby_warning, 1_000)
        |> NamedTimers.schedule(:lobby_expiry, 1_000)
        |> NamedTimers.cancel_all()

      assert emptied.timers == %{}
    end

    test "a session that scheduled nothing can still end" do
      assert NamedTimers.cancel_all(state()) == state()
    end
  end
end
