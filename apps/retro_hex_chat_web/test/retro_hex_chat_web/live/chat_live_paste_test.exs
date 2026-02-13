defmodule RetroHexChatWeb.ChatLivePasteTest do
  use RetroHexChatWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias RetroHexChat.Channels.{Registry, Supervisor}

  @moduletag :liveview

  setup %{conn: conn} do
    channel = "#pste-#{System.unique_integer([:positive])}"
    ensure_channel(channel)
    {:ok, conn: conn, channel: channel}
  end

  describe "US5: Multi-Line Paste Dialog" do
    test "paste_lines event shows confirmation dialog", %{conn: conn, channel: channel} do
      nick = "Pst#{uid()}"
      {:ok, view, _} = live(conn, "/chat?nickname=#{nick}")
      join_channel(view, channel)

      lines = ["line1", "line2", "line3"]
      render_click(view, "paste_lines", %{"lines" => lines})
      html = render(view)

      assert html =~ "Paste Confirmation"
      assert html =~ "3 lines"
    end

    test "paste_cancel clears dialog", %{conn: conn, channel: channel} do
      nick = "PsC#{uid()}"
      {:ok, view, _} = live(conn, "/chat?nickname=#{nick}")
      join_channel(view, channel)

      render_click(view, "paste_lines", %{"lines" => ["a", "b"]})
      render_click(view, "paste_cancel", %{})
      html = render(view)

      refute html =~ "Paste Confirmation"
    end

    test "paste_send dispatches messages", %{conn: conn, channel: channel} do
      nick = "PsS#{uid()}"
      {:ok, view, _} = live(conn, "/chat?nickname=#{nick}")
      join_channel(view, channel)

      render_click(view, "paste_lines", %{"lines" => ["hello", "world"]})
      render_click(view, "paste_send", %{})

      # Dialog should close
      html = render(view)
      refute html =~ "Paste Confirmation"
    end

    test ">50 lines shows flood warning", %{conn: conn, channel: channel} do
      nick = "PsW#{uid()}"
      {:ok, view, _} = live(conn, "/chat?nickname=#{nick}")
      join_channel(view, channel)

      lines = Enum.map(1..55, &"line #{&1}")
      render_click(view, "paste_lines", %{"lines" => lines})
      html = render(view)

      assert html =~ "flood"
    end

    test ">100 lines disables send", %{conn: conn, channel: channel} do
      nick = "PsD#{uid()}"
      {:ok, view, _} = live(conn, "/chat?nickname=#{nick}")
      join_channel(view, channel)

      lines = Enum.map(1..105, &"line #{&1}")
      render_click(view, "paste_lines", %{"lines" => lines})
      html = render(view)

      assert html =~ "disabled"
    end

    test "empty lines are filtered out", %{conn: conn, channel: channel} do
      nick = "PsE#{uid()}"
      {:ok, view, _} = live(conn, "/chat?nickname=#{nick}")
      join_channel(view, channel)

      lines = ["hello", "", "  ", "world", ""]
      render_click(view, "paste_lines", %{"lines" => lines})
      html = render(view)

      # Only 2 non-empty lines
      assert html =~ "2 lines"
    end
  end

  defp join_channel(view, channel) do
    view |> render_submit("send_input", %{"input" => "/join #{channel}"})
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end

  defp uid, do: System.unique_integer([:positive])
end
