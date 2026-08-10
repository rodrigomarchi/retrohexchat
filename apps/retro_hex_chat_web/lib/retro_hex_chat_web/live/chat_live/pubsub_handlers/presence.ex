defmodule RetroHexChatWeb.ChatLive.PubsubHandlers.Presence do
  @moduledoc """
  PubSub handlers for presence events: user connect/disconnect notifications,
  notify debounce, link preview results, and channel invites.
  """

  import Phoenix.Component, only: [assign: 2]

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
  alias RetroHexChat.Chat.{CapturedURL, IgnoreList}
  alias RetroHexChat.Presence.NotifyList
  alias RetroHexChat.Scraper.Store
  alias RetroHexChatWeb.ChatLive.Components.MessageViewport

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
        do: dgettext("chat", "* %{nickname} is now online", nickname: nickname),
        else: dgettext("chat", "* %{nickname} has gone offline", nickname: nickname)

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

  # ── Scraped page ──────────────────────────────────────────

  # One shape, whether the page came from the archive or from the network a
  # moment ago. The hash matches rows filed under the address the page was stored
  # at; the URL is what the viewport reads the page back with, since the card it
  # renders has to be built in this reader's locale rather than the scraper's.
  def handle_info(
        {:scraped_page, %{status: "ready", url: url, url_hash: url_hash, title: title}},
        socket
      )
      when is_binary(title) do
    socket =
      socket
      |> update_link_preview(url_hash, title)
      |> MessageViewport.attach_preview(url, url_hash)

    {:halt, socket}
  end

  def handle_info({:scraped_page, %{}}, socket), do: {:halt, socket}

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
  # `is_reference/1` guard is load bearing: without it this halts EVERY 2-tuple,
  # swallowing island→parent bubbles (e.g. `{:highlight_dialog_session, session}`)
  # before they reach the LiveView. Only real `Task` results are `{ref, result}`.

  def handle_info({ref, _result}, socket) when is_reference(ref), do: {:halt, socket}
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
          dgettext("chat", "* You have been invited to %{channel} by %{inviter} (auto-joined)",
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
          dgettext("chat", "* %{inviter} has invited you to %{channel}",
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

  # Matched by hash, not by string: the captured URL still carries the campaign
  # parameters it was posted with, while the page was stored under the address
  # they all reduce to.
  defp update_link_preview(socket, url_hash, title) do
    entries =
      Enum.map(socket.assigns.url_catcher_entries, fn entry ->
        if entry_hash(entry.url) == url_hash,
          do: CapturedURL.set_preview_title(entry, title),
          else: entry
      end)

    assign(socket, url_catcher_entries: entries)
  end

  defp entry_hash(url) do
    case Store.hash_url(url) do
      {:ok, url_hash} -> url_hash
      {:error, :invalid_url} -> nil
    end
  end
end
