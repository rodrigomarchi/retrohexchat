defmodule RetroHexChatWeb.ChatLive.Helpers.LobbyInvite do
  @moduledoc """
  Shared P2P invite logic used by both command dispatch and the context
  menu. Sends a PM invitation (rendered as an in-chat card with
  Accept/Decline; the `/lobby/<token>` path in the content only embeds the
  session token for card enrichment), notifies the target, switches the
  sender to the PM conversation, and tracks the session as its creator.

  With a P2P session already active, the invite is NOT delivered yet: the
  switch confirm opens first, and only confirming ends the current session and
  opens outgoing setup. The lobby row and invite PM are still created only after
  setup submit.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Chat.Service
  alias RetroHexChat.Lobby
  alias RetroHexChatWeb.ChatLive.Components.P2PConfirmDialog
  alias RetroHexChatWeb.ChatLive.Helpers.{Messages, PM}
  alias RetroHexChatWeb.ChatLive.P2PSessionEvents

  @spec handle_lobby_invite(Phoenix.LiveView.Socket.t(), map(), map()) ::
          Phoenix.LiveView.Socket.t()
  def handle_lobby_invite(socket, _session, payload) do
    case socket.assigns.p2p_session do
      nil ->
        P2PSessionEvents.open_outgoing_setup(socket, payload)

      p2p ->
        Phoenix.LiveView.send_update(P2PConfirmDialog,
          id: P2PConfirmDialog.id(),
          action: {:open_switch, p2p.peer_nick, payload.target}
        )

        assign(socket, p2p_pending: %{kind: :outgoing, payload: payload})
    end
  end

  @doc """
  Sends the invite PM, opens the conversation and joins the new session as
  creator. Also the continuation after outgoing setup or a confirmed switch.
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
    |> P2PSessionEvents.start_as_creator(token, payload.creator_id)
  end

  @spec lobby_invite_content(String.t()) :: String.t()
  def lobby_invite_content(token),
    do:
      dgettext("chat", "P2P session invite — accept it on this card. /lobby/%{token}",
        token: token
      )
end
