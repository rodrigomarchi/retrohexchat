defmodule RetroHexChatWeb.Live.OpenSurfacesTest do
  @moduledoc """
  A surface drawing the way in, against what this person actually has open.

  The registry test proves the set is right. What is proved here is the half
  only a live screen can show: that the set arrives without asking, and that
  the screen redraws when it changes — a screen that read it once would be
  right only at the moment it drew.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Surfaces

  defp nick, do: "surf#{System.unique_integer([:positive])}" |> String.slice(0, 16)

  # The set arriving is a message, so the test waits for the message and never
  # for the clock — but a message is only half of it, and the half that is not
  # enough on its own. A broadcast sends to each subscriber in turn, and this
  # process can be reached before the screen is: `assert_receive` returning
  # proves the registry announced, and proves nothing at all about whether the
  # screen has been sent to yet. Waiting on the announcement and then reading
  # the screen is a race that loses roughly once in a full suite, which is how
  # it was found.
  #
  # `settle/1` is the other half. It is a `GenServer.call` to the registry, so
  # it is answered only after the handler that announced has finished — and
  # that handler did the sending. Once it returns, the screen's copy is in the
  # screen's mailbox, ahead of anything this process sends next.
  defp watch(nickname) do
    :ok = Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Surfaces.topic(nickname))
  end

  defp settle(nickname), do: Surfaces.count(nickname)

  # Waits for the announcement that says what the test is about, not for a
  # number of announcements: registering a surface publishes twice — once for
  # the process, once for its address — and counting them is a way to be wrong
  # every time one of those halves moves.
  defp await_paths(predicate) do
    assert_receive {:surfaces_changed, listing}, 1_000
    paths = MapSet.new(listing, & &1.path)

    if predicate.(paths), do: paths, else: await_paths(predicate)
  end

  defp await_open(nickname, path) do
    await_paths(&MapSet.member?(&1, path))
    settle(nickname)
  end

  defp await_gone(nickname, path) do
    await_paths(&(not MapSet.member?(&1, path)))
    settle(nickname)
  end

  # A surface is a process, so a stand-in for one is a process. It reports back
  # when the registry has it, so the test never races the monitor.
  defp fake_surface(nickname, path) do
    test = self()

    pid =
      spawn(fn ->
        :ok = Surfaces.open(nickname, __MODULE__)
        :ok = Surfaces.address(nickname, path)
        send(test, {:registered, self()})

        receive do
          :close -> :ok
        end
      end)

    assert_receive {:registered, ^pid}, 1_000
    on_exit(fn -> if Process.alive?(pid), do: send(pid, :close) end)
    pid
  end

  defp close(pid) do
    ref = Process.monitor(pid)
    send(pid, :close)
    assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 1_000
    :ok
  end

  describe "the way back to the chat" do
    test "navigates when this person has no chat open", %{conn: conn} do
      nickname = nick()

      {:ok, _view, html} = conn |> chat_conn(nickname) |> live(~p"/play/hex_pong")

      assert html =~ ~s(data-testid="play-back-to-chat")
      refute html =~ ~s(data-surface-path="/chat")
    end

    test "tries the chat tab that already exists", %{conn: conn} do
      nickname = nick()
      fake_surface(nickname, "/chat")

      {:ok, _view, html} = conn |> chat_conn(nickname) |> live(~p"/play/hex_pong")

      assert html =~ ~s(data-surface-path="/chat")
      assert html =~ ~s(phx-hook="SurfaceTabLinkHook")
    end

    # The whole reason this is a subscription and not a lookup: a tab that
    # opens after this screen drew has to change what this screen says.
    test "changes its mind when a chat tab opens and when it closes", %{conn: conn} do
      nickname = nick()
      watch(nickname)

      {:ok, view, html} = conn |> chat_conn(nickname) |> live(~p"/play/hex_pong")
      refute html =~ ~s(data-surface-path="/chat")

      chat = fake_surface(nickname, "/chat")
      await_open(nickname, "/chat")
      assert render(view) =~ ~s(data-surface-path="/chat")

      close(chat)
      await_gone(nickname, "/chat")
      refute render(view) =~ ~s(data-surface-path="/chat")
    end

    test "somebody else's chat is not this person's", %{conn: conn} do
      mine = nick()
      fake_surface(nick(), "/chat")

      {:ok, _view, html} = conn |> chat_conn(mine) |> live(~p"/play/hex_pong")

      refute html =~ ~s(data-surface-path="/chat")
    end
  end

  # The chat reads the same set, through a hook chain with a dozen other
  # handlers in it. If any of them swallowed the message the chat would be the
  # one screen that never learns — and it is the screen that draws "open in a
  # tab" for a call.
  describe "the chat" do
    # `live/2` returns after `handle_params`, and registering is a call into the
    # registry from there — so by the time the screen exists the registry has
    # already answered. Nothing to wait for.
    test "registers its own address, so a surface can go back to it", %{conn: conn} do
      nickname = nick()

      {:ok, _view, _html} = conn |> chat_conn(nickname) |> live(~p"/chat")

      assert Surfaces.open?(nickname, "/chat")
    end

    test "learns about a surface opening without being asked", %{conn: conn} do
      nickname = nick()
      watch(nickname)

      {:ok, view, _html} = conn |> chat_conn(nickname) |> live(~p"/chat")
      refute MapSet.member?(open_paths(view), "/call/abc")

      surface = fake_surface(nickname, "/call/abc")
      await_open(nickname, "/call/abc")
      assert MapSet.member?(open_paths(view), "/call/abc")

      close(surface)
      await_gone(nickname, "/call/abc")
      refute MapSet.member?(open_paths(view), "/call/abc")
    end
  end

  describe "the surface's own address" do
    # The registry learns where a surface is from `handle_params`, which is the
    # only place a LiveView is told — and the only place it is told it moved.
    test "a surface registers the address it was opened at", %{conn: conn} do
      nickname = nick()

      {:ok, _view, _html} = conn |> chat_conn(nickname) |> live(~p"/play/hex_pong")

      assert Surfaces.open?(nickname, "/play/hex_pong")
      refute Surfaces.open?(nickname, "/play")
    end

    test "two surfaces of this person are two addresses", %{conn: conn} do
      nickname = nick()
      fake_surface(nickname, "/chat")

      {:ok, _view, _html} = conn |> chat_conn(nickname) |> live(~p"/play/hex_pong")

      assert Surfaces.open?(nickname, "/play/hex_pong")
      assert Surfaces.open?(nickname, "/chat")
    end
  end

  # Synchronous state rather than a rendered fragment: what is in doubt is
  # whether the message survived the chat's hook chain, and the assign is where
  # that stops being a question.
  defp open_paths(view), do: :sys.get_state(view.pid).socket.assigns.open_surface_paths
end
