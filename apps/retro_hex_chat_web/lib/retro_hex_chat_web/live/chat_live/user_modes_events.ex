defmodule RetroHexChatWeb.ChatLive.UserModesEvents do
  @moduledoc """
  Handle the User Modes window — the IRC user modes on your own connection.

  Attached as `attach_hook(:user_modes_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  alias RetroHexChatWeb.ChatLive.CommandDispatch
  alias RetroHexChatWeb.ChatLive.Windows

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:halt, Phoenix.LiveView.Socket.t()} | {:cont, Phoenix.LiveView.Socket.t()}

  def handle_event("open_user_modes_dialog", _params, socket) do
    {:halt, open(socket)}
  end

  def handle_event("user_modes_submit", params, socket) do
    mode_string = if truthy?(params["wallops"]), do: "+w", else: "-w"

    {:halt,
     CommandDispatch.dispatch_command(socket, socket.assigns.session, "umode", [mode_string])}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}

  @doc "Opens/focuses the User Modes window."
  @spec open(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def open(socket), do: Windows.open(socket, "user-modes")

  defp truthy?(true), do: true
  defp truthy?("true"), do: true
  defp truthy?(_value), do: false
end
