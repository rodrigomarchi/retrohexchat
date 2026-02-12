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
      nick = "Idle1#{System.unique_integer([:positive])}"
      target = "Idle2#{System.unique_integer([:positive])}"

      {:ok, _target_view, _html} = live(conn, "/chat?nickname=#{target}")
      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/whois #{target}"})

      Process.sleep(50)
      html = render(view)

      assert html =~ "Idle for:"
    end

    test "idle time resets on sending a message", %{conn: conn} do
      nick = "Idle3#{System.unique_integer([:positive])}"

      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Send a message to reset activity
      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "hello there"})

      Process.sleep(50)

      # Self-whois to check idle time — should be very low
      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/whois #{nick}"})

      Process.sleep(50)
      html = render(view)

      # After just sending a message, idle should be minimal
      assert html =~ "Idle for:"
      assert html =~ "less than a minute"
    end

    test "idle time resets on command dispatch", %{conn: conn} do
      nick = "Idle4#{System.unique_integer([:positive])}"

      {:ok, view, _html} = live(conn, "/chat?nickname=#{nick}")

      # Run a command to reset activity
      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/help"})

      Process.sleep(50)

      # Now self-whois — idle should be very low
      view
      |> element("form.chat-input-form")
      |> render_submit(%{"input" => "/whois #{nick}"})

      Process.sleep(50)
      html = render(view)

      assert html =~ "Idle for:"
      assert html =~ "less than a minute"
    end
  end
end
