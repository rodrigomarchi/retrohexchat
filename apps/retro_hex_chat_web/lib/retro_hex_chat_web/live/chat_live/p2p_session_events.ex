defmodule RetroHexChatWeb.ChatLive.P2PSessionEvents do
  @moduledoc """
  The chat's side of a P2P session it does not host.

  Being in a session happens at `/p2p/:token` and nowhere else — the media, the
  files, the game, the statistics and the recovery all belong to
  `RetroHexChatWeb.App.P2PLive`, on a page of its own. What is left here is
  everything the chat itself is responsible for and the session cannot be:

    * **the invite, whole.** It is a real private message, persisted, with a
      card in the history, and creating the session *is* sending it. That is
      conversation, and conversation is the chat's — including declining one,
      which happens on a card and never inside a session.
    * **saying what happened.** A refusal or an ending belongs in the
      conversation, which is where every other one in this product appears.

  There is no accept event here any more, because there is nothing to accept:
  the card carries the session's own address, and following it is the consent.
  One click, one door, the same one for the person who sent the invite and the
  person who got it.

  What the chat keeps about the sessions themselves is only what its own chrome
  draws, and that is `RetroHexChatWeb.ChatLive.P2PReadModel`.
  """

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias Phoenix.LiveView.Socket
  alias RetroHexChat.Accounts.ServerRoles
  alias RetroHexChat.Chat.Service, as: ChatService
  alias RetroHexChat.Commands.Handlers.Lobby, as: LobbyCommand
  alias RetroHexChat.Lobby
  alias RetroHexChatWeb.App.SessionHelpers
  alias RetroHexChatWeb.ChatLive.Helpers.LobbyInvite
  alias RetroHexChatWeb.ChatLive.Helpers.Messages
  alias RetroHexChatWeb.ChatLive.Helpers.PM, as: PMHelper
  alias RetroHexChatWeb.ChatLive.P2PReadModel
  alias RetroHexChatWeb.ChatLive.ShareCards

  @type event_result :: {:cont | :halt, Socket.t()}

  @doc "Rebuild what the chat knows about P2P, after a mount or a reconnect."
  @spec rehydrate(Socket.t()) :: Socket.t()
  def rehydrate(socket), do: P2PReadModel.refresh_all(socket)

  @doc """
  Refresh the badge of one private conversation without joining anything.

  Kept as the chat's own name for it because half a dozen callers in the chat
  ask for exactly this when a conversation comes into focus.
  """
  @spec refresh_pm_session_read_model(Socket.t(), String.t() | nil) :: Socket.t()
  def refresh_pm_session_read_model(socket, peer_nick),
    do: P2PReadModel.refresh_pm(socket, peer_nick)

  @spec handle_event(String.t(), map(), Socket.t()) :: event_result()
  def handle_event("p2p_start_pm_session", params, socket) do
    {:halt, start_pm_session(socket, params)}
  end

  def handle_event("p2p_decline_invite", %{"token" => token}, socket) do
    {:halt, decline_invite(socket, token)}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}

  @doc """
  What one of this reader's sessions has just done, heard on their own topic.

  The session tells the people in it; the room's topic is where the negotiation
  crosses and the chat has no business there. Three sentences arrive: an invite
  showed up, a session moved on, a session is over — and all three end in the
  same place, which is the conversation re-reading the row.
  """
  @spec handle_info(term(), Socket.t()) :: event_result()
  def handle_info(%{event: "lobby_session_progress", payload: %{peer_nick: peer_nick}}, socket) do
    {:halt, socket |> P2PReadModel.refresh_pm(peer_nick) |> ShareCards.refresh()}
  end

  def handle_info(%{event: "lobby_session_ended", payload: payload}, socket) do
    {:halt, ended(socket, payload)}
  end

  def handle_info(_message, socket), do: {:cont, socket}

  # A session that ended is a card that has to say so. The invite row is
  # refreshed by hand because it is a persisted message and not a badge: the
  # row in the history keeps the token that names which card to redraw.
  defp ended(socket, %{peer_nick: peer_nick, token: token}) do
    socket
    |> P2PReadModel.refresh_pm(peer_nick)
    |> PMHelper.refresh_p2p_invite_row(peer_nick, token)
    |> ShareCards.refresh()
  end

  defp ended(socket, _payload), do: socket

  defp decline_invite(socket, token) do
    nickname = socket.assigns.session.nickname
    creator = creator_nick(token)

    with {:ok, user_id} <- SessionHelpers.resolve_user_id(nickname),
         :ok <- Lobby.decline_session(token, user_id) do
      persist_p2p_system(
        socket,
        creator,
        dgettext("chat", "%{nick} declined the P2P invite.", nick: nickname)
      )

      socket
      |> P2PReadModel.drop_pm(creator)
      |> PMHelper.refresh_p2p_invite_row(creator, token)
      |> ShareCards.refresh()
    else
      {:error, message} -> Messages.system_event(socket, message)
      _unregistered -> socket
    end
  end

  defp start_pm_session(socket, params) do
    peer = params["peer"] || socket.assigns.session.active_pm

    if is_binary(peer) and peer != "" do
      session = socket.assigns.session

      case LobbyCommand.execute([peer], lobby_command_context(session)) do
        {:ok, :ui_action, :lobby_invite, payload} ->
          LobbyInvite.handle_lobby_invite(socket, session, payload)

        {:error, message} ->
          Messages.error_event(socket, message)
      end
    else
      socket
    end
  end

  defp lobby_command_context(session) do
    %{
      nickname: session.nickname,
      identified: session.identified,
      active_channel: session.active_channel,
      channels: session.channels,
      owner_in: [],
      operator_in: [],
      half_operator_in: [],
      is_admin: ServerRoles.admin?(session.nickname, session.identified),
      is_server_operator: ServerRoles.server_operator?(session.nickname, session.identified)
    }
  end

  defp creator_nick(token) do
    case Lobby.session_summary(token) do
      {:ok, %{created_by: created_by}} -> created_by
      _absent -> nil
    end
  end

  # A line the other side can still read tomorrow. The ephemeral notice says it
  # now; this is what a conversation reopened next week still shows.
  defp persist_p2p_system(socket, peer_nick, text) when is_binary(peer_nick) do
    _ =
      ChatService.send_private_message(
        socket.assigns.session.nickname,
        peer_nick,
        text,
        "p2p_system"
      )

    :ok
  end

  defp persist_p2p_system(_socket, _peer_nick, _text), do: :ok
end
