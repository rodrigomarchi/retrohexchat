defmodule RetroHexChatWeb.QuitFeatureTest do
  @moduledoc """
  E2E tests for quit message broadcast (US6).
  Run with: mix test --only liveview_feature
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Channels.{Registry, Server, Supervisor}

  setup do
    channel = "#qte2e-#{uid()}"
    ensure_channel(channel)
    {:ok, channel: channel}
  end

  describe "Quit E2E" do
    test "/quit with message removes the quitting user from the channel", %{
      conn: conn,
      channel: channel
    } do
      nick1 = "QE1#{uid()}"
      nick2 = "QE2#{uid()}"

      {:ok, view1, _} = live(chat_conn(conn, nick1), "/chat")
      join_channel(view1, channel)

      {:ok, view2, _} = live(chat_conn(conn, nick2), "/chat")
      join_channel(view2, channel)

      assert member?(channel, nick1)

      view1
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/quit See you later!"})

      # /quit parts every channel and then pushes intentional_disconnect. Waiting
      # for that push settles the async dispatch, so the durable channel
      # membership below is deterministic (no transient stream message needed).
      assert_push_event(view1, "intentional_disconnect", %{})

      refute member?(channel, nick1)
      assert member?(channel, nick2)
    end

    test "/quit without a message removes the quitting user from the channel", %{
      conn: conn,
      channel: channel
    } do
      nick1 = "QE3#{uid()}"
      nick2 = "QE4#{uid()}"

      {:ok, view1, _} = live(chat_conn(conn, nick1), "/chat")
      join_channel(view1, channel)

      {:ok, view2, _} = live(chat_conn(conn, nick2), "/chat")
      join_channel(view2, channel)

      assert member?(channel, nick1)

      view1
      |> element(~s([data-testid="chat-input-form"]))
      |> render_submit(%{"input" => "/quit"})

      assert_push_event(view1, "intentional_disconnect", %{})

      refute member?(channel, nick1)
      assert member?(channel, nick2)
    end
  end

  defp member?(channel, nick) do
    {:ok, state} = Server.get_state(channel)
    Enum.any?(state.members, fn {member, _role} -> member == nick end)
  end

  defp join_channel(view, channel) do
    view
    |> element(~s([data-testid="chat-input-form"]))
    |> render_submit(%{"input" => "/join #{channel}"})

    # Drain the async /join dispatch (FIFO behind this call) so channel
    # membership is settled before the test inspects it.
    _ = :sys.get_state(view.pid)
  end

  defp ensure_channel(name) do
    case Registry.lookup(name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> Supervisor.start_child(name)
    end
  end
end
