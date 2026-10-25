defmodule RetroHexChatWeb.ChatLive.WindowOpenEvents do
  @moduledoc """
  The menu, toolbar and Start menu events that only open (or focus) a window.

  Each window's state and events live in its dialog island, mounted inside the
  window; this hook only turns the event into the window's id for
  `ChatLive.Windows.open/2`.

  Attached as `attach_hook(:window_open_events, :handle_event, ...)` in DesktopLive.
  """

  alias RetroHexChatWeb.ChatLive.Windows

  @opens %{
    "toggle_address_book" => "address-book",
    "open_autojoin_dialog" => "autojoin",
    "open_highlight_dialog" => "highlight",
    "open_ignore_list_dialog" => "ignore-list",
    "open_nick_colors_dialog" => "nick-colors",
    "open_perform_dialog" => "perform",
    "open_trusted_terminals_dialog" => "trusted-terminals",
    "toggle_notify_list" => "notify-list",
    "toggle_url_catcher" => "url-catcher"
  }

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:halt, Phoenix.LiveView.Socket.t()} | {:cont, Phoenix.LiveView.Socket.t()}
  def handle_event(event, _params, socket) when is_map_key(@opens, event) do
    {:halt, Windows.open(socket, Map.fetch!(@opens, event))}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}
end
