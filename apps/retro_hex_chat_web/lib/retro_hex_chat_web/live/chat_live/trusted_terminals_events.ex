defmodule RetroHexChatWeb.ChatLive.TrustedTerminalsEvents do
  @moduledoc """
  Entry points for the Trusted Terminals managed window.
  """

  alias RetroHexChatWeb.ChatLive.Windows

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:halt, Phoenix.LiveView.Socket.t()} | {:cont, Phoenix.LiveView.Socket.t()}
  def handle_event("open_trusted_terminals_dialog", _params, socket) do
    {:halt, Windows.open(socket, "trusted-terminals")}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}
end
