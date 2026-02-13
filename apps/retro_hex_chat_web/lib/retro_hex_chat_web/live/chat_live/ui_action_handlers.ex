defmodule RetroHexChatWeb.ChatLive.UiActionHandlers do
  @moduledoc """
  Handle all ui_action dispatch results from command execution.

  Contains ~50 handle_ui_action/3 clauses covering: query, channel_list, clear_chat,
  away, topic, whois, help, set_mode, kick/ban, notify CRUD, ignore CRUD,
  perform CRUD, alias CRUD, custom menus, autorespond CRUD, timer management,
  autojoin CRUD, invite, notice routing, whowas, bio management.

  NOT a hook module — public function called by CommandDispatch.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_navigate: 2, stream: 4, stream_insert: 3]

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [
      system_message: 1,
      error_message: 1,
      push_status_message: 3,
      open_pm_conversation: 2,
      show_whois_text: 2,
      show_whowas_text: 2,
      maybe_persist_notify_list: 2,
      maybe_persist_ignore_list: 2,
      maybe_persist_perform_list: 2,
      maybe_persist_autojoin_list: 2,
      maybe_persist_aliases: 2,
      maybe_persist_autorespond_rules: 2,
      cancel_ignore_timer: 2,
      maybe_start_ignore_timer: 3,
      cancel_auto_ignore_with_cooldown: 2,
      safe_update_away: 4,
      safe_update_bio: 3
    ]

  alias RetroHexChat.Accounts.Session

  alias RetroHexChat.Chat.{
    AliasList,
    AutoJoinList,
    AutoRespondRules,
    IgnoreList,
    NoticeRouting,
    PerformList,
    TimerManager,
    UserBio
  }

  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Presence.NotifyList

  require Logger

  @spec handle_ui_action(Phoenix.LiveView.Socket.t(), atom(), map()) ::
          Phoenix.LiveView.Socket.t()

  def handle_ui_action(socket, :open_query, %{nickname: target}),
    do: open_pm_conversation(socket, target)

  def handle_ui_action(socket, :open_channel_list, _),
    do: push_navigate(socket, to: ~p"/channels")

  def handle_ui_action(socket, :clear_chat, _),
    do: stream(socket, :chat_messages, [], reset: true)

  def handle_ui_action(socket, :set_away, %{message: message}),
    do: handle_set_away(socket, message)

  def handle_ui_action(socket, :clear_away, _),
    do: handle_clear_away(socket)

  def handle_ui_action(socket, :set_topic, %{channel: channel, topic: topic}),
    do: handle_set_topic(socket, channel, topic)

  def handle_ui_action(socket, :view_topic, %{channel: channel}),
    do: handle_view_topic(socket, channel)

  def handle_ui_action(socket, :show_whois_info, %{nickname: target}),
    do: show_whois_text(socket, target)

  def handle_ui_action(socket, :show_help, %{commands: commands}),
    do: show_help_message(socket, commands)

  def handle_ui_action(socket, :show_command_help, %{help: help}),
    do: show_command_help_message(socket, help)

  def handle_ui_action(socket, :set_mode, %{
        channel: channel,
        mode_string: mode_string,
        params: params
      }) do
    case Server.set_mode(channel, socket.assigns.session.nickname, mode_string, params) do
      :ok -> socket
      {:error, msg} -> stream_insert(socket, :chat_messages, error_message(msg))
    end
  end

  def handle_ui_action(socket, :kick_user, %{
        channel: channel,
        reason: reason,
        target: target
      }) do
    case Server.kick(channel, socket.assigns.session.nickname, target, reason) do
      :ok -> socket
      {:error, msg} -> stream_insert(socket, :chat_messages, error_message(msg))
    end
  end

  def handle_ui_action(socket, :ban_user, %{
        channel: channel,
        reason: reason,
        target: target
      }) do
    case Server.ban(channel, socket.assigns.session.nickname, target, reason) do
      :ok -> socket
      {:error, msg} -> stream_insert(socket, :chat_messages, error_message(msg))
    end
  end

  # ── Notify list UI actions ────────────────────────────────

  def handle_ui_action(socket, :open_notify_list, _payload) do
    assign(socket, show_notify_list: true)
  end

  def handle_ui_action(socket, :notify_add, %{nickname: nick, note: note}) do
    session = socket.assigns.session

    case NotifyList.add_entry(session.notify_list, session.nickname, nick, note) do
      {:ok, updated_list} ->
        new_session = Session.set_notify_list(session, updated_list)

        socket
        |> assign(session: new_session)
        |> maybe_persist_notify_list(new_session)
        |> push_status_message("Added #{nick} to notify list", :system)

      {:error, :self_add} ->
        push_status_message(socket, "Cannot add yourself to the notify list", :system)

      {:error, :duplicate} ->
        push_status_message(socket, "#{nick} is already in your notify list", :system)

      {:error, :list_full} ->
        push_status_message(socket, "Notify list is full (max 50 entries)", :system)
    end
  end

  def handle_ui_action(socket, :notify_remove, %{nickname: nick}) do
    session = socket.assigns.session

    case NotifyList.remove_entry(session.notify_list, nick) do
      {:ok, updated_list} ->
        new_session = Session.set_notify_list(session, updated_list)

        socket
        |> assign(session: new_session)
        |> maybe_persist_notify_list(new_session)
        |> push_status_message("Removed #{nick} from notify list", :system)

      {:error, :not_found} ->
        push_status_message(socket, "#{nick} is not in your notify list", :system)
    end
  end

  def handle_ui_action(socket, :notify_edit, %{nickname: nick, note: note}) do
    session = socket.assigns.session

    case NotifyList.update_note(session.notify_list, nick, note) do
      {:ok, updated_list} ->
        new_session = Session.set_notify_list(session, updated_list)

        socket
        |> assign(session: new_session)
        |> maybe_persist_notify_list(new_session)
        |> push_status_message("Updated note for #{nick}", :system)

      {:error, :not_found} ->
        push_status_message(socket, "#{nick} is not in your notify list", :system)
    end
  end

  def handle_ui_action(socket, :notify_list_display, _payload) do
    session = socket.assigns.session
    entries = NotifyList.sorted_entries(session.notify_list)

    if entries == [] do
      push_status_message(socket, "Your notify list is empty", :system)
    else
      Enum.reduce(entries, socket, fn entry, acc ->
        push_status_message(acc, format_notify_entry(entry), :system)
      end)
    end
  end

  # ── Ignore list UI actions ────────────────────────────────

  def handle_ui_action(socket, :ignore_list, _payload) do
    session = socket.assigns.session
    entries = IgnoreList.sorted_entries(session.ignore_list)

    if entries == [] do
      stream_insert(socket, :chat_messages, system_message("Your ignore list is empty"))
    else
      Enum.reduce(entries, socket, fn entry, acc ->
        stream_insert(acc, :chat_messages, system_message(format_ignore_entry(entry)))
      end)
    end
  end

  def handle_ui_action(socket, :ignore_add, %{nickname: nick, type: type} = payload) do
    session = socket.assigns.session
    duration = Map.get(payload, :duration)
    expires_at = if duration, do: DateTime.add(DateTime.utc_now(), duration, :second)
    existing = IgnoreList.get_entry(session.ignore_list, nick)

    case IgnoreList.add_entry(session.ignore_list, nick, type, expires_at) do
      {:ok, updated_list} ->
        new_session = Session.set_ignore_list(session, updated_list)

        msg =
          if existing do
            "* #{nick} ignore updated to: #{type}"
          else
            "* #{nick} is now ignored (#{type})"
          end

        socket
        |> assign(session: new_session)
        |> cancel_ignore_timer(nick)
        |> maybe_start_ignore_timer(nick, duration)
        |> maybe_persist_ignore_list(new_session)
        |> stream_insert(:chat_messages, system_message(msg))

      {:error, :list_full} ->
        stream_insert(
          socket,
          :chat_messages,
          error_message("Ignore list is full (max 100 entries)")
        )

      {:error, :invalid_type} ->
        stream_insert(socket, :chat_messages, error_message("Invalid ignore type: #{type}"))
    end
  end

  def handle_ui_action(socket, :ignore_remove, %{nickname: nick}) do
    session = socket.assigns.session

    case IgnoreList.remove_entry(session.ignore_list, nick) do
      {:ok, updated_list} ->
        new_session = Session.set_ignore_list(session, updated_list)

        socket
        |> assign(session: new_session)
        |> cancel_ignore_timer(nick)
        |> cancel_auto_ignore_with_cooldown(nick)
        |> maybe_persist_ignore_list(new_session)
        |> stream_insert(:chat_messages, system_message("* #{nick} is no longer ignored"))

      {:error, :not_found} ->
        stream_insert(
          socket,
          :chat_messages,
          error_message("#{nick} is not in your ignore list")
        )
    end
  end

  # ── Perform list UI actions ───────────────────────────────

  def handle_ui_action(socket, :open_perform_dialog, payload) do
    tab = Map.get(payload, :tab, "commands")
    assign(socket, show_perform_dialog: true, perform_dialog_tab: tab)
  end

  def handle_ui_action(socket, :perform_list_display, _payload) do
    session = socket.assigns.session
    entries = PerformList.entries(session.perform_list)

    if entries == [] do
      stream_insert(socket, :chat_messages, system_message("Your perform list is empty"))
    else
      Enum.with_index(entries)
      |> Enum.reduce(socket, fn {entry, idx}, acc ->
        masked = PerformList.mask_command(entry.command)
        stream_insert(acc, :chat_messages, system_message("  #{idx}: #{masked}"))
      end)
    end
  end

  def handle_ui_action(socket, :perform_add, %{command: command}) do
    session = socket.assigns.session

    case PerformList.add_entry(session.perform_list, command) do
      {:ok, updated_list} ->
        new_session = Session.set_perform_list(session, updated_list)
        masked = PerformList.mask_command(String.trim(command))

        socket
        |> assign(session: new_session)
        |> maybe_persist_perform_list(new_session)
        |> stream_insert(:chat_messages, system_message("* Added to perform list: #{masked}"))

      {:error, :invalid_command} ->
        stream_insert(
          socket,
          :chat_messages,
          error_message("Invalid command. Commands must start with /")
        )

      {:error, :disallowed_command} ->
        stream_insert(
          socket,
          :chat_messages,
          error_message("That command cannot be added to the perform list")
        )

      {:error, :command_too_long} ->
        stream_insert(
          socket,
          :chat_messages,
          error_message("Command too long (max 500 characters)")
        )

      {:error, :list_full} ->
        stream_insert(
          socket,
          :chat_messages,
          error_message("Perform list is full (max 50 commands)")
        )
    end
  end

  def handle_ui_action(socket, :perform_remove, %{position: position}) do
    session = socket.assigns.session

    case PerformList.remove_entry(session.perform_list, position) do
      {:ok, updated_list} ->
        new_session = Session.set_perform_list(session, updated_list)

        socket
        |> assign(session: new_session)
        |> maybe_persist_perform_list(new_session)
        |> stream_insert(
          :chat_messages,
          system_message("* Removed command at position #{position}")
        )

      {:error, :not_found} ->
        stream_insert(
          socket,
          :chat_messages,
          error_message("No command at position #{position}")
        )
    end
  end

  def handle_ui_action(socket, :perform_move, %{from: from, to: to}) do
    session = socket.assigns.session

    case PerformList.move_entry(session.perform_list, from, to) do
      {:ok, updated_list} ->
        new_session = Session.set_perform_list(session, updated_list)

        socket
        |> assign(session: new_session)
        |> maybe_persist_perform_list(new_session)
        |> stream_insert(
          :chat_messages,
          system_message("* Moved command from position #{from} to #{to}")
        )

      {:error, :same_position} ->
        stream_insert(
          socket,
          :chat_messages,
          error_message("Source and destination are the same")
        )

      {:error, :invalid_position} ->
        stream_insert(socket, :chat_messages, error_message("Invalid position"))
    end
  end

  def handle_ui_action(socket, :perform_clear, _payload) do
    session = socket.assigns.session
    {:ok, updated_list} = PerformList.clear(session.perform_list)
    new_session = Session.set_perform_list(session, updated_list)

    socket
    |> assign(session: new_session)
    |> maybe_persist_perform_list(new_session)
    |> stream_insert(:chat_messages, system_message("* Perform list cleared"))
  end

  # ── Alias UI actions ──────────────────────────────────────

  def handle_ui_action(socket, :open_alias_dialog, _payload) do
    assign(socket, show_alias_dialog: true)
  end

  def handle_ui_action(socket, :alias_added, %{name: name, expansion: expansion}) do
    session = socket.assigns.session

    case AliasList.add_entry(session.aliases, name, expansion) do
      {:ok, updated_list} ->
        new_session = Session.set_aliases(session, updated_list)

        warning =
          if AliasList.shadows_builtin?(name), do: " (warning: shadows built-in /#{name})"

        socket
        |> assign(session: new_session)
        |> maybe_persist_aliases(new_session)
        |> stream_insert(
          :chat_messages,
          system_message("* Alias /#{name} created#{warning || ""}")
        )

      {:error, :duplicate_name} ->
        stream_insert(socket, :chat_messages, error_message("Alias /#{name} already exists"))

      {:error, :invalid_name} ->
        stream_insert(
          socket,
          :chat_messages,
          error_message("Invalid alias name. Use only letters, numbers, hyphens, underscores.")
        )

      {:error, :expansion_too_long} ->
        stream_insert(
          socket,
          :chat_messages,
          error_message("Expansion too long (max 500 characters)")
        )

      {:error, :command_chaining} ->
        stream_insert(
          socket,
          :chat_messages,
          error_message("Expansion must not contain command chaining (|, &&, ;, newlines)")
        )

      {:error, :list_full} ->
        stream_insert(socket, :chat_messages, error_message("Alias list is full (max 50)"))
    end
  end

  def handle_ui_action(socket, :alias_removed, %{name: name}) do
    session = socket.assigns.session

    case AliasList.remove_entry(session.aliases, name) do
      {:ok, updated_list} ->
        new_session = Session.set_aliases(session, updated_list)

        socket
        |> assign(session: new_session)
        |> maybe_persist_aliases(new_session)
        |> stream_insert(:chat_messages, system_message("* Alias /#{name} removed"))

      {:error, :not_found} ->
        stream_insert(socket, :chat_messages, error_message("Alias /#{name} not found"))
    end
  end

  def handle_ui_action(socket, :alias_list_display, _payload) do
    session = socket.assigns.session
    entries = AliasList.entries(session.aliases)

    if entries == [] do
      stream_insert(socket, :chat_messages, system_message("Your alias list is empty"))
    else
      Enum.reduce(entries, socket, fn entry, acc ->
        stream_insert(
          acc,
          :chat_messages,
          system_message("  /#{entry.name} → #{entry.expansion}")
        )
      end)
    end
  end

  # ── Custom menus UI actions ───────────────────────────────

  def handle_ui_action(socket, :open_custom_menus_dialog, _payload) do
    assign(socket, show_custom_menus_dialog: true)
  end

  # ── Auto-respond UI actions ───────────────────────────────

  def handle_ui_action(socket, :open_autorespond_dialog, _payload) do
    assign(socket, show_autorespond_dialog: true)
  end

  def handle_ui_action(socket, :autorespond_added, %{
        trigger_event: trigger,
        channel_filter: channel,
        command: command
      }) do
    session = socket.assigns.session

    case AutoRespondRules.add_entry(session.autorespond_rules, trigger, channel, command) do
      {:ok, updated} ->
        new_session = Session.set_autorespond_rules(session, updated)

        socket
        |> assign(session: new_session)
        |> maybe_persist_autorespond_rules(new_session)
        |> stream_insert(
          :chat_messages,
          system_message("Auto-respond rule added: #{trigger} → #{command}")
        )

      {:error, reason} ->
        stream_insert(
          socket,
          :chat_messages,
          system_message("Error adding auto-respond rule: #{autorespond_error_msg(reason)}")
        )
    end
  end

  def handle_ui_action(socket, :autorespond_removed, %{position: position}) do
    session = socket.assigns.session

    case AutoRespondRules.remove_entry(session.autorespond_rules, position) do
      {:ok, updated} ->
        new_session = Session.set_autorespond_rules(session, updated)

        socket
        |> assign(session: new_session)
        |> maybe_persist_autorespond_rules(new_session)
        |> stream_insert(:chat_messages, system_message("Auto-respond rule removed."))

      {:error, :not_found} ->
        stream_insert(socket, :chat_messages, system_message("Auto-respond rule not found."))
    end
  end

  def handle_ui_action(socket, :autorespond_list_display, _payload) do
    session = socket.assigns.session
    entries = AutoRespondRules.entries(session.autorespond_rules)

    if entries == [] do
      stream_insert(
        socket,
        :chat_messages,
        system_message("No auto-respond rules configured.")
      )
    else
      lines = Enum.map(entries, &format_autorespond_entry/1)
      msg = ["Auto-respond rules:" | lines] |> Enum.join("\n")
      stream_insert(socket, :chat_messages, system_message(msg))
    end
  end

  # ── Timer UI actions ──────────────────────────────────────

  def handle_ui_action(socket, :timer_create, %{
        name: name,
        type: type,
        interval: interval,
        command: command
      }) do
    timers = socket.assigns.user_timers

    case TimerManager.validate_create(timers, name, type, interval, command) do
      :ok ->
        {clamped_interval, notice} = TimerManager.clamp_interval(type, interval)

        socket =
          case Map.get(timers, name) do
            %{ref: ref} ->
              Process.cancel_timer(ref)
              socket

            nil ->
              socket
          end

        ref = Process.send_after(self(), {:user_timer_fired, name}, clamped_interval * 1000)

        new_timers =
          Map.put(timers, name, %{
            type: type,
            interval: clamped_interval,
            command: command,
            ref: ref
          })

        socket = assign(socket, user_timers: new_timers)

        socket =
          if notice do
            stream_insert(socket, :chat_messages, system_message("* #{notice}"))
          else
            socket
          end

        type_label = if type == :repeat, do: "repeat", else: "one-shot"

        stream_insert(
          socket,
          :chat_messages,
          system_message(
            "* Timer '#{name}' set: #{type_label}, #{clamped_interval}s → #{command}"
          )
        )

      {:error, msg} ->
        stream_insert(socket, :chat_messages, error_message(msg))
    end
  end

  def handle_ui_action(socket, :timer_stop, %{name: name}) do
    timers = socket.assigns.user_timers

    case Map.get(timers, name) do
      %{ref: ref} ->
        Process.cancel_timer(ref)
        new_timers = Map.delete(timers, name)

        socket
        |> assign(user_timers: new_timers)
        |> stream_insert(:chat_messages, system_message("* Timer '#{name}' stopped"))

      nil ->
        stream_insert(socket, :chat_messages, error_message("Timer '#{name}' not found"))
    end
  end

  def handle_ui_action(socket, :timer_list, _payload) do
    text = TimerManager.format_timer_list(socket.assigns.user_timers)

    text
    |> String.split("\n")
    |> Enum.reduce(socket, fn line, acc ->
      stream_insert(acc, :chat_messages, system_message(line))
    end)
  end

  # ── Autojoin UI actions ───────────────────────────────────

  def handle_ui_action(socket, :autojoin_list_display, _payload) do
    session = socket.assigns.session
    entries = AutoJoinList.entries(session.autojoin_list)

    if entries == [] do
      stream_insert(socket, :chat_messages, system_message("Your auto-join list is empty"))
    else
      Enum.reduce(entries, socket, fn entry, acc ->
        stream_insert(acc, :chat_messages, system_message(format_autojoin_entry(entry)))
      end)
    end
  end

  def handle_ui_action(socket, :autojoin_add, %{channel: channel} = payload) do
    session = socket.assigns.session
    key = Map.get(payload, :key)

    case AutoJoinList.add_entry(session.autojoin_list, channel, key) do
      {:ok, updated_list} ->
        new_session = Session.set_autojoin_list(session, updated_list)

        socket
        |> assign(session: new_session)
        |> maybe_persist_autojoin_list(new_session)
        |> stream_insert(
          :chat_messages,
          system_message("* Added to auto-join list: #{channel}")
        )

      {:error, reason} ->
        stream_insert(
          socket,
          :chat_messages,
          error_message("Failed to add auto-join channel: #{reason}")
        )
    end
  end

  def handle_ui_action(socket, :autojoin_remove, %{channel: channel}) do
    session = socket.assigns.session

    case AutoJoinList.remove_entry(session.autojoin_list, channel) do
      {:ok, updated_list} ->
        new_session = Session.set_autojoin_list(session, updated_list)

        socket
        |> assign(session: new_session)
        |> maybe_persist_autojoin_list(new_session)
        |> stream_insert(
          :chat_messages,
          system_message("* Removed #{channel} from auto-join list")
        )

      {:error, :not_found} ->
        stream_insert(
          socket,
          :chat_messages,
          error_message("#{channel} is not in your auto-join list")
        )
    end
  end

  def handle_ui_action(socket, :autojoin_clear, _payload) do
    session = socket.assigns.session
    {:ok, updated_list} = AutoJoinList.clear(session.autojoin_list)
    new_session = Session.set_autojoin_list(session, updated_list)

    socket
    |> assign(session: new_session)
    |> maybe_persist_autojoin_list(new_session)
    |> stream_insert(:chat_messages, system_message("* Auto-join list cleared"))
  end

  # ── Invite UI actions ─────────────────────────────────────

  def handle_ui_action(socket, :send_invite, %{target: target, channel: channel}) do
    nickname = socket.assigns.session.nickname

    with {:ok, state} <- Server.get_state(channel),
         :ok <- validate_operator(nickname, state),
         :ok <- validate_invite_only(channel, state),
         :ok <- validate_target_not_in_channel(target, state),
         :ok <- validate_target_online(target) do
      Server.add_invite_exception(channel, nickname, target)

      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        "user:#{target}",
        {:channel_invite, %{channel: channel, inviter: nickname}}
      )

      stream_insert(
        socket,
        :chat_messages,
        system_message("* Inviting #{target} to #{channel}")
      )
    else
      {:error, msg} ->
        stream_insert(socket, :chat_messages, error_message(msg))
    end
  end

  def handle_ui_action(socket, :toggle_auto_join_on_invite, _payload) do
    session = socket.assigns.session
    new_session = Session.toggle_auto_join_on_invite(session)
    status = if new_session.auto_join_on_invite, do: "enabled", else: "disabled"

    socket
    |> assign(session: new_session)
    |> stream_insert(:chat_messages, system_message("* Auto-join on invite: #{status}"))
  end

  # ── Notice routing UI actions ─────────────────────────────

  def handle_ui_action(socket, :notice_routing_show, _payload) do
    session = socket.assigns.session
    routing = Session.get_notice_routing(session)

    stream_insert(
      socket,
      :chat_messages,
      system_message("* Notice routing is set to: #{routing}")
    )
  end

  def handle_ui_action(socket, :notice_routing_set, %{routing: routing}) do
    session = socket.assigns.session
    new_session = Session.set_notice_routing(session, routing)

    if new_session.identified do
      Task.start(fn ->
        NoticeRouting.save(new_session.nickname, %{routing: routing})
      end)
    end

    socket
    |> assign(session: new_session)
    |> stream_insert(
      :chat_messages,
      system_message("* Notice routing set to: #{routing}")
    )
  end

  # ── Whowas UI action ─────────────────────────────────────

  def handle_ui_action(socket, :show_whowas_info, %{nickname: target}),
    do: show_whowas_text(socket, target)

  # ── Bio UI actions ────────────────────────────────────────

  def handle_ui_action(socket, :set_bio, %{text: text, truncated: truncated}) do
    session = socket.assigns.session
    new_session = Session.set_bio(session, text)

    if session.identified do
      UserBio.save(session.nickname, text)
    end

    Enum.each(session.channels, fn channel ->
      safe_update_bio("channel:#{channel}", session.nickname, text)
    end)

    msg =
      if truncated,
        do: "Bio truncated to 200 characters and set.",
        else: "Bio set: #{text}"

    socket
    |> assign(session: new_session)
    |> stream_insert(:chat_messages, system_message("* #{msg}"))
  end

  def handle_ui_action(socket, :view_bio, _payload) do
    session = socket.assigns.session

    msg =
      case Session.get_bio(session) do
        nil -> "No bio set. Use /bio <text> to set one."
        bio -> "Your bio: #{bio}"
      end

    stream_insert(socket, :chat_messages, system_message("* #{msg}"))
  end

  def handle_ui_action(socket, :clear_bio, _payload) do
    session = socket.assigns.session
    new_session = Session.set_bio(session, nil)

    if session.identified do
      UserBio.delete(session.nickname)
    end

    Enum.each(session.channels, fn channel ->
      safe_update_bio("channel:#{channel}", session.nickname, nil)
    end)

    socket
    |> assign(session: new_session)
    |> stream_insert(:chat_messages, system_message("* Bio cleared."))
  end

  # ── Catch-all ─────────────────────────────────────────────

  def handle_ui_action(socket, _action, _payload), do: socket

  # ── Private helpers ───────────────────────────────────────

  defp handle_set_away(socket, message) do
    session = Session.set_away(socket.assigns.session, message)

    Enum.each(session.channels, fn channel ->
      safe_update_away("channel:#{channel}", session.nickname, true, message)
    end)

    socket
    |> stream_insert(:chat_messages, system_message("You are now away: #{message}"))
    |> assign(session: session)
  end

  defp handle_clear_away(socket) do
    session = socket.assigns.session
    new_session = Session.set_away(session, nil)

    Enum.each(session.channels, fn channel ->
      safe_update_away("channel:#{channel}", session.nickname, false, nil)
    end)

    socket
    |> stream_insert(:chat_messages, system_message("You are no longer away"))
    |> assign(session: new_session)
  end

  defp handle_set_topic(socket, channel, topic) do
    case Server.set_topic(channel, socket.assigns.session.nickname, topic) do
      :ok -> socket
      {:error, msg} -> stream_insert(socket, :chat_messages, error_message(msg))
    end
  end

  defp handle_view_topic(socket, channel) do
    case Server.get_state(channel) do
      {:ok, state} ->
        topic_text = if state.topic == "", do: "No topic set", else: state.topic

        stream_insert(
          socket,
          :chat_messages,
          system_message("Topic for #{channel}: #{topic_text}")
        )

      {:error, _} ->
        socket
    end
  end

  defp show_help_message(socket, commands) do
    text =
      "Available commands: " <>
        Enum.join(Enum.map(commands, &"/#{&1}"), ", ") <>
        "\nType /help <command> for details, or press F1 for the full help system."

    stream_insert(socket, :chat_messages, system_message(text))
  end

  defp show_command_help_message(socket, help) do
    text = "#{help.syntax} - #{help.description}"
    stream_insert(socket, :chat_messages, system_message(text))
  end

  defp format_notify_entry(entry) do
    status = if entry.online, do: "online", else: "offline"
    note = if entry.note, do: " - #{entry.note}", else: ""
    "  #{entry.tracked_nickname} [#{status}]#{note}"
  end

  defp format_ignore_entry(entry) do
    alias RetroHexChat.Chat.IgnoreEntry
    expires = if IgnoreEntry.permanent?(entry), do: "permanent", else: "timed"
    "  #{entry.nickname} [#{entry.ignore_type}] (#{expires})"
  end

  defp format_autojoin_entry(entry) do
    key_part = if entry.channel_key, do: " (key: ****)", else: ""
    "  #{entry.channel_name}#{key_part}"
  end

  defp format_autorespond_entry(entry) do
    status = if entry.enabled, do: "[ON]", else: "[OFF]"
    channel = entry.channel_filter || "(all)"
    "  #{entry.position}: #{status} #{entry.trigger_event} #{channel} → #{entry.command}"
  end

  defp autorespond_error_msg(:list_full), do: "Maximum 10 auto-respond rules"
  defp autorespond_error_msg(:invalid_trigger), do: "Invalid trigger event"
  defp autorespond_error_msg(:invalid_channel), do: "Channel filter must start with #"
  defp autorespond_error_msg(:command_too_long), do: "Command too long (max 500 characters)"

  defp autorespond_error_msg(:command_chaining),
    do: "Command must not contain chaining (|, &&, ;)"

  defp validate_operator(nickname, state) do
    if nickname in state.operators do
      :ok
    else
      {:error, "* You are not a channel operator"}
    end
  end

  defp validate_invite_only(channel, state) do
    if state.modes_detail.invite_only do
      :ok
    else
      {:error, "* #{channel} is not invite-only — anyone can join"}
    end
  end

  defp validate_target_not_in_channel(target, state) do
    member_nicks = Enum.map(state.members, fn {nick, _role} -> nick end)

    if target in member_nicks do
      {:error, "* #{target} is already in the channel"}
    else
      :ok
    end
  end

  defp validate_target_online(target) do
    case Server.get_state("#lobby") do
      {:ok, state} ->
        member_nicks = Enum.map(state.members, fn {nick, _role} -> nick end)

        if target in member_nicks do
          :ok
        else
          {:error, "* User '#{target}' not found"}
        end

      {:error, _} ->
        {:error, "* User '#{target}' not found"}
    end
  end
end
