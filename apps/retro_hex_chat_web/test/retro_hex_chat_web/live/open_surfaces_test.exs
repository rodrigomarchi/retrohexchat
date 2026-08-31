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

      {:ok, view, html} = conn |> chat_conn(nickname) |> live(~p"/play/hex_pong")
      refute html =~ ~s(data-surface-path="/chat")

      chat = fake_surface(nickname, "/chat")
      assert render_eventually(view, ~s(data-surface-path="/chat"))

      close(chat)
      assert render_until_gone(view, ~s(data-surface-path="/chat"))
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
    test "registers its own address, so a surface can go back to it", %{conn: conn} do
      nickname = nick()

      {:ok, _view, _html} = conn |> chat_conn(nickname) |> live(~p"/chat")

      assert_eventually(fn -> Surfaces.open?(nickname, "/chat") end)
    end

    test "learns about a surface opening without being asked", %{conn: conn} do
      nickname = nick()

      {:ok, view, _html} = conn |> chat_conn(nickname) |> live(~p"/chat")
      refute MapSet.member?(open_paths(view), "/call/abc")

      surface = fake_surface(nickname, "/call/abc")
      assert_eventually(fn -> MapSet.member?(open_paths(view), "/call/abc") end)

      close(surface)
      assert_eventually(fn -> not MapSet.member?(open_paths(view), "/call/abc") end)
    end
  end

  describe "the surface's own address" do
    # The registry learns where a surface is from `handle_params`, which is the
    # only place a LiveView is told — and the only place it is told it moved.
    test "a surface registers the address it was opened at", %{conn: conn} do
      nickname = nick()

      {:ok, _view, _html} = conn |> chat_conn(nickname) |> live(~p"/play/hex_pong")

      assert_eventually(fn -> Surfaces.open?(nickname, "/play/hex_pong") end)
      refute Surfaces.open?(nickname, "/play")
    end

    test "two surfaces of this person are two addresses", %{conn: conn} do
      nickname = nick()
      fake_surface(nickname, "/chat")

      {:ok, _view, _html} = conn |> chat_conn(nickname) |> live(~p"/play/hex_pong")

      assert_eventually(fn -> Surfaces.open?(nickname, "/play/hex_pong") end)
      assert Surfaces.open?(nickname, "/chat")
    end
  end

  # The set arrives asynchronously, so the assertion waits for the render
  # rather than for a message: what is being proved is what the screen says.
  #
  # The negative needs its own helper and does not get one by writing `refute`
  # in front of this one — that would pass the instant the fragment is still
  # there, which is exactly what it is still there for. It has to wait for the
  # fragment to *go*.
  defp render_eventually(view, fragment, retries \\ 50)
  defp render_eventually(_view, _fragment, 0), do: false

  defp render_eventually(view, fragment, retries) do
    if render(view) =~ fragment do
      true
    else
      Process.sleep(20)
      render_eventually(view, fragment, retries - 1)
    end
  end

  defp render_until_gone(view, fragment, retries \\ 50)
  defp render_until_gone(_view, _fragment, 0), do: false

  defp render_until_gone(view, fragment, retries) do
    if render(view) =~ fragment do
      Process.sleep(20)
      render_until_gone(view, fragment, retries - 1)
    else
      true
    end
  end

  # Synchronous state rather than a rendered fragment: what is in doubt is
  # whether the message survived the chat's hook chain, and the assign is where
  # that stops being a question.
  defp open_paths(view), do: :sys.get_state(view.pid).socket.assigns.open_surface_paths

  defp assert_eventually(fun, retries \\ 50) do
    cond do
      fun.() -> :ok
      retries <= 0 -> flunk("condition was not met before timeout")
      true -> Process.sleep(20) && assert_eventually(fun, retries - 1)
    end
  end
end
