defmodule RetroHexChatWeb.ChatLive.PubsubHandlers.Presence do
  @moduledoc """
  PubSub handlers for presence events: user connect/disconnect notifications,
  notify debounce, link preview results, and channel invites.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3]

  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.ChatLive.Helpers,
    only: [
      system_event: 2,
      push_status_message: 3,
      play_event_sound: 3,
      maybe_persist_notify_list: 2,
      join_channel_in_background: 3,
      start_notify_debounce: 3,
      push_whois_info: 2
    ]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.{CapturedURL, IgnoreList, LinkPreview}
  alias RetroHexChat.Presence.NotifyList

  # ── Global presence events ────────────────────────────────

  def handle_info({:user_connected, %{nickname: nick}}, socket) do
    session = socket.assigns.session

    if nick == session.nickname do
      {:halt, socket}
    else
      if NotifyList.tracking?(session.notify_list, nick) do
        {:halt, start_notify_debounce(socket, nick, :online)}
      else
        {:halt, socket}
      end
    end
  end

  def handle_info({:user_disconnected, %{nickname: nick}}, socket) do
    session = socket.assigns.session

    if NotifyList.tracking?(session.notify_list, nick) do
      {:halt, start_notify_debounce(socket, nick, :offline)}
    else
      {:halt, socket}
    end
  end

  # ── Notify debounce timer ─────────────────────────────────

  def handle_info({:notify_debounce, nickname, status}, socket) do
    session = socket.assigns.session
    timers = Map.delete(socket.assigns.notify_debounce_timers, String.downcase(nickname))

    online? = status == :online
    updated_list = NotifyList.set_online(session.notify_list, nickname, online?)
    new_session = Session.set_notify_list(session, updated_list)

    msg =
      if online?,
        do: gettext("* %{nickname} is now online", nickname: nickname),
        else: gettext("* %{nickname} has gone offline", nickname: nickname)

    type = if online?, do: :notify_online, else: :notify_offline

    buddy_sound = if online?, do: :buddy_online, else: :buddy_offline

    socket =
      socket
      |> assign(session: new_session, notify_debounce_timers: timers)
      |> maybe_persist_notify_list(new_session)
      |> push_status_message(msg, type)
      |> play_event_sound(buddy_sound, new_session)

    socket =
      if online? && new_session.notify_list.settings.auto_whois do
        push_whois_info(socket, nickname)
      else
        socket
      end

    {:halt, socket}
  end

  # ── Link preview result ───────────────────────────────────

  def handle_info({:link_preview_result, url, {:ok, title}}, socket) do
    LinkPreview.Cache.put(url, title)

    updated_entries =
      Enum.map(socket.assigns.url_catcher_entries, fn entry ->
        if entry.url == url, do: CapturedURL.set_preview_title(entry, title), else: entry
      end)

    socket =
      socket
      |> assign(
        link_previews: Map.put(socket.assigns.link_previews, url, title),
        url_catcher_entries: updated_entries
      )
      |> push_event("link_preview", %{url: url, title: title})

    {:halt, socket}
  end

  def handle_info({:link_preview_result, url, {:error, _}}, socket) do
    LinkPreview.Cache.put_error(url)
    {:halt, socket}
  end

  # ── Channel invite ────────────────────────────────────────

  def handle_info({:channel_invite, %{channel: channel, inviter: inviter}}, socket) do
    session = socket.assigns.session

    if IgnoreList.ignored?(session.ignore_list, inviter, :invite) do
      {:halt, socket}
    else
      handle_invite(socket, session, channel, inviter)
    end
  end

  # ── Task/DOWN catch-all ───────────────────────────────────

  def handle_info({_ref, _result}, socket), do: {:halt, socket}
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket), do: {:halt, socket}

  # ── Catch-all: pass unhandled to next hook ────────────────

  def handle_info(_, socket), do: {:cont, socket}

  # ── Private helpers ───────────────────────────────────────

  defp handle_invite(socket, session, channel, inviter) do
    if Session.get_auto_join_on_invite(session) do
      socket =
        socket
        |> join_channel_in_background(channel, session)
        |> system_event(
          gettext("* You have been invited to %{channel} by %{inviter} (auto-joined)",
            channel: channel,
            inviter: inviter
          )
        )

      {:halt, socket}
    else
      pending = socket.assigns.pending_invites
      {pending, _old} = cancel_existing_invite(pending, channel)
      timer_ref = Process.send_after(self(), {:invite_expired, channel}, 300_000)

      invite = %{
        channel: channel,
        inviter: inviter,
        invited_at: DateTime.utc_now(),
        timer_ref: timer_ref
      }

      socket =
        socket
        |> assign(pending_invites: pending ++ [invite])
        |> push_status_message(
          gettext("* %{inviter} has invited you to %{channel}",
            inviter: inviter,
            channel: channel
          ),
          :system
        )

      {:halt, socket}
    end
  end

  defp cancel_existing_invite(pending, channel) do
    case Enum.split_with(pending, &(&1.channel == channel)) do
      {[existing], rest} ->
        Process.cancel_timer(existing.timer_ref)
        {rest, existing}

      {[], _} ->
        {pending, nil}
    end
  end
end
