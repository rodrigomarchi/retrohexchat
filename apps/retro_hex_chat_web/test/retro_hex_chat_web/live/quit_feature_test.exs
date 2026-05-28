defmodule RetroHexChatWeb.QuitFeatureTest do
  @moduledoc """
  E2E tests for quit message broadcast (US6).
  Run with: mix test --only liveview_feature
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Channels.{Registry, Supervisor}

  setup do
    channel = "#qte2e-#{uid()}"
    ensure_channel(channel)
    {:ok, channel: channel}
  end

  describe "Quit Message Broadcast E2E" do
    test "/quit with message broadcasts to shared channel", %{conn: conn, channel: channel} do
      nick1 = "QE1#{uid()}"
      nick2 = "QE2#{uid()}"

      {:ok, view1, _} = live(chat_conn(conn, nick1), "/chat")
      join_channel(view1, channel)

      {:ok, view2, _} = live(chat_conn(conn, nick2), "/chat")
      join_channel(view2, channel)

      :timer.sleep(50)
      _ = render(view2)

      view1 |> render_submit("send_input", %{"input" => "/quit See you later!"})

      :timer.sleep(50)
      _ = render(view2)
      html = render(view2)

      assert html =~ "See you later!"
    end

    test "/quit without message uses default 'Leaving'", %{conn: conn, channel: channel} do
      nick1 = "QE3#{uid()}"
      nick2 = "QE4#{uid()}"

      {:ok, view1, _} = live(chat_conn(conn, nick1), "/chat")
      join_channel(view1, channel)

      {:ok, view2, _} = live(chat_conn(conn, nick2), "/chat")
      join_channel(view2, channel)

      :timer.sleep(50)
      _ = render(view2)

      view1 |> render_submit("send_input", %{"input" => "/quit"})

      :timer.sleep(50)
      _ = render(view2)
      html = render(view2)

      assert html =~ "Leaving"
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
