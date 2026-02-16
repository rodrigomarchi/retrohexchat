defmodule RetroHexChatWeb.PasteE2ETest do
  @moduledoc """
  E2E tests for multi-line paste dialog (US5).
  Run with: mix test --only e2e
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :e2e

  alias RetroHexChat.Channels.{Registry, Supervisor}

  setup do
    channel = "#paste2e-#{System.unique_integer([:positive])}"
    ensure_channel(channel)
    {:ok, channel: channel}
  end

  describe "Multi-Line Paste E2E" do
    test "paste_lines event shows paste confirmation dialog", %{conn: conn, channel: channel} do
      nick = "PE#{uid()}"
      {:ok, view, _} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      render_hook(view, "paste_lines", %{"lines" => ["line one", "line two", "line three"]})
      html = render(view)

      assert html =~ "Paste Confirmation"
      assert html =~ "3 lines"
    end

    test "paste_cancel clears the dialog", %{conn: conn, channel: channel} do
      nick = "PE#{uid()}"
      {:ok, view, _} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      render_hook(view, "paste_lines", %{"lines" => ["a", "b"]})
      assert render(view) =~ "Paste Confirmation"

      render_click(view, "paste_cancel")
      html = render(view)

      refute html =~ "Paste Confirmation"
    end

    test "paste_send dispatches messages and closes dialog", %{conn: conn, channel: channel} do
      nick = "PE#{uid()}"
      {:ok, view, _} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      render_hook(view, "paste_lines", %{"lines" => ["hello world", "second line"]})
      assert render(view) =~ "Paste Confirmation"

      render_click(view, "paste_send")
      html = render(view)

      refute html =~ "Paste Confirmation"
    end

    test "flood warning shown for more than 50 lines", %{conn: conn, channel: channel} do
      nick = "PE#{uid()}"
      {:ok, view, _} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      lines = Enum.map(1..55, &"line #{&1}")
      render_hook(view, "paste_lines", %{"lines" => lines})
      html = render(view)

      assert html =~ "Paste Confirmation"
      assert html =~ "flood"
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
