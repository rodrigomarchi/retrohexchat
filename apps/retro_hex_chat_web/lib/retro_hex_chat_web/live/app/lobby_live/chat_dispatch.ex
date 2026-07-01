defmodule RetroHexChatWeb.App.LobbyLive.ChatDispatch do
  @moduledoc """
  Turns a composer submission into a lobby chat effect.

  The lobby shares the chat `Composer`, so submissions arrive already parsed by
  `Commands.Parser` into a plain message or a `/command`. Unlike the main chat,
  the lobby is an ephemeral two-peer session with no channels, so it supports
  only the handful of commands that make sense here (`/me`, `/clear`, `/help`);
  everything else is echoed back as a local system notice. Plain messages and
  `/me` actions go through `Lobby.send_lobby_message/4` and reach both peers via
  the `lobby:<token>` PubSub topic; `/clear` and `/help` are local-only.
  """

  use Gettext, backend: RetroHexChatWeb.Gettext

  import Phoenix.LiveView, only: [send_update: 2]

  alias RetroHexChat.Commands.Parser
  alias RetroHexChat.Lobby
  alias RetroHexChatWeb.App.LobbyLive.Components.ChatIsland

  @doc "Available lobby chat commands, for help + validation."
  @spec commands() :: [String.t()]
  def commands, do: ~w(me clear help)

  @spec dispatch(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  def dispatch(socket, text) do
    case Parser.parse(text) do
      {:message, message} -> send_message(socket, message)
      {:command, name, args} -> run_command(socket, name, args)
    end
  end

  defp run_command(socket, "me", args) do
    case args |> Enum.join(" ") |> String.trim() do
      "" -> socket
      action -> send_message(socket, action, "action")
    end
  end

  defp run_command(socket, "clear", _args) do
    send_update(ChatIsland, id: ChatIsland.id(), clear: true)
    socket
  end

  defp run_command(socket, "help", _args) do
    notice(socket, dgettext("lobby", "Lobby commands: /me <action>, /clear, /help"))
  end

  defp run_command(socket, name, _args) do
    notice(socket, dgettext("lobby", "Unknown command: /%{name}", name: name))
  end

  defp send_message(socket, content, type \\ "message") do
    case String.trim(content) do
      "" ->
        socket

      trimmed ->
        Lobby.send_lobby_message(socket.assigns.token, socket.assigns.user_id, trimmed, type)
        socket
    end
  end

  defp notice(socket, text) do
    send_update(ChatIsland, id: ChatIsland.id(), system_message: text)
    socket
  end
end
