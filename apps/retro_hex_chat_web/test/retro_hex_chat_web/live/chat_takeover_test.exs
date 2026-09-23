defmodule RetroHexChatWeb.ChatTakeoverTest do
  @moduledoc """
  What opening the chat does to the chat somebody already has.

  It used to end it, and the two had to be sequenced: the old session's
  departure from its channels had to land *before* the new session joined, or
  the departure arrived afterwards and took the nickname back out. That
  sequencing cost a blocking wait in the connected mount, and it is gone —
  because the departure is gone. A second screen joins a membership the first
  one is holding, and neither leaves on the other's account.

  What survives from the old mechanism is the budget: the connected mount must
  not block on anything, and a stale presence entry with nobody behind it used
  to make it wait out a full acknowledgement timeout.
  """
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

  describe "when a previous session is still live" do
    test "both sessions hold the one membership between them", %{conn: conn} do
      nick = "Take#{uid()}"

      {:ok, first, _html} = conn |> chat_conn(nick) |> live("/chat")
      assert render(first) =~ nick
      assert nick in channel_members("#lobby")

      {:ok, second, _html} = conn |> chat_conn(nick) |> live("/chat")

      # One member, two screens: the membership is keyed by nickname, so the
      # second session adopts it rather than joining a second time. A count of
      # two here would be a nicklist showing the same person twice.
      assert channel_members("#lobby") |> Enum.count(&(&1 == nick)) == 1
      assert Tracker.online?("presence:global", nick)
      assert Process.alive?(first.pid)
      assert :sys.get_state(second.pid).socket.assigns.session.nickname == nick
    end
  end

  describe "the connected mount blocks on nothing" do
    test "a presence entry with nobody behind it does not slow it down", %{conn: conn} do
      nick = "Ghost#{uid()}"

      # What a tab that vanished leaves behind until the tracker catches up:
      # tracked, but never subscribed to the nickname's inbox. It used to be
      # enough to make the mount wait out an acknowledgement that could never
      # arrive.
      ghost = spawn(fn -> Process.sleep(:timer.seconds(60)) end)
      on_exit(fn -> Process.exit(ghost, :kill) end)
      Tracker.track(ghost, "presence:global", nick, %{})
      wait_until(fn -> Tracker.online?("presence:global", nick) end)

      assert Tracker.online?("presence:global", nick),
             "precondition: the tracker has to believe the nickname is online"

      {micros, {:ok, _view, _html}} =
        :timer.tc(fn -> conn |> chat_conn(nick) |> live("/chat") end)

      assert div(micros, 1000) < PerfBudgets.connected_mount_ms(),
             "mount blocked for #{div(micros, 1000)}ms"
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
