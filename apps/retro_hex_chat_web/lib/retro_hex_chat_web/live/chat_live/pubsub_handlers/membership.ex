defmodule RetroHexChatWeb.ChatLive.PubsubHandlers.Membership do
  @moduledoc """
  PubSub handlers for membership changes: user joined/left, nick changes,
  force disconnect/rename, and NickServ identification.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3, push_navigate: 2, stream_insert: 3]

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [
      system_message: 1,
      push_status_message: 3,
      play_event_sound: 3,
      maybe_fire_autorespond: 5,
      maybe_persist_notify_list: 2,
      rebuild_nick_color_fn: 2,
      load_persisted_data: 2
    ]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Chat.IgnoreList
  alias RetroHexChat.Presence.{NotifyList, Tracker}
  alias RetroHexChat.Services.NickServ
  alias RetroHexChatWeb.ChatLive.{CommandDispatch, HoverEvents}

  # ── User joined/left/nick_changed ─────────────────────────

  def handle_info({:user_joined, %{nickname: nick} = payload}, socket) do
    msg = "#{nick} has joined the channel"
    role = Map.get(payload, :role, :regular)
    channel = Map.get(payload, :channel)
    user = %{nickname: nick, role: role, away: false}
    users = [user | socket.assigns.channel_users]

    {:halt,
     socket
     |> assign(channel_users: users)
     |> maybe_refresh_cc(channel)
     |> play_event_sound(:join, socket.assigns.session)
     |> stream_insert(:chat_messages, system_message(msg))
     |> maybe_fire_autorespond(
       :on_join,
       channel,
       nick,
       &CommandDispatch.dispatch_command/4
     )}
  end

  def handle_info({:user_left, %{nickname: nick, reason: reason} = payload}, socket) do
    msg = "#{nick} has left" <> if(reason, do: " (#{reason})", else: "")
    channel = Map.get(payload, :channel)
    users = Enum.reject(socket.assigns.channel_users, &(&1.nickname == nick))

    {:halt,
     socket
     |> assign(channel_users: users)
     |> maybe_refresh_cc(channel)
     |> play_event_sound(:part, socket.assigns.session)
     |> stream_insert(:chat_messages, system_message(msg))
     |> maybe_fire_autorespond(
       :on_part,
       channel,
       nick,
       &CommandDispatch.dispatch_command/4
     )}
  end

  def handle_info({:nick_changed, %{old_nick: old_nick, new_nick: new_nick}}, socket) do
    users =
      Enum.map(socket.assigns.channel_users, fn user ->
        if user.nickname == old_nick, do: %{user | nickname: new_nick}, else: user
      end)

    msg = "#{old_nick} is now known as #{new_nick}"

    socket =
      if NotifyList.tracking?(socket.assigns.session.notify_list, old_nick) do
        session = socket.assigns.session
        updated_list = NotifyList.update_nickname(session.notify_list, old_nick, new_nick)
        new_session = Session.set_notify_list(session, updated_list)

        socket
        |> assign(session: new_session)
        |> maybe_persist_notify_list(new_session)
        |> push_status_message(
          "* Your notify list buddy #{old_nick} is now known as #{new_nick}",
          :notify_rename
        )
      else
        socket
      end

    socket =
      if IgnoreList.get_entry(socket.assigns.session.ignore_list, old_nick) do
        session = socket.assigns.session
        updated_list = IgnoreList.update_nickname(session.ignore_list, old_nick, new_nick)
        new_session = Session.set_ignore_list(session, updated_list)
        assign(socket, session: new_session)
      else
        socket
      end

    # Dismiss nick hover card if it's showing the old nick (T023)
    socket =
      if socket.assigns.hover_card.nick == old_nick do
        socket
        |> assign(hover_card: HoverEvents.default_hover_card())
        |> push_event("dismiss_hover_card", %{})
      else
        socket
      end

    {:halt,
     socket
     |> assign(channel_users: users)
     |> stream_insert(:chat_messages, system_message(msg))
     |> maybe_fire_autorespond(
       :on_nick_change,
       socket.assigns.session.active_channel,
       new_nick,
       &CommandDispatch.dispatch_command/4
     )}
  end

  # ── Force disconnect/rename ───────────────────────────────

  def handle_info({:force_disconnect, %{reason: reason}}, socket) do
    cleanup_channels(socket.assigns.session)

    {:halt,
     socket
     |> Phoenix.LiveView.put_flash(:error, "Disconnected: #{reason}")
     |> push_navigate(to: ~p"/")}
  end

  def handle_info({:force_rename, %{reason: reason}}, socket) do
    old_nickname = socket.assigns.session.nickname
    guest_nick = "Guest_#{:rand.uniform(99999)}"
    session = Session.update_nickname(socket.assigns.session, guest_nick)

    Phoenix.PubSub.unsubscribe(RetroHexChat.PubSub, "user:#{old_nickname}")
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "user:#{guest_nick}")

    msg = "[NickServ] #{reason}. You are now #{guest_nick}"

    {:halt,
     socket
     |> assign(session: session)
     |> stream_insert(:chat_messages, system_message(msg))}
  end

  # ── NickServ identified ───────────────────────────────────

  def handle_info({:nickserv_identified, %{nickname: nick}}, socket) do
    session = socket.assigns.session

    if nick == session.nickname do
      new_session =
        session
        |> Session.set_identified(true)
        |> load_persisted_data(nick)

      {:halt,
       socket
       |> assign(session: new_session)
       |> rebuild_nick_color_fn(new_session)
       |> push_status_message("You are now identified as #{nick}", :system)}
    else
      {:halt, socket}
    end
  end

  # ── Catch-all: pass unhandled to next hook ────────────────

  def handle_info(_, socket), do: {:cont, socket}

  # ── Private helpers ───────────────────────────────────────

  defp maybe_refresh_cc(socket, channel) do
    if socket.assigns.show_channel_central and socket.assigns.channel_central_channel == channel do
      case Server.get_state(channel) do
        {:ok, state} ->
          nickname = socket.assigns.session.nickname

          operator =
            nickname in state.operators or nickname in Map.get(state, :owners, [])

          assign(socket, channel_central_state: state, channel_central_operator: operator)

        {:error, _} ->
          assign(socket,
            show_channel_central: false,
            channel_central_tab: "general",
            channel_central_channel: nil,
            channel_central_state: nil,
            channel_central_operator: false,
            channel_central_ban_selected: nil,
            channel_central_ban_ex_selected: nil,
            channel_central_invite_ex_selected: nil,
            channel_central_modes_form: %{},
            show_cc_add_ban_dialog: false,
            show_cc_add_ban_ex_dialog: false,
            show_cc_add_invite_ex_dialog: false
          )
      end
    else
      socket
    end
  end

  defp cleanup_channels(session) do
    NickServ.cancel_identify_timer(session.nickname)

    Enum.each(session.channels, fn channel ->
      try do
        Tracker.untrack_user("channel:#{channel}", session.nickname)
        Server.part(channel, session.nickname, "Connection lost")
      rescue
        e ->
          require Logger
          Logger.warning("Failed to part #{channel} during cleanup: #{inspect(e)}")
          :ok
      end
    end)
  end
end
