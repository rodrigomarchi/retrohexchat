defmodule RetroHexChatWeb.ChatLive.PubsubHandlers.Membership do
  @moduledoc """
  PubSub handlers for membership changes: user joined/left, nick changes,
  force disconnect/rename, and NickServ identification.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3]

  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [
      system_event: 2,
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
  alias RetroHexChatWeb.ChatLive.Helpers.PathHelpers
  alias RetroHexChatWeb.ChatLive.Helpers.PM

  # ── User joined/left/nick_changed ─────────────────────────

  def handle_info({:user_joined, %{nickname: nick} = payload}, socket) do
    msg = gettext("%{nickname} has joined the channel", nickname: nick)
    role = Map.get(payload, :role, :regular)
    channel = Map.get(payload, :channel)
    user = %{nickname: nick, role: role, away: false}

    socket =
      socket
      |> increment_channel_user_count(channel)
      |> maybe_refresh_cc(channel)

    if active_channel?(socket, channel) do
      users = upsert_channel_user(socket.assigns.channel_users, user)

      {:halt,
       socket
       |> assign(channel_users: users)
       |> play_event_sound(:join, socket.assigns.session)
       |> system_event(msg)
       |> maybe_fire_autorespond(
         :on_join,
         channel,
         nick,
         &CommandDispatch.dispatch_command/4
       )}
    else
      {:halt, socket}
    end
  end

  def handle_info({:user_left, %{nickname: nick, reason: reason} = payload}, socket) do
    msg =
      if reason do
        gettext("%{nickname} has left (%{reason})", nickname: nick, reason: reason)
      else
        gettext("%{nickname} has left", nickname: nick)
      end

    channel = Map.get(payload, :channel)

    socket =
      socket
      |> decrement_channel_user_count(channel)
      |> maybe_refresh_cc(channel)

    if active_channel?(socket, channel) do
      users = Enum.reject(socket.assigns.channel_users, &same_nick?(&1.nickname, nick))

      socket =
        socket
        |> assign(channel_users: users)
        |> play_event_sound(:part, socket.assigns.session)
        |> system_event(msg)

      socket =
        if reason == "Changing nickname" do
          socket
        else
          maybe_fire_autorespond(
            socket,
            :on_part,
            channel,
            nick,
            &CommandDispatch.dispatch_command/4
          )
        end

      {:halt, socket}
    else
      {:halt, socket}
    end
  end

  def handle_info({:nick_changed, %{old_nick: old_nick, new_nick: new_nick} = payload}, socket) do
    channel = Map.get(payload, :channel, socket.assigns.session.active_channel)

    msg =
      gettext("%{old_nick} is now known as %{new_nick}", old_nick: old_nick, new_nick: new_nick)

    socket =
      if NotifyList.tracking?(socket.assigns.session.notify_list, old_nick) do
        session = socket.assigns.session
        updated_list = NotifyList.update_nickname(session.notify_list, old_nick, new_nick)
        new_session = Session.set_notify_list(session, updated_list)

        socket
        |> assign(session: new_session)
        |> maybe_persist_notify_list(new_session)
        |> push_status_message(
          gettext("* Your notify list buddy %{old_nick} is now known as %{new_nick}",
            old_nick: old_nick,
            new_nick: new_nick
          ),
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

    socket = rename_pm_state(socket, old_nick, new_nick)

    # Dismiss nick hover card if it's showing the old nick (T023)
    socket =
      if socket.assigns.hover_card.nick == old_nick do
        socket
        |> assign(hover_card: HoverEvents.default_hover_card())
        |> push_event("dismiss_hover_card", %{})
      else
        socket
      end

    if active_channel?(socket, channel) do
      users =
        Enum.map(socket.assigns.channel_users, fn user ->
          rename_channel_user(user, old_nick, new_nick)
        end)

      {:halt,
       socket
       |> assign(channel_users: users)
       |> system_event(msg)
       |> maybe_fire_autorespond(
         :on_nick_change,
         channel,
         new_nick,
         &CommandDispatch.dispatch_command/4
       )}
    else
      {:halt, socket}
    end
  end

  def handle_info(
        {:user_away_changed, %{nickname: nick, away: away, away_message: message} = payload},
        socket
      ) do
    channel = Map.get(payload, :channel)

    if active_channel?(socket, channel) do
      users =
        Enum.map(socket.assigns.channel_users, fn user ->
          update_channel_user_away(user, nick, away, message)
        end)

      {:halt,
       socket
       |> assign(channel_users: users)
       |> maybe_update_hover_away(nick, away, message)}
    else
      {:halt, socket}
    end
  end

  # ── Force disconnect/rename ───────────────────────────────

  def handle_info({:force_disconnect, %{reason: reason} = payload}, socket) do
    cleanup_channels(socket.assigns.session)
    maybe_ack_force_disconnect(payload)

    {:halt,
     socket
     |> assign(skip_channel_cleanup: true)
     |> push_event("intentional_disconnect", %{})
     |> push_event("clear_client_state", %{})
     |> Phoenix.LiveView.redirect(to: PathHelpers.session_clear_path(socket, reason))}
  end

  def handle_info({:force_rename, %{reason: reason}}, socket) do
    old_nickname = socket.assigns.session.nickname
    guest_nick = "Guest_#{:rand.uniform(99999)}"

    session =
      socket.assigns.session
      |> Session.update_nickname(guest_nick)
      |> Session.set_identified(false)

    Phoenix.PubSub.unsubscribe(RetroHexChat.PubSub, "user:#{old_nickname}")
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "user:#{guest_nick}")

    msg =
      gettext("[NickServ] %{reason}. You are now %{nickname}",
        reason: reason,
        nickname: guest_nick
      )

    {:halt,
     socket
     |> assign(session: session)
     |> system_event(msg)}
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
       |> push_status_message(
         gettext("You are now identified as %{nickname}", nickname: nick),
         :system
       )}
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

  defp increment_channel_user_count(socket, nil), do: socket

  defp increment_channel_user_count(socket, channel) do
    counts = socket.assigns.channel_user_counts
    current = Map.get(counts, channel, 0)
    assign(socket, channel_user_counts: Map.put(counts, channel, current + 1))
  end

  defp decrement_channel_user_count(socket, nil), do: socket

  defp decrement_channel_user_count(socket, channel) do
    counts = socket.assigns.channel_user_counts
    current = Map.get(counts, channel, 0)
    assign(socket, channel_user_counts: Map.put(counts, channel, max(current - 1, 0)))
  end

  defp active_channel?(_socket, nil), do: true

  defp active_channel?(socket, channel) do
    socket.assigns.session.active_channel == channel
  end

  defp upsert_channel_user(users, user) do
    users
    |> Enum.reject(&same_nick?(&1.nickname, user.nickname))
    |> then(&[user | &1])
  end

  defp same_nick?(left, right) do
    String.downcase(left) == String.downcase(right)
  end

  defp rename_channel_user(user, old_nick, new_nick) do
    if same_nick?(user.nickname, old_nick), do: %{user | nickname: new_nick}, else: user
  end

  defp update_channel_user_away(user, nick, away, message) do
    if same_nick?(user.nickname, nick) do
      Map.merge(user, %{away: away, away_message: message})
    else
      user
    end
  end

  defp rename_pm_state(socket, old_nick, new_nick) do
    session = socket.assigns.session

    if old_nick in session.pm_conversations or session.active_pm == old_nick do
      Phoenix.PubSub.unsubscribe(
        RetroHexChat.PubSub,
        "pm:#{PM.pm_topic(session.nickname, old_nick)}"
      )

      PM.ensure_pm_subscription(session.nickname, new_nick)
    end

    old_pm_key = "pm:#{old_nick}"
    new_pm_key = "pm:#{new_nick}"

    socket
    |> assign(
      session: Session.rename_pm_conversation(session, old_nick, new_nick),
      unread_counts: rename_count_key(socket.assigns.unread_counts, old_pm_key, new_pm_key),
      flash_channels: rename_set_key(socket.assigns.flash_channels, old_pm_key, new_pm_key),
      muted_channels: rename_set_key(socket.assigns.muted_channels, old_pm_key, new_pm_key),
      away_replied_to: rename_set_key(socket.assigns.away_replied_to, old_nick, new_nick),
      pm_typing_from: rename_optional_value(socket.assigns.pm_typing_from, old_nick, new_nick)
    )
  end

  defp rename_count_key(counts, old_key, new_key) do
    case Map.pop(counts, old_key) do
      {nil, updated_counts} ->
        updated_counts

      {count, updated_counts} ->
        Map.update(updated_counts, new_key, count, &(&1 + count))
    end
  end

  defp rename_set_key(set, old_key, new_key) do
    if MapSet.member?(set, old_key) do
      set
      |> MapSet.delete(old_key)
      |> MapSet.put(new_key)
    else
      set
    end
  end

  defp rename_optional_value(value, old_nick, new_nick) when value == old_nick, do: new_nick
  defp rename_optional_value(value, _old_nick, _new_nick), do: value

  defp maybe_update_hover_away(socket, nick, away, message) do
    case socket.assigns.hover_card do
      %{visible: true, nick: hover_nick} = card ->
        if String.downcase(hover_nick) == String.downcase(nick) do
          data = Map.get(card, :data) || %{}

          assign(socket,
            hover_card:
              Map.merge(card, %{
                away: if(away, do: message || gettext("Away")),
                data: Map.merge(data, %{away: away, away_message: message})
              })
          )
        else
          socket
        end

      _ ->
        socket
    end
  end

  defp maybe_ack_force_disconnect(%{takeover_ack: {pid, ref}}) when is_pid(pid) do
    send(pid, {:force_disconnect_ack, ref})
    :ok
  end

  defp maybe_ack_force_disconnect(_payload), do: :ok

  defp cleanup_channels(session) do
    NickServ.cancel_identify_timer(session.nickname)

    Enum.each(session.channels, fn channel ->
      try do
        Tracker.untrack_user("channel:#{channel}", session.nickname)
        Server.part(channel, session.nickname, gettext("Connection lost"))
      rescue
        e ->
          require Logger
          Logger.warning("Failed to part #{channel} during cleanup: #{inspect(e)}")
          :ok
      end
    end)
  end
end
