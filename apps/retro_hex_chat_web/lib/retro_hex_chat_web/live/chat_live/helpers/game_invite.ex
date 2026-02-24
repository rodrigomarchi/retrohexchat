defmodule RetroHexChatWeb.ChatLive.Helpers.GameInvite do
  @moduledoc """
  Game invite logic for the /game command.

  Sends a PM invitation to the target with a /game/{token} link,
  shows a confirmation system message, and switches the sender to the PM conversation.
  """

  import Phoenix.LiveView, only: [push_event: 3]

  alias RetroHexChat.Chat.Service
  alias RetroHexChatWeb.ChatLive.Helpers.{Messages, PM}

  @spec handle_game_invite(Phoenix.LiveView.Socket.t(), map(), map()) ::
          Phoenix.LiveView.Socket.t()
  def handle_game_invite(socket, session, payload) do
    %{target: target, token: token} = payload

    pm_content = "Game session started! Join the lobby: /game/#{token}"

    socket =
      case Service.send_private_message(session.nickname, target, pm_content, "game_invite") do
        {:ok, _pm} ->
          Phoenix.PubSub.broadcast(
            RetroHexChat.PubSub,
            "user:#{target}",
            {:incoming_pm_notify, %{sender: session.nickname}}
          )

          socket
          |> PM.open_pm_conversation(target)
          |> Messages.system_event("Game invite sent to #{target}. Waiting for response...")

        {:error, reason} ->
          msg = "Failed to send game invite to #{target}: #{reason}"
          Messages.system_event(socket, msg)
      end

    push_event(socket, "scroll_to_bottom", %{})
  end
end
