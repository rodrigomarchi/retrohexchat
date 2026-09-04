defmodule RetroHexChatWeb.IdleTimeTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.{Registry, Supervisor}

  setup do
    ensure_channel("#lobby")
    :ok
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end

  describe "idle time tracking" do
    test "idle time shown in whois output", %{conn: conn} do
      nick = "Idle1#{uid()}"
      target = "Idle2#{uid()}"

      {:ok, _target_view, _html} = live(chat_conn(conn, target), "/chat")
      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      view
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/whois #{target}"})

      # Drain the async dispatch (FIFO behind this call) before reading the view.
      _ = :sys.get_state(view.pid)
      html = render(view)

      assert html =~ "Idle for:"
    end

    test "idle time resets on sending a message", %{conn: conn} do
      nick = "Idle3#{uid()}"

      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Send a message to reset activity
      view
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "hello there"})

      # Drain the async dispatch (FIFO behind this call) before reading the view.
      _ = :sys.get_state(view.pid)

      # Self-whois to check idle time — should be very low
      view
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/whois #{nick}"})

      # Drain the async dispatch (FIFO behind this call) before reading the view.
      _ = :sys.get_state(view.pid)
      html = render(view)

      # After just sending a message, idle should be minimal
      assert html =~ "Idle for:"
      assert html =~ "less than a minute"
    end

    test "idle time resets on command dispatch", %{conn: conn} do
      nick = "Idle4#{uid()}"

      {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")

      # Run a command to reset activity
      view
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/help"})

      # Drain the async dispatch (FIFO behind this call) before reading the view.
      _ = :sys.get_state(view.pid)

      # Now self-whois — idle should be very low
      view
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/whois #{nick}"})

      # Drain the async dispatch (FIFO behind this call) before reading the view.
      _ = :sys.get_state(view.pid)
      html = render(view)

      assert html =~ "Idle for:"
      assert html =~ "less than a minute"
    end
  end
end
