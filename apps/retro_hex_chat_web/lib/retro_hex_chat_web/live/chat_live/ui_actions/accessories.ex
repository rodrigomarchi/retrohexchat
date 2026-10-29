defmodule RetroHexChatWeb.ChatLive.UiActions.Accessories do
  @moduledoc """
  The Accessories — Hex Paint, ASCII Art and Hex Radio — opened by their
  commands (`/paint`, `/ascii`, `/radio`) the way their menu entries open them.
  """

  alias RetroHexChatWeb.ChatLive.Windows

  @spec handle_ui_action(Phoenix.LiveView.Socket.t(), atom(), map()) ::
          Phoenix.LiveView.Socket.t()
  def handle_ui_action(socket, :open_paint, _payload), do: Windows.open(socket, "paint")
  def handle_ui_action(socket, :open_ascii_art, _payload), do: Windows.open(socket, "ascii-art")
  def handle_ui_action(socket, :open_radio, _payload), do: Windows.open(socket, "radio")
end
