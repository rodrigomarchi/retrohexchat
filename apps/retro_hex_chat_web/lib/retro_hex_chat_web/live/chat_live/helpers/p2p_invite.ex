defmodule RetroHexChatWeb.ChatLive.Helpers.P2pInvite do
  @moduledoc """
  Shared P2P invite logic used by both command dispatch and context menu events.

  Sends a PM invitation to the target and shows a confirmation system message
  to the initiator.
  """

  import Phoenix.LiveView, only: [push_event: 3, stream_insert: 3]
  import RetroHexChatWeb.ChatLive.Helpers, only: [system_message: 1]

  alias RetroHexChat.Chat.Service

  @spec handle_p2p_invite(Phoenix.LiveView.Socket.t(), map(), map()) ::
          Phoenix.LiveView.Socket.t()
  def handle_p2p_invite(socket, session, payload) do
    %{target: target, session_type: session_type, token: token} = payload

    pm_content = p2p_invite_content(session_type, token)

    # Send PM invitation (persisted, appears in PM chat)
    case Service.send_private_message(session.nickname, target, pm_content, "p2p_invite") do
      {:ok, _pm} -> :ok
      {:error, _} -> :ok
    end

    # Toast notification is sent by P2P.Service.notify_peer via "user:#{peer_nick}" PubSub
    # The PubSub handler in ChatLive handles the "p2p_invite" event

    # Show confirmation system message to initiator
    confirm_msg = "Convite P2P enviado para #{target}. Aguardando resposta..."

    socket
    |> stream_insert(:chat_messages, system_message(confirm_msg))
    |> push_event("scroll_to_bottom", %{})
  end

  @spec p2p_invite_content(String.t(), String.t()) :: String.t()
  def p2p_invite_content("audio_call", token),
    do: "Chamada de audio iniciada. Entre no lobby: /p2p/#{token}"

  def p2p_invite_content("video_call", token),
    do: "Chamada de video iniciada. Entre no lobby: /p2p/#{token}"

  def p2p_invite_content("file_transfer", token),
    do: "Transferencia de arquivo iniciada. Entre no lobby: /p2p/#{token}"

  def p2p_invite_content(_generic, token),
    do: "Sessao P2P iniciada. Entre no lobby: /p2p/#{token}"
end
