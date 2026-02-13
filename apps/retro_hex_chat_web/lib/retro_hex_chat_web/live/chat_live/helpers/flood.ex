defmodule RetroHexChatWeb.ChatLive.Helpers.Flood do
  @moduledoc """
  Flood detection and auto-ignore helpers.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [stream_insert: 3]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.{FloodProtection, FloodTracker, IgnoreList}
  alias RetroHexChatWeb.ChatLive.Helpers.Messages
  alias RetroHexChatWeb.ChatLive.Helpers.Persistence

  @cooldown_duration_ms 60_000

  @spec check_flood_and_auto_ignore(Phoenix.LiveView.Socket.t(), String.t(), atom(), Session.t()) ::
          Phoenix.LiveView.Socket.t()
  def check_flood_and_auto_ignore(socket, _sender, :system, _session), do: socket

  def check_flood_and_auto_ignore(socket, sender, _msg_type, session) do
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
        maybe_trigger_auto_ignore(socket, sender, session)
      else
        socket
      end
    end
  end

  @spec maybe_trigger_auto_ignore(Phoenix.LiveView.Socket.t(), String.t(), Session.t()) ::
          Phoenix.LiveView.Socket.t()
  def maybe_trigger_auto_ignore(socket, sender, session) do
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
          |> stream_insert(
            :chat_messages,
            Messages.system_message(
              "* #{sender} has been auto-ignored for flooding (#{duration_str})"
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
    "#{hours} hour#{if hours > 1, do: "s", else: ""}"
  end

  def format_duration(seconds) when seconds >= 60 do
    minutes = div(seconds, 60)
    "#{minutes} minute#{if minutes > 1, do: "s", else: ""}"
  end

  def format_duration(seconds), do: "#{seconds} seconds"

  # Private helpers

  defp cooldown_active?(auto_state, sender_key) do
    case Map.get(auto_state.cooldowns, sender_key) do
      nil ->
        false

      cooldown_until ->
        System.monotonic_time(:millisecond) < cooldown_until
    end
  end
end
