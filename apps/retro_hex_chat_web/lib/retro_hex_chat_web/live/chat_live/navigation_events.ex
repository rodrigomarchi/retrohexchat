defmodule RetroHexChatWeb.ChatLive.NavigationEvents do
  @moduledoc """
  Handle window navigation events (window_next, window_prev, window_select).

  Builds an ordered window list from channels + PMs and switches the
  active window based on keyboard shortcuts.

  Attached as `attach_hook(:navigation_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  alias RetroHexChat.Accounts.Session
  alias RetroHexChatWeb.ChatLive.Helpers.Conversation

  def handle_event("window_next", _params, socket) do
    {:halt, navigate(socket, :next)}
  end

  def handle_event("window_prev", _params, socket) do
    {:halt, navigate(socket, :prev)}
  end

  def handle_event("window_select", %{"index" => index}, socket) do
    {:halt, navigate_to_index(socket, index)}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp navigate(socket, direction) do
    windows = build_window_list(socket.assigns.session, socket.assigns[:open_pm_tabs] || [])

    current = current_window(socket.assigns)

    case find_window_index(windows, current) do
      nil -> socket
      idx -> switch_to(socket, windows, move(idx, direction, length(windows)))
    end
  end

  defp navigate_to_index(socket, index) when is_integer(index) do
    windows = build_window_list(socket.assigns.session, socket.assigns[:open_pm_tabs] || [])

    # 1-based index, skip Status tab
    target_idx = index - 1

    if target_idx >= 0 and target_idx < length(windows) do
      switch_to(socket, windows, target_idx)
    else
      socket
    end
  end

  # Joined channels in join order, then open PMs. A fixed, predictable cycle:
  # mIRC walks its window list, it does not jump to whatever was touched last.
  @spec build_window_list(Session.t(), [String.t()]) :: [
          {:channel, String.t()} | {:pm, String.t()}
        ]
  def build_window_list(session, open_pm_tabs) do
    channel_keys =
      for channel <- session.channels || [], is_binary(channel), do: {:channel, channel}

    pm_keys = for pm <- open_pm_tabs || [], is_binary(pm), do: {:pm, pm}

    Enum.uniq(channel_keys ++ pm_keys)
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

  # Cycling to a window is the same act as clicking its tab, and goes through the
  # same door: a copy of the switch here is how this path came to skip the
  # composer reset and the search close that the click path runs.
  defp switch_to(socket, windows, idx) do
    case Enum.at(windows, idx) do
      {:channel, channel} -> Conversation.activate_channel(socket, channel)
      {:pm, nickname} -> Conversation.activate_pm(socket, nickname)
      nil -> socket
    end
  end
end
