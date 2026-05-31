defmodule RetroHexChatWeb.ChatLive.Helpers.GameInvite do
  @moduledoc """
  Game invite logic for the /game command.

  Sends a PM invitation to the target with a /game/{token} link,
  shows a confirmation system message, and switches the sender to the PM conversation.
  """

  import Phoenix.LiveView, only: [push_event: 3]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Chat.Service
  alias RetroHexChatWeb.ChatLive.Helpers.{Messages, PM}

  @spec handle_game_invite(Phoenix.LiveView.Socket.t(), map(), map()) ::
          Phoenix.LiveView.Socket.t()
  def handle_game_invite(socket, session, payload) do
    %{target: target, token: token} = payload

    pm_content = gettext("Game session started! Join the lobby: /game/%{token}", token: token)

    socket =
      case Service.send_private_message(session.nickname, target, pm_content, "p2p_invite") do
        {:ok, _pm} ->
          Phoenix.PubSub.broadcast(
            RetroHexChat.PubSub,
            "user:#{target}",
            {:incoming_pm_notify, %{sender: session.nickname, type: :invite}}
          )

          # Toast notification so receiver can Accept → push_navigate (same tab)
          Phoenix.PubSub.broadcast(
            RetroHexChat.PubSub,
            "user:#{target}",
            %{event: "game_invite", payload: %{token: token, from: session.nickname}}
          )

          socket
          |> PM.open_pm_conversation(target)
          |> Messages.system_event(
            gettext("Game invite sent to %{target}. Waiting for response...", target: target)
          )

        {:error, _reason} ->
          Messages.system_event(
            socket,
            gettext("Failed to send game invite to %{target}.", target: target)
          )
      end

    push_event(socket, "scroll_to_bottom", %{})
  end
end
