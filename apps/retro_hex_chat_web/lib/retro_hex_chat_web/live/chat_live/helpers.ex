defmodule RetroHexChatWeb.ChatLive.Helpers do
  @moduledoc """
  Facade for shared helper functions used across ChatLive hook modules.

  Delegates to focused sub-modules under `Helpers.*`:
  - `Messages` — message factory functions
  - `Persistence` — async save for identified users
  - `Channel` — join/part/load channel data
  - `PM` — private message conversations and sending
  - `Presence` — presence tracker wrappers
  - `Whois` — whois/whowas text output
  - `Flood` — flood detection and auto-ignore
  - `CTCP` — CTCP reply handling
  - `Autorespond` — auto-respond rule execution
  - `Session` — nick colors, sounds, reconnect, misc actions

  All event-handler modules can `import RetroHexChatWeb.ChatLive.Helpers`
  and call any function directly — the public API is unchanged.
  """

  # ── Messages ─────────────────────────────────────────────────

  defdelegate system_message(content), to: __MODULE__.Messages
  defdelegate error_message(content), to: __MODULE__.Messages
  defdelegate service_message(author, content), to: __MODULE__.Messages
  defdelegate notice_message(author, content), to: __MODULE__.Messages
  defdelegate push_status_message(socket, content, type), to: __MODULE__.Messages

  # ── Persistence ──────────────────────────────────────────────

  defdelegate maybe_persist_notify_list(socket, session), to: __MODULE__.Persistence
  defdelegate maybe_persist_contacts(socket, session), to: __MODULE__.Persistence
  defdelegate maybe_persist_nick_colors(socket, session), to: __MODULE__.Persistence
  defdelegate maybe_persist_highlight_words(socket, session), to: __MODULE__.Persistence
  defdelegate maybe_persist_ignore_list(socket, session), to: __MODULE__.Persistence
  defdelegate maybe_persist_perform_list(socket, session), to: __MODULE__.Persistence
  defdelegate maybe_persist_autojoin_list(socket, session), to: __MODULE__.Persistence
  defdelegate maybe_persist_aliases(socket, session), to: __MODULE__.Persistence
  defdelegate maybe_persist_custom_menus(socket, session), to: __MODULE__.Persistence
  defdelegate maybe_persist_autorespond_rules(socket, session), to: __MODULE__.Persistence
  defdelegate maybe_persist_favorites(socket, session), to: __MODULE__.Persistence
  defdelegate load_persisted_data(session, nick), to: __MODULE__.Persistence

  # ── Channel ──────────────────────────────────────────────────

  defdelegate join_channel(socket, channel_name, session), to: __MODULE__.Channel
  defdelegate join_channel(socket, channel_name, session, password), to: __MODULE__.Channel
  defdelegate part_channel(socket, channel_name), to: __MODULE__.Channel
  defdelegate part_channel_after_kick(socket, channel_name), to: __MODULE__.Channel
  defdelegate load_channel_users(socket, channel_name), to: __MODULE__.Channel
  defdelegate load_channel_messages_with_pagination(socket, channel_name), to: __MODULE__.Channel
  defdelegate ensure_channel_exists(channel_name), to: __MODULE__.Channel
  defdelegate channels_where_operator(session), to: __MODULE__.Channel
  defdelegate handle_set_topic(socket, channel, topic), to: __MODULE__.Channel
  defdelegate cleanup_channels(session, reason \\ "Connection lost"), to: __MODULE__.Channel
  defdelegate validate_target_online(target), to: __MODULE__.Channel

  # ── PM ───────────────────────────────────────────────────────

  defdelegate open_pm_conversation(socket, target), to: __MODULE__.PM
  defdelegate handle_pm_send(socket, target, content), to: __MODULE__.PM
  defdelegate ensure_pm_subscription(nick_a, nick_b), to: __MODULE__.PM
  defdelegate pm_topic(nick_a, nick_b), to: __MODULE__.PM
  defdelegate send_plain_message(socket, session, text), to: __MODULE__.PM
  defdelegate handle_notice_send(socket, session, target, content), to: __MODULE__.PM
  defdelegate handle_action_message(socket, session, content), to: __MODULE__.PM

  # ── Presence ─────────────────────────────────────────────────

  defdelegate safe_track_user(topic, nickname), to: __MODULE__.Presence
  defdelegate safe_track_user(topic, nickname, extra_meta), to: __MODULE__.Presence
  defdelegate safe_untrack_user(topic, nickname), to: __MODULE__.Presence
  defdelegate safe_update_away(topic, nickname, away, message), to: __MODULE__.Presence
  defdelegate safe_update_activity(topic, nickname), to: __MODULE__.Presence
  defdelegate safe_update_bio(topic, nickname, bio), to: __MODULE__.Presence
  defdelegate reset_activity(socket), to: __MODULE__.Presence

  # ── Whois ────────────────────────────────────────────────────

  defdelegate show_whois_text(socket, target), to: __MODULE__.Whois
  defdelegate show_whowas_text(socket, target), to: __MODULE__.Whois

  # ── Flood ────────────────────────────────────────────────────

  defdelegate check_flood_and_auto_ignore(socket, sender, msg_type, session), to: __MODULE__.Flood
  defdelegate maybe_trigger_auto_ignore(socket, sender, session), to: __MODULE__.Flood

  defdelegate cancel_auto_ignore_with_cooldown(socket, nick), to: __MODULE__.Flood
  defdelegate format_duration(seconds), to: __MODULE__.Flood

  # ── CTCP ─────────────────────────────────────────────────────

  defdelegate maybe_send_ctcp_reply(socket, session, settings, type, sender, req_id, sent_at),
    to: __MODULE__.CTCP

  defdelegate ctcp_reply_allowed?(tracker, limit, window_seconds), to: __MODULE__.CTCP

  # ── Autorespond ──────────────────────────────────────────────

  defdelegate maybe_fire_autorespond(socket, event_type, channel, triggering_nick, dispatch_fn),
    to: __MODULE__.Autorespond

  defdelegate fire_rule(rule, socket, triggering_nick, channel, now, dispatch_fn),
    to: __MODULE__.Autorespond

  defdelegate execute_autorespond(
                socket,
                rule,
                triggering_nick,
                channel,
                cooldown_key,
                now,
                dispatch_command_fn
              ),
              to: __MODULE__.Autorespond

  # ── Notifications ────────────────────────────────────────────

  defdelegate maybe_push_notification(socket, event_type, attrs), to: __MODULE__.Notifications

  # ── Session / Nick colors / Sounds / Reconnect / Misc ────────

  defdelegate build_nick_color_fn(session), to: __MODULE__.Session
  defdelegate rebuild_nick_color_fn(socket, session), to: __MODULE__.Session
  defdelegate capture_urls(socket, content, source, source_type, author), to: __MODULE__.Session
  defdelegate maybe_fetch_previews(socket, urls), to: __MODULE__.Session
  defdelegate spawn_preview_fetch(url, lv_pid), to: __MODULE__.Session
  defdelegate maybe_start_ignore_timer(socket, nick, duration), to: __MODULE__.Session
  defdelegate cancel_ignore_timer(socket, nick), to: __MODULE__.Session
  defdelegate parse_dialog_duration(str), to: __MODULE__.Session
  defdelegate start_notify_debounce(socket, nickname, status), to: __MODULE__.Session
  defdelegate cancel_notify_timer(socket, nickname), to: __MODULE__.Session
  defdelegate push_whois_info(socket, nickname), to: __MODULE__.Session
  defdelegate play_event_sound(socket, event_type, session), to: __MODULE__.Session
  defdelegate maybe_play_highlight_sound(socket, payload, session), to: __MODULE__.Session

  defdelegate maybe_flash_channel(socket, channel_key, event_type, session),
    to: __MODULE__.Session

  defdelegate push_reconnect_state(socket), to: __MODULE__.Session
  defdelegate restore_session(socket, params), to: __MODULE__.Session
  defdelegate close_context_menu(socket), to: __MODULE__.Session
  defdelegate maybe_highlight(payload, session), to: __MODULE__.Session
  defdelegate handle_nick_change(socket, new_nick), to: __MODULE__.Session
  defdelegate handle_quit(socket, reason), to: __MODULE__.Session
  defdelegate handle_set_away(socket, message), to: __MODULE__.Session
  defdelegate maybe_start_nickserv_timer(socket, nickname), to: __MODULE__.Session
  defdelegate maybe_join_from_params(socket, params), to: __MODULE__.Session
  defdelegate maybe_trigger_perform(socket), to: __MODULE__.Session
end
