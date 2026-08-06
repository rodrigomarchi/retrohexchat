defmodule RetroHexChatWeb.IgnoreListTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.Supervisor, as: ChannelSupervisor

  setup do
    case RetroHexChat.Channels.Registry.lookup("#lobby") do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> ChannelSupervisor.start_child("#lobby")
    end

    :ok
  end

  defp connect_user(conn, nick) do
    {:ok, view, _html} = live(chat_conn(conn, nick), "/chat")
    view
  end

  # ── Phase 3: US1 — Dialog Shell ──────────────────────────

  describe "control tab" do
    test "shows empty state when no ignored users", %{conn: conn} do
      view = connect_user(conn, "ControlTab")
      view |> render_click("open_ignore_list_dialog")

      html = render(view)
      assert html =~ "No ignored users. Click Add to ignore a nickname."
    end
  end
end
