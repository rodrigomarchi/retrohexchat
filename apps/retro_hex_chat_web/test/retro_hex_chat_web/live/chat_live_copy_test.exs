defmodule RetroHexChatWeb.ChatLiveCopyTest do
  use RetroHexChatWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias RetroHexChat.Channels.{Registry, Supervisor}

  @moduletag :liveview

  setup %{conn: conn} do
    channel = "#copy-#{uid()}"
    ensure_channel(channel)
    {:ok, conn: conn, channel: channel}
  end

  describe "US3: Right-Click Copy" do
    test "chat-messages container has ScrollHook (includes copy support)", %{
      conn: conn,
      channel: channel
    } do
      nick = "Cpy#{uid()}"
      {:ok, view, _} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)
      html = render(view)

      # ScrollHook now includes copy functionality
      assert html =~ ~s(phx-hook="ScrollHook")
      assert html =~ "chat-messages"
    end

    test "chat messages area allows text selection (no inline user-select override)", %{
      conn: conn,
      channel: channel
    } do
      nick = "CpS#{uid()}"
      {:ok, view, _} = live(chat_conn(conn, nick), "/chat")
      join_channel(view, channel)
      html = render(view)

      # The chat-messages div itself should not suppress selection
      # Extract just the chat-messages element
      assert html =~ ~s(id="chat-messages")
      # Ensure the element does not have an inline user-select: none style
      refute Regex.match?(~r/id="chat-messages"[^>]*user-select:\s*none/, html)
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
