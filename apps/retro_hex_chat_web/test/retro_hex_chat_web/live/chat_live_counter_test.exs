defmodule RetroHexChatWeb.ChatLiveCounterTest do
  use RetroHexChatWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias RetroHexChat.Channels.{Registry, Supervisor}

  @moduletag :liveview

  setup %{conn: conn} do
    channel = "#cntr-#{System.unique_integer([:positive])}"
    ensure_channel(channel)
    {:ok, conn: conn, channel: channel}
  end

  describe "US4: Character Counter" do
    test "counter element exists with data-testid", %{conn: conn, channel: channel} do
      nick = "Cnt#{uid()}"
      {:ok, view, _} = live(conn, "/chat?nickname=#{nick}")
      join_channel(view, channel)
      html = render(view)

      assert html =~ ~s(data-testid="char-counter")
      assert html =~ "char-counter"
    end

    test "input has maxlength attribute", %{conn: conn, channel: channel} do
      nick = "CnM#{uid()}"
      {:ok, view, _} = live(conn, "/chat?nickname=#{nick}")
      join_channel(view, channel)
      html = render(view)

      assert html =~ ~s(maxlength="1000")
    end

    test "CharCounterHook is present on input area", %{conn: conn, channel: channel} do
      nick = "CnH#{uid()}"
      {:ok, view, _} = live(conn, "/chat?nickname=#{nick}")
      join_channel(view, channel)
      html = render(view)

      assert html =~ "CharCounterHook"
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
