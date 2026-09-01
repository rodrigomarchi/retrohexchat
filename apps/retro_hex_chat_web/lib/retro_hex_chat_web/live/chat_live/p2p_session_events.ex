defmodule RetroHexChatWeb.ChatLive.P2PSessionEvents do
  @moduledoc """
  The chat's side of a P2P session it no longer hosts.

  Being in a session moved out — `RetroHexChatWeb.App.P2PLive` owns the media,
  the files, the game, the statistics and the recovery, whether it is rendered
  in the chat's P2P window or in a tab of its own. What is left here is
  everything the chat itself is responsible for and the session cannot be:

    * **the invite, whole.** It is a real private message, persisted, with a
      card in the history, and creating the session *is* sending it. That is
      conversation, and conversation is the chat's — including declining one,
      which happens on a card and never inside a session.
    * **the window.** The chat's window manager owns opening, focusing, the X
      and the geometry, so the controls that mean those still arrive here and
      are handed on.
    * **swapping one session for another.** Only the chat can be in the
      position of already having a session and being asked for a different
      peer's.
    * **saying what happened.** A refusal or an ending belongs in the
      conversation, which is where every other one in this product appears. The
      surface sends the sentence; this puts it where the person is reading.

  What the chat keeps about the session itself is only what its own chrome
  draws, and that is `RetroHexChatWeb.ChatLive.P2PReadModel`.
  """

  import Phoenix.Component, only: [assign: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias Phoenix.LiveView.Socket
  alias RetroHexChat.Accounts.ServerRoles
  alias RetroHexChat.Chat.Service, as: ChatService
  alias RetroHexChat.Commands.Handlers.Lobby, as: LobbyCommand
  alias RetroHexChat.Lobby
  alias RetroHexChat.Lobby.Schema.Session, as: LobbySession
  alias RetroHexChatWeb.App.SessionHelpers
  alias RetroHexChatWeb.ChatLive.Helpers.LobbyInvite
  alias RetroHexChatWeb.ChatLive.Helpers.Messages
  alias RetroHexChatWeb.ChatLive.Helpers.PM, as: PMHelper
  alias RetroHexChatWeb.ChatLive.P2PReadModel
  alias RetroHexChatWeb.ChatLive.ShareCards
  alias RetroHexChatWeb.ChatLive.Windows
  alias RetroHexChatWeb.Live.P2PConfirmDialog

  @window_id "p2p-call"
  @confirm_id "p2p-switch-dialog"

  @type event_result :: {:cont | :halt, Socket.t()}

  @doc """
  The id the chat renders its confirmation under.

  Distinct from the session surface's on purpose: both are in the document at
  the same time whenever the session is embedded, and the only question the
  chat ever asks is the one the session cannot — whether to swap it for another
  peer's.
  """
  @spec confirm_dialog_id() :: String.t()
  def confirm_dialog_id, do: @confirm_id

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

  @doc """
  Track a freshly created invite as its creator and open the surface onto it.

  The creator does not take a seat yet — a pending invite is a card, not a
  connection — but the starting room is already the right screen: it is where
  the host chooses devices while waiting for an answer.
  """
  @spec start_as_creator(Socket.t(), String.t(), integer()) :: Socket.t()
  def start_as_creator(socket, token, creator_id) do
    socket
    |> P2PReadModel.open(token, creator_id, :creator, "pending")
    |> Windows.open(@window_id)
  end

  @spec handle_event(String.t(), map(), Socket.t()) :: event_result()
  def handle_event("p2p_start_pm_session", params, socket) do
    {:halt, start_pm_session(socket, params)}
  end

  def handle_event("p2p_accept_invite", %{"token" => token}, socket) do
    {:halt, request_accept(socket, token)}
  end

  def handle_event("p2p_decline_invite", %{"token" => token}, socket) do
    {:halt, decline_invite(socket, token)}
  end

  # The P2P menu without a session: teach the entry points and drop the
  # inline help card for the full walkthrough.
  def handle_event("p2p_how_to_start", _params, socket) do
    socket =
      socket
      |> Messages.system_event(
        dgettext(
          "chat",
          "Start a P2P session with /p2p <nick>, or right-click a user in the nicklist."
        )
      )
      |> Messages.inline_help_event(
        "feature-p2p-in-chat",
        dgettext("chat", "P2P Sessions in Chat")
      )

    {:halt, socket}
  end

  def handle_event("p2p_statusbar_click", _params, %{assigns: %{p2p_session: %{}}} = socket) do
    {:halt, Windows.open(socket, @window_id)}
  end

  def handle_event("p2p_statusbar_click", _params, socket), do: {:halt, socket}

  # The stop button and the window's X belong to the chat's chrome; what they
  # mean belongs to the session, which is the only process that knows whether
  # the answer is a confirmation or cancelling an invite nobody answered.
  def handle_event("p2p_statusbar_stop", _params, %{assigns: %{p2p_session: %{}}} = socket) do
    {:halt, command(socket, {:event, "p2p_end_session"})}
  end

  def handle_event("p2p_statusbar_stop", _params, socket), do: {:halt, socket}

  def handle_event("p2p_window_close", _params, %{assigns: %{p2p_session: %{}}} = socket) do
    {:halt, command(socket, {:event, "p2p_window_close"})}
  end

  def handle_event("p2p_window_close", _params, socket), do: {:halt, socket}

  def handle_event("p2p_confirm_switch", _params, socket) do
    close_confirm()
    {:halt, confirm_switch(socket)}
  end

  def handle_event("p2p_confirm_cancel", _params, socket) do
    close_confirm()

    # Backing out clears the staged switch. The token branch is defensive for
    # callers that stage an already-created invite.
    case socket.assigns[:p2p_pending] do
      %{kind: :outgoing, payload: %{token: token, creator_id: creator_id}} ->
        _ = Lobby.cancel_invite(token, creator_id)
        :ok

      _none ->
        :ok
    end

    {:halt, assign(socket, p2p_pending: nil)}
  end

  # Controls the chat's own chrome carries — the menu bar, the Start menu, the
  # desktop launchers, the PM badge — that mean something only the session can
  # do. The click lands here because that is where the markup is; what it means
  # is handed on.
  @forwarded ~w(
    p2p_console_select p2p_end_session p2p_retry_connection
    p2p_toggle_call_mini p2p_toggle_privacy toggle_network_info
    p2p_start_audio p2p_start_video
  )

  def handle_event(event, params, %{assigns: %{p2p_session: %{}}} = socket)
      when event in @forwarded do
    {:halt, command(socket, {:event, event, params})}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}

  @doc """
  Hand a chat-owned control to the session it means.

  The window's controls are bound on the chat's window, because that is where
  the click lands, and the session is what they act on.
  """
  @spec forward(Socket.t(), String.t()) :: Socket.t()
  def forward(socket, event), do: command(socket, {:event, event})

  @spec handle_info(term(), Socket.t()) :: event_result()
  def handle_info({:surface_state, :p2p, pid, snapshot}, socket) when is_map(snapshot) do
    {:halt, P2PReadModel.merge(socket, pid, snapshot)}
  end

  def handle_info({:surface_state, :p2p, _pid, nil}, socket), do: {:halt, socket}

  def handle_info({:surface_notice, :p2p, :error, message}, socket) do
    {:halt, Messages.error_event(socket, message)}
  end

  def handle_info({:surface_notice, :p2p, :system, message}, socket) do
    {:halt, Messages.system_event(socket, message)}
  end

  def handle_info({:surface_focus, :p2p}, socket) do
    {:halt, Windows.open(socket, @window_id)}
  end

  def handle_info({:surface_geometry, :p2p, geometry}, socket) do
    {:halt,
     Phoenix.LiveView.push_event(
       socket,
       "window_command",
       Map.put(geometry, :id, @window_id)
     )}
  end

  # The surface is gone. If the reason it went was a swap, the invite that was
  # waiting for it is delivered now and not a moment earlier — delivering
  # before the old session had actually ended would race the two.
  def handle_info({:surface_closed, :p2p}, socket) do
    socket =
      socket
      |> P2PReadModel.close()
      |> Phoenix.LiveView.push_event("window_command", %{action: "close", id: @window_id})

    case socket.assigns[:p2p_pending] do
      %{kind: :outgoing, payload: payload} ->
        {:halt,
         socket
         |> assign(p2p_pending: nil)
         |> LobbyInvite.deliver_invite(socket.assigns.session, payload)}

      %{kind: :incoming, token: token} ->
        {:halt, socket |> assign(p2p_pending: nil) |> accept(token)}

      _none ->
        {:halt, socket}
    end
  end

  # The session's own topic, and only its ending: everything that happens
  # inside is the surface's, and the surface is what says it. What the chat
  # needs is to stop drawing a badge and an invite row for something over.
  def handle_info(%{event: "lobby_" <> _rest, token: token} = msg, socket) do
    {:halt, apply_lifecycle(msg, socket, token)}
  end

  def handle_info(%{event: "lobby_" <> _rest}, socket), do: {:halt, socket}

  def handle_info(_message, socket), do: {:cont, socket}

  defp apply_lifecycle(
         %{event: "lobby_status_changed", payload: %{status: status}},
         socket,
         token
       ) do
    if LobbySession.terminal?(status), do: forget(socket, token), else: socket
  end

  defp apply_lifecycle(%{event: "lobby_session_closed"}, socket, token), do: forget(socket, token)
  defp apply_lifecycle(_message, socket, _token), do: socket

  defp forget(socket, token) do
    peer_nick = peer_nick_of(socket, token)

    socket
    |> P2PReadModel.drop_pm_by_token(token)
    |> PMHelper.refresh_p2p_invite_row(peer_nick, token)
    # A session that ended is a card that has to say so. The link outlives the
    # room by design — the card it draws is the record that the room happened.
    |> ShareCards.refresh()
  end

  defp peer_nick_of(%{assigns: %{p2p_session: %{token: token, peer_nick: peer_nick}}}, token),
    do: peer_nick

  defp peer_nick_of(socket, token) do
    socket
    |> P2PReadModel.pm_sessions()
    |> Enum.find_value(fn
      {_key, %{token: ^token, peer_nick: peer_nick}} -> peer_nick
      _other -> nil
    end)
  end

  @doc """
  Accept an invite from a PM card.

  With a session already active this stashes the target and opens the switch
  confirm instead: one session at a time, and the new one is validated as still
  joinable before the current one is ended.
  """
  @spec request_accept(Socket.t(), String.t()) :: Socket.t()
  def request_accept(socket, token) do
    case socket.assigns[:p2p_session] do
      nil ->
        accept(socket, token)

      p2p ->
        case joinable_summary(token) do
          {:ok, summary} ->
            open_switch_confirm(socket, p2p.peer_nick, summary.created_by)
            assign(socket, p2p_pending: %{kind: :incoming, token: token})

          {:error, message} ->
            Messages.system_event(socket, message)
        end
    end
  end

  # Accepting is consent, and consent is what opens the surface: the seat, the
  # devices and the readiness all belong to the room behind this click.
  defp accept(socket, token) do
    nickname = socket.assigns.session.nickname

    with {:ok, user_id} <- SessionHelpers.resolve_user_id(nickname),
         {:ok, _summary} <- joinable_summary(token) do
      socket
      |> P2PReadModel.open(token, user_id, :peer, "lobby")
      |> Windows.open(@window_id)
      |> Messages.system_event(dgettext("chat", "P2P request accepted - connecting..."))
    else
      {:error, message} -> Messages.system_event(socket, message)
      _unregistered -> socket
    end
  end

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

  # Validate the NEW session is still joinable BEFORE ending the current one,
  # so a stale confirm cannot cost the person both. The surface is what ends
  # the session it holds, and its closing is what continues the switch.
  defp confirm_switch(%{assigns: %{p2p_pending: %{kind: :incoming, token: token}}} = socket) do
    case joinable_summary(token) do
      {:ok, _summary} ->
        command(socket, {:event, "p2p_confirm_end"})

      {:error, message} ->
        socket
        |> assign(p2p_pending: nil)
        |> Messages.system_event(message)
    end
  end

  defp confirm_switch(%{assigns: %{p2p_pending: %{kind: :outgoing}}} = socket) do
    command(socket, {:event, "p2p_confirm_end"})
  end

  defp confirm_switch(socket), do: assign(socket, p2p_pending: nil)

  @doc """
  Ask about swapping the session in progress for `new_peer`'s.

  Public because the invite helper reaches the same question from the other
  direction — an outgoing invite while a session is up.
  """
  @spec open_switch_confirm(Socket.t(), String.t() | nil, String.t() | nil) :: :ok
  def open_switch_confirm(_socket, peer, new_peer) do
    Phoenix.LiveView.send_update(P2PConfirmDialog,
      id: @confirm_id,
      action: {:open_switch, peer, new_peer}
    )

    :ok
  end

  defp close_confirm do
    Phoenix.LiveView.send_update(P2PConfirmDialog, id: @confirm_id, action: :close)
  end

  defp command(%{assigns: %{p2p_session: %{pid: pid}}} = socket, message) when is_pid(pid) do
    send(pid, {:p2p_surface_command, message})
    socket
  end

  defp command(socket, _message), do: socket

  defp joinable_summary(token) do
    case Lobby.session_summary(token) do
      {:ok, %{terminal?: false} = summary} ->
        {:ok, summary}

      _gone ->
        {:error, dgettext("chat", "This P2P invite is no longer active.")}
    end
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
