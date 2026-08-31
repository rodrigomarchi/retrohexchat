defmodule RetroHexChatWeb.ChatLive.Helpers.LobbyInvite do
  @moduledoc """
  Sending a P2P invite, which is the same act as creating the session.

  The invite is a real private message: it sends a request line into the PM,
  notifies the target, switches the sender to that conversation and opens the
  session's starting room as its creator. The `/lobby/<token>` path stays
  embedded in the text for legacy token resolution.

  With a session already active the invite is NOT delivered yet: the switch
  confirm opens first, and only confirming ends the current session — the
  invite goes out when that session actually closes, never before.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Chat.Service
  alias RetroHexChat.Lobby
  alias RetroHexChatWeb.ChatLive.Helpers.{Messages, PM}
  alias RetroHexChatWeb.ChatLive.P2PSessionEvents

  @spec handle_lobby_invite(Phoenix.LiveView.Socket.t(), map(), map()) ::
          Phoenix.LiveView.Socket.t()
  def handle_lobby_invite(socket, session, payload) do
    case socket.assigns[:p2p_session] do
      nil ->
        deliver_invite(socket, session, payload)

      p2p ->
        P2PSessionEvents.open_switch_confirm(socket, p2p.peer_nick, payload.target)
        assign(socket, p2p_pending: %{kind: :outgoing, payload: payload})
    end
  end

  @doc """
  Sends the invite PM, opens the conversation and takes the session's starting
  room as its creator. Also the continuation after a confirmed switch.
  """
  @spec deliver_invite(Phoenix.LiveView.Socket.t(), map(), map()) ::
          Phoenix.LiveView.Socket.t()
  def deliver_invite(socket, session, %{token: token} = payload) when is_binary(token) do
    do_deliver_invite(socket, session, payload)
  end

  def deliver_invite(socket, session, %{creator_id: creator_id, target_id: target_id} = payload) do
    case Lobby.create_session(creator_id, target_id) do
      {:ok, %{token: token}} ->
        do_deliver_invite(socket, session, Map.put(payload, :token, token))

      {:error, message} ->
        Messages.system_event(socket, message)
    end
  end

  def deliver_invite(socket, _session, _payload) do
    Messages.system_event(socket, dgettext("chat", "Could not start the P2P invite."))
  end

  defp do_deliver_invite(socket, session, payload) do
    %{target: target, token: token} = payload

    case Service.send_private_message(
           session.nickname,
           target,
           lobby_invite_content(token),
           "p2p_invite"
         ) do
      {:ok, _pm} -> :ok
      {:error, _reason} -> :ok
    end

    socket = PM.open_pm_conversation(socket, target)

    confirm_msg =
      dgettext("chat", "P2P request sent to %{target}. Waiting for response...", target: target)

    socket
    |> Messages.system_event(confirm_msg)
    |> push_event("scroll_to_bottom", %{})
    |> P2PSessionEvents.start_as_creator(token, payload.creator_id)
  end

  @spec lobby_invite_content(String.t()) :: String.t()
  def lobby_invite_content(token),
    do:
      dgettext("chat", "P2P session request. Use the P2P control in this PM. /lobby/%{token}",
        token: token
      )
end
