defmodule RetroHexChatWeb.ChatTakeoverTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.Registry
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Channels.Supervisor
  alias RetroHexChat.Presence.Tracker
  alias RetroHexChatWeb.PerfBudgets

  setup do
    case Registry.lookup("#lobby") do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child("#lobby")
    end

    :ok
  end

  # Connecting a nickname that is already online has to wait for the previous
  # session to leave its channels first, or the old session's departure lands
  # after the new one has joined and takes it back out. The wait for that
  # acknowledgement is the single most expensive thing in the connected mount —
  # so it must happen only when a previous session is actually there to answer.

  describe "when a previous session is still live" do
    test "the previous session has left the channel by the time the new one is in", %{conn: conn} do
      nick = "Take#{uid()}"

      {:ok, first, _html} = conn |> chat_conn(nick) |> live("/chat")
      assert render(first) =~ nick
      assert nick in channel_members("#lobby")

      {:ok, second, _html} = conn |> chat_conn(nick) |> live("/chat")

      # This is what the wait buys. Without it the old session's departure lands
      # after the new session's join and takes the nickname back out of the
      # channel — so a single membership, checked with no sleep in between, is
      # the whole assertion.
      assert channel_members("#lobby") |> Enum.count(&(&1 == nick)) == 1
      assert Tracker.online?("presence:global", nick)
      assert :sys.get_state(second.pid).socket.assigns.session.nickname == nick
    end
  end

  describe "when nothing is left to answer" do
    test "the mount does not wait out the acknowledgement timeout", %{conn: conn} do
      nick = "Ghost#{uid()}"

      # A presence entry whose owner will never answer a force_disconnect: what a
      # tab that vanished leaves behind until the tracker catches up. It is
      # tracked but never subscribed to the nickname's inbox, which is what
      # separates "a session is here" from "something was here once".
      ghost = spawn(fn -> Process.sleep(:timer.seconds(60)) end)
      on_exit(fn -> Process.exit(ghost, :kill) end)
      Tracker.track(ghost, "presence:global", nick, %{})
      wait_until(fn -> Tracker.online?("presence:global", nick) end)

      assert Tracker.online?("presence:global", nick),
             "precondition: the tracker has to believe the nickname is online"

      {micros, {:ok, _view, _html}} =
        :timer.tc(fn -> conn |> chat_conn(nick) |> live("/chat") end)

      assert div(micros, 1000) < PerfBudgets.connected_mount_ms(),
             "mount blocked for #{div(micros, 1000)}ms waiting for an acknowledgement " <>
               "that could never arrive"
    end
  end

  defp channel_members(channel) do
    {:ok, state} = Server.get_state(channel)

    Enum.map(state.members, fn {member, _role} -> member end)
  end

  defp wait_until(fun, retries \\ 50) do
    cond do
      fun.() -> :ok
      retries <= 0 -> flunk("condition was not met before timeout")
      true -> Process.sleep(10) && wait_until(fun, retries - 1)
    end
  end
end
