defmodule RetroHexChatWeb.ChatLive.SyntaxTooltipTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.{Registry, Supervisor}

  setup do
    ensure_channel("#lobby")
    :ok
  end

  # ── syntax_tooltip_query event ────────────────────────────

  describe "syntax_tooltip_query" do
    test "returns tooltip data for known command", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "TooltipUser1"), "/chat")

      # Push syntax_tooltip_query event for "mode" command
      render_hook(view, "syntax_tooltip_query", %{
        "command" => "mode",
        "args" => ""
      })

      # The view should have syntax_tooltip assign set
      html = render(view)
      assert html =~ "syntax-tooltip"
      assert html =~ "mode"
    end

    test "does not show tooltip for unknown command", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "TooltipUser2"), "/chat")

      render_hook(view, "syntax_tooltip_query", %{
        "command" => "nonexistent",
        "args" => ""
      })

      html = render(view)
      refute html =~ "syntax-tooltip"
    end

    test "computes current param index from args", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "TooltipUser3"), "/chat")

      render_hook(view, "syntax_tooltip_query", %{
        "command" => "kick",
        "args" => "troll"
      })

      html = render(view)
      assert html =~ "syntax-tooltip"
    end
  end

  # ── syntax_tooltip_dismiss event ──────────────────────────

  describe "syntax_tooltip_dismiss" do
    test "hides the tooltip", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "DismissUser"), "/chat")

      # Show tooltip first
      render_hook(view, "syntax_tooltip_query", %{
        "command" => "mode",
        "args" => ""
      })

      html = render(view)
      assert html =~ "syntax-tooltip"

      # Now dismiss
      render_hook(view, "syntax_tooltip_dismiss", %{})

      html = render(view)
      refute html =~ "syntax-tooltip"
    end
  end

  # ── helpers ────────────────────────────────────────────────

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end
end
