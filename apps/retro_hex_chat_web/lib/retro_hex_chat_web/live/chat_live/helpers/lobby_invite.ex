defmodule RetroHexChatWeb.ChatLive.Helpers.LobbyInvite do
  @moduledoc """
  Shared universal-lobby invite logic used by both command dispatch and the
  context menu. Mirrors `P2pInvite`: sends a PM invitation (rendered as a join
  card pointing at `/lobby/<token>`), notifies the target, and switches the
  sender to the PM conversation.
  """

  import Phoenix.LiveView, only: [push_event: 3]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Chat.Service
  alias RetroHexChatWeb.ChatLive.Helpers.{Messages, PM}

  @spec handle_lobby_invite(Phoenix.LiveView.Socket.t(), map(), map()) ::
          Phoenix.LiveView.Socket.t()
  def handle_lobby_invite(socket, session, payload) do
    %{target: target, token: token} = payload

    pm_content = lobby_invite_content(token)

    case Service.send_private_message(session.nickname, target, pm_content, "p2p_invite") do
      {:ok, _pm} ->
        Phoenix.PubSub.broadcast(
          RetroHexChat.PubSub,
          "user:#{target}",
          {:incoming_pm_notify, %{sender: session.nickname, type: :invite}}
        )

      {:error, _} ->
        :ok
    end

    socket = PM.open_pm_conversation(socket, target)

    confirm_msg =
      dgettext("chat", "Lobby invite sent to %{target}. Waiting for response...", target: target)

    socket
    |> Messages.system_event(confirm_msg)
    |> push_event("scroll_to_bottom", %{})
  end

  @spec lobby_invite_content(String.t()) :: String.t()
  def lobby_invite_content(token),
    do: dgettext("chat", "Universal lobby ready. Join the lobby: /lobby/%{token}", token: token)
end
