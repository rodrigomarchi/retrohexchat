defmodule RetroHexChat.SessionControlLimitTest do
  @moduledoc """
  How many screens one nickname may hold, and which one gives way.

  Opening the chat used to end whatever chat the person already had. That was a
  rule about conflicts we no longer have — a channel membership is per nickname,
  and both windows share it — so what is left is a ceiling, because each session
  is a process with subscriptions, timers and state.

  The count comes from the database rather than from a process registry: a
  session whose process died and has not been cleaned up yet would otherwise be
  counted as gone while its row is still open, and the ceiling would drift.
  """
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Accounts.TrustedDevices
  alias RetroHexChat.Services.Queries
  alias RetroHexChat.SessionControl

  setup do
    nickname = "cap#{System.unique_integer([:positive])}" |> String.slice(0, 16)
    {:ok, _} = Queries.insert_registered_nick(nickname, "password123")
    %{nickname: nickname}
  end

  describe "enforce_limit/2" do
    test "a second and a third screen end nobody", %{nickname: nickname} do
      first = open_session(nickname)
      second = open_session(nickname)

      subscribe_session(first)
      subscribe_session(second)

      third = open_session(nickname)
      assert :ok = SessionControl.enforce_limit(nickname, third)

      refute_receive {:force_disconnect, _payload}
      assert open_refs(nickname) == [first, second, third]
    end

    test "the fourth screen ends the oldest", %{nickname: nickname} do
      oldest = open_session(nickname)
      middle = open_session(nickname)
      newest = open_session(nickname)

      subscribe_session(oldest)
      subscribe_session(middle)
      subscribe_session(newest)

      fourth = open_session(nickname)
      assert :ok = SessionControl.enforce_limit(nickname, fourth)

      assert_receive {:force_disconnect, payload}
      assert payload.session_ref == oldest
    end

    # The screen that gives way is not leaving the channels: the screens that
    # outlive it are still in them, and they share one membership. This is the
    # bug the whole change can introduce, so the payload says so explicitly
    # rather than leaving it to a predicate the handler has to guess at.
    test "the screen that gives way keeps the channels for the others", %{nickname: nickname} do
      oldest = open_session(nickname)
      open_session(nickname)
      open_session(nickname)

      subscribe_session(oldest)

      assert :ok = SessionControl.enforce_limit(nickname, open_session(nickname))

      assert_receive {:force_disconnect, payload}
      assert payload.skip_channel_cleanup
      assert payload.skip_whowas
    end

    test "the session being opened is never the one ended", %{nickname: nickname} do
      Enum.each(1..3, fn _ -> open_session(nickname) end)
      newcomer = open_session(nickname)

      subscribe_session(newcomer)

      assert :ok = SessionControl.enforce_limit(nickname, newcomer)

      refute_receive {:force_disconnect, _payload}
    end

    test "a screen that already closed does not count against the ceiling", %{nickname: nickname} do
      gone = open_session(nickname)
      TrustedDevices.record_session_stop(gone, "closed")

      kept = open_session(nickname)
      subscribe_session(kept)

      assert :ok = SessionControl.enforce_limit(nickname, open_session(nickname))

      refute_receive {:force_disconnect, _payload}
    end

    test "somebody else's screens are not counted", %{nickname: nickname} do
      stranger = "other#{System.unique_integer([:positive])}" |> String.slice(0, 16)
      {:ok, _} = Queries.insert_registered_nick(stranger, "password123")
      Enum.each(1..3, fn _ -> open_session(stranger) end)

      mine = open_session(nickname)
      subscribe_session(mine)

      assert :ok = SessionControl.enforce_limit(nickname, open_session(nickname))

      refute_receive {:force_disconnect, _payload}
    end
  end

  defp open_session(nickname) do
    {:ok, session} = TrustedDevices.record_session_start(nickname, nil, %{})
    session.session_ref
  end

  defp open_refs(nickname) do
    nickname
    |> TrustedDevices.open_sessions_for_nick()
    |> Enum.map(& &1.session_ref)
  end

  defp subscribe_session(session_ref) do
    :ok = Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "chat_device_session:#{session_ref}")
  end
end
