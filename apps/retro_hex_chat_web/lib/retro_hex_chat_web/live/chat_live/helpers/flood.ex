defmodule RetroHexChatWeb.ChatLive.Helpers.Flood do
  @moduledoc """
  Flood detection and auto-ignore helpers.

  The decision is per reader: this runs in one viewer's LiveView, and the
  nickname it silences goes quiet for that viewer alone. Nothing is broadcast
  and the sender is never told, which is what made a flooding bot invisible —
  the room emptied of its wire one reader at a time.

  So an auto-ignore is reported. The persisted entry cannot stand in for it: it
  carries no flag saying it was automatic, and `IgnoreList` drops it when it
  expires, so five minutes later there is nothing left to find. The log line and
  the telemetry event are the only durable record, and `kind` is the tag that
  matters — a silenced bot is our defect, a silenced person is moderation
  working.
  """

  import Phoenix.Component, only: [assign: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Bots.Registry, as: BotRegistry
  alias RetroHexChat.Chat.{FloodProtection, FloodTracker, IgnoreList}
  alias RetroHexChat.Observability
  alias RetroHexChatWeb.ChatLive.Components.MessageViewport
  alias RetroHexChatWeb.ChatLive.Helpers.Messages
  alias RetroHexChatWeb.ChatLive.Helpers.Persistence

  require Logger

  @cooldown_duration_ms 60_000
  @auto_ignore_event [:retro_hex_chat, :chat, :auto_ignore]

  @type source :: {:channel, String.t()} | {:private, String.t()}

  @spec check_flood_and_auto_ignore(
          Phoenix.LiveView.Socket.t(),
          String.t(),
          atom(),
          source(),
          Session.t()
        ) :: Phoenix.LiveView.Socket.t()
  def check_flood_and_auto_ignore(socket, _sender, :system, _source, _session), do: socket

  def check_flood_and_auto_ignore(socket, sender, _msg_type, source, session) do
    if String.downcase(sender) == String.downcase(session.nickname) do
      socket
    else
      flood_settings = session.flood_protection
      tracker = FloodTracker.record_message(socket.assigns.flood_tracker, sender)
      socket = assign(socket, flood_tracker: tracker)

      if FloodTracker.flooded?(
           tracker,
           sender,
           FloodProtection.get_flood_threshold(flood_settings),
           FloodProtection.get_flood_window_seconds(flood_settings)
         ) do
        maybe_trigger_auto_ignore(socket, sender, source, session)
      else
        socket
      end
    end
  end

  @spec maybe_trigger_auto_ignore(
          Phoenix.LiveView.Socket.t(),
          String.t(),
          source(),
          Session.t()
        ) :: Phoenix.LiveView.Socket.t()
  def maybe_trigger_auto_ignore(socket, sender, source, session) do
    sender_key = String.downcase(sender)
    auto_state = socket.assigns.auto_ignore_state

    already_active = Map.has_key?(auto_state.active, sender_key)
    in_cooldown = cooldown_active?(auto_state, sender_key)
    already_ignored = IgnoreList.ignored?(session.ignore_list, sender, :all)

    if already_active or in_cooldown or already_ignored do
      socket
    else
      duration = FloodProtection.get_auto_ignore_duration_seconds(session.flood_protection)
      expires_at = DateTime.add(DateTime.utc_now(), duration, :second)

      case IgnoreList.add_entry(session.ignore_list, sender, :all, expires_at) do
        {:ok, updated_list} ->
          report_auto_ignore(sender, source, duration, session.flood_protection)
          new_session = Session.set_ignore_list(session, updated_list)

          timer_ref =
            Process.send_after(self(), {:auto_ignore_expired, sender}, duration * 1000)

          new_active = Map.put(auto_state.active, sender_key, timer_ref)
          new_auto_state = %{auto_state | active: new_active}

          duration_str = format_duration(duration)

          socket
          |> assign(
            session: new_session,
            auto_ignore_state: new_auto_state
          )
          |> Persistence.maybe_persist_ignore_list(new_session)
          |> MessageViewport.insert(
            Messages.system_message(
              dgettext("chat", "* %{sender} has been auto-ignored for flooding (%{duration})",
                sender: sender,
                duration: duration_str
              )
            )
          )

        {:error, _} ->
          socket
      end
    end
  end

  @spec cancel_auto_ignore_with_cooldown(Phoenix.LiveView.Socket.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  def cancel_auto_ignore_with_cooldown(socket, nick) do
    sender_key = String.downcase(nick)
    auto_state = socket.assigns.auto_ignore_state

    case Map.get(auto_state.active, sender_key) do
      nil ->
        socket

      timer_ref ->
        Process.cancel_timer(timer_ref)

        new_active = Map.delete(auto_state.active, sender_key)
        cooldown_until = System.monotonic_time(:millisecond) + @cooldown_duration_ms
        new_cooldowns = Map.put(auto_state.cooldowns, sender_key, cooldown_until)

        new_auto_state = %{active: new_active, cooldowns: new_cooldowns}

        new_tracker = FloodTracker.reset_sender(socket.assigns.flood_tracker, nick)

        assign(socket,
          auto_ignore_state: new_auto_state,
          flood_tracker: new_tracker
        )
    end
  end

  @spec format_duration(integer()) :: String.t()
  def format_duration(seconds) when seconds >= 3600 do
    hours = div(seconds, 3600)
    dngettext("chat", "%{count} hour", "%{count} hours", hours)
  end

  def format_duration(seconds) when seconds >= 60 do
    minutes = div(seconds, 60)
    dngettext("chat", "%{count} minute", "%{count} minutes", minutes)
  end

  def format_duration(seconds),
    do: dngettext("chat", "%{count} second", "%{count} seconds", seconds)

  # Private helpers

  # Deliberately without the reader's nickname. Monitoring a bot needs to know
  # which bot went quiet and where, not who stopped listening; the count of
  # events already says how many readers it happened to.
  @spec report_auto_ignore(String.t(), source(), pos_integer(), map()) :: :ok
  defp report_auto_ignore(sender, source, duration_seconds, flood_settings) do
    kind = sender_kind(sender)
    {surface, where} = describe(source)

    Logger.info(
      "chat_auto_ignore sender=#{sender} kind=#{kind} surface=#{surface} where=#{where} " <>
        "duration_s=#{duration_seconds} " <>
        "threshold=#{FloodProtection.get_flood_threshold(flood_settings)} " <>
        "window_s=#{FloodProtection.get_flood_window_seconds(flood_settings)}"
    )

    Observability.record_event(
      @auto_ignore_event,
      %{count: 1, duration_seconds: duration_seconds},
      %{sender: sender, kind: kind, surface: surface}
    )
  end

  # A nickname with a running bot server behind it is a bot. The lookup costs a
  # registry read on an event that is rare by definition.
  @spec sender_kind(String.t()) :: String.t()
  defp sender_kind(sender) do
    case BotRegistry.lookup(sender) do
      {:ok, _pid} -> "bot"
      _ -> "user"
    end
  end

  @spec describe(source()) :: {String.t(), String.t()}
  defp describe({:channel, channel}), do: {"channel", channel}
  # The peer's nickname is the conversation's identity and would name a person,
  # so a private flood reports only that it was private.
  defp describe({:private, _peer}), do: {"private", "-"}
  defp describe(_other), do: {"unknown", "-"}

  defp cooldown_active?(auto_state, sender_key) do
    case Map.get(auto_state.cooldowns, sender_key) do
      nil ->
        false

      cooldown_until ->
        System.monotonic_time(:millisecond) < cooldown_until
    end
  end
end
