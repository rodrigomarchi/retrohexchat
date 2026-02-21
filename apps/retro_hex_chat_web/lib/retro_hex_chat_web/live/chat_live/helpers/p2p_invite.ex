defmodule RetroHexChatWeb.ChatLive.Helpers.P2pInvite do
  @moduledoc """
  Shared P2P invite logic used by both command dispatch and context menu events.

  Sends a PM invitation to the target and shows a confirmation system message
  to the initiator, then switches the sender to the PM conversation.
  """

  import Phoenix.LiveView, only: [push_event: 3]

  alias RetroHexChatWeb.ChatLive.Helpers.{Messages, PM}

  alias RetroHexChat.Chat.Service

  @spec handle_p2p_invite(Phoenix.LiveView.Socket.t(), map(), map()) ::
          Phoenix.LiveView.Socket.t()
  def handle_p2p_invite(socket, session, payload) do
    %{target: target, session_type: session_type, token: token} = payload

    pm_content = p2p_invite_content(session_type, token)

    # Send PM invitation (persisted, appears in PM chat)
    case Service.send_private_message(session.nickname, target, pm_content, "p2p_invite") do
      {:ok, _pm} ->
        Phoenix.PubSub.broadcast(
          RetroHexChat.PubSub,
          "user:#{target}",
          {:incoming_pm_notify, %{sender: session.nickname}}
        )

      {:error, _} ->
        :ok
    end

    # Toast notification is sent by P2P.Service.notify_peer via "user:#{peer_nick}" PubSub
    # The PubSub handler in ChatLive handles the "p2p_invite" event

    # Switch sender to PM conversation with the target
    socket = PM.open_pm_conversation(socket, target)

    # Show confirmation system message to initiator (in the PM window)
    confirm_msg = "P2P invite sent to #{target}. Waiting for response..."

    socket
    |> Messages.system_event(confirm_msg)
    |> push_event("scroll_to_bottom", %{})
  end

  @spec p2p_invite_content(String.t(), String.t()) :: String.t()
  def p2p_invite_content("audio_call", token),
    do: "Audio call started. Join the lobby: /p2p/#{token}"

  def p2p_invite_content("video_call", token),
    do: "Video call started. Join the lobby: /p2p/#{token}"

  def p2p_invite_content("file_transfer", token),
    do: "File transfer started. Join the lobby: /p2p/#{token}"

  def p2p_invite_content(_generic, token),
    do: "P2P session started. Join the lobby: /p2p/#{token}"
end
