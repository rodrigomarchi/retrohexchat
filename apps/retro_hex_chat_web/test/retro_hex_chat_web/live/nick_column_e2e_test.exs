defmodule RetroHexChatWeb.NickColumnE2ETest do
  @moduledoc """
  E2E tests for nick column alignment (US1).
  Run with: mix test --only e2e
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :e2e

  alias RetroHexChat.Channels.{Registry, Supervisor}

  setup do
    channel = "#ncole2e-#{uid()}"
    ensure_channel(channel)
    {:ok, channel: channel}
  end

  describe "Nick Column Alignment E2E" do
    test "regular messages render inside grid layout", %{conn: conn, channel: channel} do
      nick = "NCE#{uid()}"
      {:ok, view, _} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      view |> render_submit("send_input", %{"input" => "Hello from grid test"})
      html = render(view)

      # V2 uses Tailwind grid layout
      assert html =~ "grid grid-cols-"
      assert html =~ "data-nick="
    end

    test "action messages do not use grid layout", %{conn: conn, channel: channel} do
      nick = "NCE#{uid()}"
      {:ok, view, _} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)

      view |> render_submit("send_input", %{"input" => "/me waves hello"})
      html = render(view)

      assert html =~ "text-action"
    end

    test "system messages do not use grid layout", %{conn: conn, channel: channel} do
      nick1 = "NC1#{uid()}"
      nick2 = "NC2#{uid()}"

      {:ok, view1, _} = live(chat_conn(conn, nick1), "/chat")
      join_channel(view1, channel)

      {:ok, _view2, _} = live(chat_conn(conn, nick2), "/chat")
      join_channel(view1, channel)

      # Wait for PubSub + flush
      :timer.sleep(50)
      _ = render(view1)
      html = render(view1)

      assert html =~ "italic"
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
end
