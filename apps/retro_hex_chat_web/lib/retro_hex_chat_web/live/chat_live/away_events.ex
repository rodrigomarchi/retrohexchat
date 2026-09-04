defmodule RetroHexChatWeb.ChatLive.AwayEvents do
  @moduledoc """
  Handle the Away window and the status-bar away toggle.

  Both surfaces run the same `/away` command; the last message is remembered on
  the parent (`account_last_away_message`) so the status-bar toggle can restore
  it without asking again.

  Attached as `attach_hook(:away_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChatWeb.ChatLive.CommandDispatch
  alias RetroHexChatWeb.ChatLive.Windows

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:halt, Phoenix.LiveView.Socket.t()} | {:cont, Phoenix.LiveView.Socket.t()}

  def handle_event("open_away_dialog", _params, socket) do
    {:halt, open(socket)}
  end

  def handle_event("away_submit", params, socket) do
    message =
      params
      |> Map.get("away_message", "")
      |> String.trim()
      |> case do
        "" -> dgettext("chat", "Away")
        value -> value
      end

    if truthy?(Map.get(params, "away", "true")) do
      {:halt,
       socket
       |> dispatch("away", [message])
       |> assign(account_last_away_message: message)}
    else
      {:halt,
       socket
       |> remember_away_message(message)
       |> dispatch("away", [])}
    end
  end

  def handle_event("away_clear", _params, socket) do
    {:halt,
     socket
     |> remember_away_message()
     |> dispatch("away", [])}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}

  @doc "Opens/focuses the Away window."
  @spec open(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def open(socket), do: Windows.open(socket, "away")

  defp remember_away_message(socket, fallback \\ nil) do
    message = socket.assigns.session.away_message || fallback

    case message do
      nil -> socket
      "" -> socket
      value -> assign(socket, account_last_away_message: value)
    end
  end

  defp dispatch(socket, name, args) do
    CommandDispatch.dispatch_command(socket, socket.assigns.session, name, args)
  end

  defp truthy?(true), do: true
  defp truthy?("true"), do: true
  defp truthy?(_value), do: false
end
