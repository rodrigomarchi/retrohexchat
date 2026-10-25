defmodule RetroHexChatWeb.ChatLive.PubsubHandlers.Presence do
  @moduledoc """
  PubSub handlers for presence events: user connect/disconnect notifications,
  notify debounce, link preview results, and channel invites.

  These are the only events a private conversation's user list has to go on. A
  channel publishes its own joins, parts and away changes on its topic, and its
  roster keys on those; two people in a query share no topic of that kind, so
  whether the other person is here, away or gone reaches this session on the
  server-wide presence topic and nowhere else.
  """

  alias RetroHexChat.Nickname

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [send_update: 2]

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
  alias RetroHexChat.Games.Activity
  alias RetroHexChat.Presence.NotifyList
  alias RetroHexChat.Scraper.Store
  alias RetroHexChatWeb.ChatLive.Components.HoverCard
  alias RetroHexChatWeb.ChatLive.Components.MessageViewport
  alias RetroHexChatWeb.ChatLive.Components.Nicklist
  alias RetroHexChatWeb.ChatLive.Helpers.Conversation
  alias RetroHexChatWeb.ChatLive.Helpers.NickFlags
  alias RetroHexChatWeb.ChatLive.Helpers.PendingInvite
  alias RetroHexChatWeb.Components.UI.LiveMatch
  alias RetroHexChatWeb.Site.Documents
  alias RetroHexChatWeb.Site.Pages

  # ── Global presence events ────────────────────────────────

  # Somebody chose a character, or opened the chat in another language. The
  # user list is a stream, so the row has to be re-inserted or it keeps the
  # face and the flag it was drawn with.
  def handle_info({:avatar_changed, %{nickname: nick, avatar: avatar}}, socket),
    do: {:halt, put_member(socket, nick, :avatar, avatar)}

  def handle_info({:locale_changed, %{nickname: nick, locale: locale}}, socket),
    do: {:halt, put_member(socket, nick, :locale, locale)}

  def handle_info({:user_connected, %{nickname: nick}}, socket) do
    session = socket.assigns.session
    socket = refresh_private_roster(socket, nick)

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
    socket = refresh_private_roster(socket, nick)

    if NotifyList.tracking?(session.notify_list, nick) do
      {:halt, start_notify_debounce(socket, nick, :offline)}
    else
      {:halt, socket}
    end
  end

  def handle_info(
        {:user_presence_changed, %{nickname: nick, away: away} = payload},
        socket
      ) do
    {:halt,
     socket
     |> refresh_private_roster(nick)
     |> maybe_update_hover_away(nick, away, Map.get(payload, :away_message))}
  end

  # ── Notify debounce timer ─────────────────────────────────

  def handle_info({:notify_debounce, nickname, status}, socket) do
    session = socket.assigns.session
    timers = Map.delete(socket.assigns.notify_debounce_timers, Nickname.key(nickname))

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
  # swallowing island→parent bubbles (e.g. `{:dialog_session, session, :highlight}`)
  # before they reach the LiveView. Only real `Task` results are `{ref, result}`.

  def handle_info({ref, _result}, socket) when is_reference(ref), do: {:halt, socket}
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket), do: {:halt, socket}

  # ── Catch-all: pass unhandled to next hook ────────────────

  # Who is in a Retro Games match anywhere, for the badge in the user list and
  # the matches to watch. Presence is the source: a tab that closes mid-match
  # takes its badge with it. Every connected page hears every diff, so a burst
  # of them — matches starting together, somebody toggling a game — is read
  # once, a moment after the first.
  @games_refresh_ms 1_000

  def handle_info(%{event: "presence_diff"}, socket) do
    if socket.assigns[:games_refresh_due] do
      {:halt, socket}
    else
      Process.send_after(self(), :refresh_games_playing, @games_refresh_ms)
      {:halt, assign(socket, games_refresh_due: true)}
    end
  end

  def handle_info(:refresh_games_playing, socket) do
    {:halt,
     socket
     |> assign(games_refresh_due: false)
     |> mark_games_playing()}
  end

  def handle_info(_, socket), do: {:cont, socket}

  defp mark_games_playing(socket) do
    games = Map.new(Activity.now(), fn {key, %{game_id: game_id}} -> {key, game_id} end)

    socket
    |> Nicklist.mark_playing(games)
    |> assign_live_matches(Activity.live_matches())
    |> refresh_game_home()
  end

  # The flag before each player's name, asked for again only when somebody
  # else is playing — not on every move of anybody's presence.
  defp assign_live_matches(socket, matches) do
    nicks = LiveMatch.player_nicks(matches)
    {_nicks, locales} = cache = NickFlags.locales(nicks, socket.assigns[:live_match_locales])

    assign(socket,
      live_matches: LiveMatch.put_player_locales(matches, locales),
      live_match_locales: cache
    )
  end

  # A game's home, when one is open, says who is playing it now: loaded again
  # only when that changed, not on every move of anybody's presence.
  defp refresh_game_home(socket) do
    case socket.assigns.docs[:site] do
      %{page: Pages.Game, open?: true, assigns: loaded} ->
        if Pages.Game.live_changed?(loaded),
          do: Documents.refresh(socket, Pages.Game),
          else: socket

      _no_game_home ->
        socket
    end
  end

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
      {pending, _old} = PendingInvite.cancel(pending, channel)
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

  # A presence event carries one fact about one person; the roster wants every
  # fact about both. Two people is a keyed lookup each, so re-reading the
  # conversation is cheaper than reconciling a partial row — and cannot drift.
  @spec refresh_private_roster(Phoenix.LiveView.Socket.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  defp refresh_private_roster(socket, nick) do
    if Conversation.active_private_participant?(socket.assigns.session, nick) do
      Conversation.load_roster(socket)
    else
      socket
    end
  end

  @spec maybe_update_hover_away(
          Phoenix.LiveView.Socket.t(),
          String.t(),
          boolean(),
          String.t() | nil
        ) :: Phoenix.LiveView.Socket.t()
  defp maybe_update_hover_away(socket, nick, away, message) do
    send_update(HoverCard, id: HoverCard.id(), action: {:update_away, nick, away, message})
    socket
  end

  defp put_member(socket, nick, key, value) do
    members = socket.assigns.conversation_members

    case Enum.find(members, &Nickname.equal?(&1.nickname, nick)) do
      nil ->
        socket

      # Already drawn that way: re-inserting the row would only push it again.
      %{^key => ^value} ->
        socket

      member ->
        updated = Map.put(member, key, value)

        socket
        |> assign(
          conversation_members:
            Enum.map(members, &if(&1.nickname == member.nickname, do: updated, else: &1))
        )
        |> Nicklist.upsert(updated)
    end
  end
end
