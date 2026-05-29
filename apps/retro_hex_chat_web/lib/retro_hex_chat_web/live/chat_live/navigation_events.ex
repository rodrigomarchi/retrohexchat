defmodule RetroHexChatWeb.ChatLive.NavigationEvents do
  @moduledoc """
  Handle window navigation events (window_next, window_prev, window_select).

  Builds an ordered window list from channels + PMs and switches the
  active window based on keyboard shortcuts.

  Attached as `attach_hook(:navigation_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.{Queries, UnreadTracker}
  alias RetroHexChatWeb.ChatLive.Helpers
  alias RetroHexChatWeb.ChatLive.Helpers.Messages, as: MessageHelpers

  def handle_event("window_next", _params, socket) do
    {:halt, navigate(socket, :next)}
  end

  def handle_event("window_prev", _params, socket) do
    {:halt, navigate(socket, :prev)}
  end

  def handle_event("window_select", %{"index" => index}, socket) do
    {:halt, navigate_to_index(socket, index)}
  end

  def handle_event("navigate_to_channel", %{"channel" => channel}, socket) do
    session = socket.assigns.session

    socket =
      if channel in session.channels do
        updated_session = Session.set_active_channel(session, channel)
        assign(socket, session: updated_session)
      else
        socket
      end

    {:halt, socket}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp navigate(socket, direction) do
    windows = build_window_list(socket.assigns.session)
    current = current_window(socket.assigns)

    case find_window_index(windows, current) do
      nil -> socket
      idx -> switch_to(socket, windows, move(idx, direction, length(windows)))
    end
  end

  defp navigate_to_index(socket, index) when is_integer(index) do
    windows = build_window_list(socket.assigns.session)
    # 1-based index, skip Status tab
    target_idx = index - 1

    if target_idx >= 0 and target_idx < length(windows) do
      switch_to(socket, windows, target_idx)
    else
      socket
    end
  end

  @spec build_window_list(Session.t()) :: [
          {:channel, String.t()} | {:pm, String.t()}
        ]
  def build_window_list(session) do
    channels = Enum.sort(session.channels) |> Enum.map(&{:channel, &1})

    pms =
      if session.pm_conversations do
        Enum.sort(session.pm_conversations) |> Enum.map(&{:pm, &1})
      else
        []
      end

    channels ++ pms
  end

  defp current_window(assigns) do
    cond do
      assigns.show_status_tab -> :status
      assigns.session.active_pm -> {:pm, assigns.session.active_pm}
      assigns.session.active_channel -> {:channel, assigns.session.active_channel}
      true -> nil
    end
  end

  defp find_window_index(_windows, :status), do: nil
  defp find_window_index(_windows, nil), do: nil

  defp find_window_index(windows, target) do
    Enum.find_index(windows, &(&1 == target))
  end

  defp move(idx, :next, len), do: rem(idx + 1, len)
  defp move(idx, :prev, len), do: rem(idx - 1 + len, len)

  defp switch_to(socket, windows, idx) do
    case Enum.at(windows, idx) do
      {:channel, channel} -> switch_channel(socket, channel)
      {:pm, nickname} -> switch_pm(socket, nickname)
      nil -> socket
    end
  end

  defp switch_channel(socket, channel) do
    session = Session.set_active_channel(socket.assigns.session, channel)
    unread_counts = UnreadTracker.reset(socket.assigns.unread_counts, channel)
    highlight = MapSet.delete(socket.assigns.highlight_channels, channel)
    flash = MapSet.delete(socket.assigns.flash_channels, channel)

    if socket.assigns.pm_typing_timer,
      do: Process.cancel_timer(socket.assigns.pm_typing_timer)

    socket
    |> assign(
      session: session,
      unread_counts: unread_counts,
      highlight_channels: highlight,
      flash_channels: flash,
      show_status_tab: false,
      pm_typing_from: nil,
      pm_typing_timer: nil
    )
    |> Helpers.Channel.load_channel_users(channel)
    |> Helpers.Channel.load_channel_messages_with_pagination(channel)
    |> Helpers.Session.push_reconnect_state()
  end

  defp switch_pm(socket, nickname) do
    session = Session.set_active_pm(socket.assigns.session, nickname)
    messages = load_pm_messages(session.nickname, nickname, session.ignore_list)
    unread_counts = UnreadTracker.reset(socket.assigns.unread_counts, "pm:#{nickname}")
    flash = MapSet.delete(socket.assigns.flash_channels, "pm:#{nickname}")

    if socket.assigns.pm_typing_timer,
      do: Process.cancel_timer(socket.assigns.pm_typing_timer)

    socket
    |> assign(
      session: session,
      unread_counts: unread_counts,
      flash_channels: flash,
      current_topic: nil,
      current_modes: nil,
      show_status_tab: false,
      pm_typing_from: nil,
      pm_typing_timer: nil
    )
    |> Phoenix.LiveView.stream(:chat_messages, messages, reset: true)
    |> Helpers.Session.push_reconnect_state()
  end

  defp load_pm_messages(my_nick, other_nick, ignore_list) do
    Queries.list_private_messages(my_nick, other_nick, limit: 50)
    |> MessageHelpers.visible_private_messages(ignore_list)
    |> Enum.reverse()
    |> Enum.map(&pm_to_stream_item/1)
  end

  defp pm_to_stream_item(pm) do
    %{
      id: pm_field(pm, [:id]),
      author: pm_field(pm, [:sender, :sender_nickname]),
      content: pm.content,
      type: pm_resolve_type(pm),
      timestamp: pm_field(pm, [:inserted_at])
    }
  end

  defp pm_field(pm, keys) when is_map(pm) do
    Enum.reduce_while(keys, nil, fn key, _acc ->
      case Map.get(pm, key) do
        nil -> {:cont, nil}
        val -> {:halt, val}
      end
    end)
  end

  defp pm_field(pm, keys) when is_struct(pm), do: pm_field(Map.from_struct(pm), keys)

  defp pm_resolve_type(%{type: type}) when is_atom(type), do: type
  defp pm_resolve_type(%{type: type}) when is_binary(type), do: String.to_existing_atom(type)
  defp pm_resolve_type(_), do: :message
end
