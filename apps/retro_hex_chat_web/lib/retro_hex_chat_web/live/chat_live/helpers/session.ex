defmodule RetroHexChatWeb.ChatLive.Helpers.Session do
  @moduledoc """
  Session, reconnect, nick color, and miscellaneous action helpers.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3, push_navigate: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  require Logger

  alias RetroHexChat.Accounts.{NickColors, Session}
  alias RetroHexChat.Channels.Server

  alias RetroHexChat.Chat.{
    CapturedURL,
    Content,
    Highlight,
    PerformList,
    ReconnectState,
    SoundSettings
  }

  alias RetroHexChat.Scraper

  alias RetroHexChat.Services.NickServ
  alias RetroHexChat.Surfaces
  alias RetroHexChat.Topics
  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.ChatLive.Components.MessageViewport
  alias RetroHexChatWeb.ChatLive.Components.Nicklist
  alias RetroHexChatWeb.ChatLive.Helpers.Channel, as: ChannelHelpers
  alias RetroHexChatWeb.ChatLive.Helpers.Messages
  alias RetroHexChatWeb.ChatLive.Helpers.Persistence
  alias RetroHexChatWeb.ChatLive.Helpers.Presence, as: PresenceHelpers
  alias RetroHexChatWeb.Live.OpenSurfaces

  # ── Nick color functions ───────────────────────────────────

  @nick_color_count 12

  @spec build_nick_color_fn(Session.t()) :: (String.t() -> String.t())
  def build_nick_color_fn(session) do
    fn nickname ->
      case NickColors.color_index_for(session.nick_colors, nickname) do
        nil -> "nick-color-#{:erlang.phash2(nickname, @nick_color_count)}"
        irc_index -> "irc-fg-#{irc_index}"
      end
    end
  end

  @spec rebuild_nick_color_fn(Phoenix.LiveView.Socket.t(), Session.t()) ::
          Phoenix.LiveView.Socket.t()
  def rebuild_nick_color_fn(socket, session) do
    # Re-stream the nicklist rows so their per-nick colors restyle: stream items
    # are not re-pushed by a plain re-render when only `nick_color_fn` changes.
    socket
    |> assign(nick_color_fn: build_nick_color_fn(session))
    |> Nicklist.reset(Map.get(socket.assigns, :conversation_members, []))
  end

  @doc """
  Re-renders the visible messages after a presentation change.

  Streams do not restyle existing rows, so a nick-colour change has to re-stream
  them — but it does not have to re-read them. The viewport keeps the rows it
  rendered, so this costs nothing at the database. It used to re-run the history
  query for every message loaded, which after a long scrollback meant thousands
  of rows fetched to paint them a different colour.
  """
  @spec refresh_active_message_stream(Phoenix.LiveView.Socket.t(), Session.t()) ::
          Phoenix.LiveView.Socket.t()
  def refresh_active_message_stream(socket, _session), do: MessageViewport.restyle(socket)

  # ── URL capture ────────────────────────────────────────────

  # Newest first, and bounded: the catcher is a session-scoped buffer of what
  # scrolled past, not a database list, so there is nothing older to page back
  # to. Unbounded it grew for the whole session inside the LiveView process.
  @max_captured_urls 200

  @spec capture_urls(
          Phoenix.LiveView.Socket.t(),
          String.t(),
          String.t(),
          atom(),
          String.t(),
          Content.format_input()
        ) ::
          Phoenix.LiveView.Socket.t()
  def capture_urls(socket, content, source, source_type, author, content_format \\ "irc") do
    urls = extract_content_urls(content, content_format)

    if urls == [] do
      socket
    else
      new_entries =
        Enum.map(urls, fn url ->
          CapturedURL.new(%{
            url: url,
            source: source,
            source_type: source_type,
            posted_by: author,
            timestamp: DateTime.utc_now()
          })
        end)

      combined = new_entries ++ socket.assigns.url_catcher_entries
      entries = Enum.take(combined, @max_captured_urls)

      # Counting what the buffer refused is the only way the window can say so:
      # once a link is dropped there is nothing left to infer it from, and a
      # full buffer is not proof that anything was discarded.
      dropped =
        (socket.assigns[:url_catcher_dropped] || 0) + max(length(combined) - length(entries), 0)

      socket
      |> assign(url_catcher_entries: entries, url_catcher_dropped: dropped)
      |> maybe_fetch_previews(urls)
    end
  end

  # What is already known arrives on this process as a message rather than a
  # return value, so a title the archive already holds and a title that has to be
  # fetched reach the view by the same path.
  @spec maybe_fetch_previews(Phoenix.LiveView.Socket.t(), [String.t()]) ::
          Phoenix.LiveView.Socket.t()
  def maybe_fetch_previews(socket, urls) do
    Enum.each(urls, &fetch_preview_for_url/1)
    socket
  end

  # ── Ignore timers ──────────────────────────────────────────

  @spec maybe_start_ignore_timer(Phoenix.LiveView.Socket.t(), String.t(), integer() | nil) ::
          Phoenix.LiveView.Socket.t()
  def maybe_start_ignore_timer(socket, _nick, nil), do: socket

  def maybe_start_ignore_timer(socket, nick, duration_seconds) do
    ref = Process.send_after(self(), {:ignore_expired, nick}, duration_seconds * 1000)
    timers = Map.put(socket.assigns.ignore_timers, String.downcase(nick), ref)
    assign(socket, ignore_timers: timers)
  end

  @spec cancel_ignore_timer(Phoenix.LiveView.Socket.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  def cancel_ignore_timer(socket, nick) do
    key = String.downcase(nick)

    case Map.get(socket.assigns.ignore_timers, key) do
      nil ->
        socket

      ref ->
        Process.cancel_timer(ref)
        assign(socket, ignore_timers: Map.delete(socket.assigns.ignore_timers, key))
    end
  end

  @spec parse_dialog_duration(String.t() | nil) :: {integer() | nil, DateTime.t() | nil}
  def parse_dialog_duration(nil), do: {nil, nil}
  def parse_dialog_duration(""), do: {nil, nil}

  def parse_dialog_duration(str) do
    case Regex.run(~r/^(\d+)([mhd])$/, String.trim(str)) do
      [_, num_str, unit] ->
        num = String.to_integer(num_str)
        multiplier = %{"m" => 60, "h" => 3600, "d" => 86_400}
        seconds = num * multiplier[unit]
        {seconds, DateTime.add(DateTime.utc_now(), seconds, :second)}

      _ ->
        {nil, nil}
    end
  end

  # ── Notify helpers ─────────────────────────────────────────

  @spec start_notify_debounce(Phoenix.LiveView.Socket.t(), String.t(), atom()) ::
          Phoenix.LiveView.Socket.t()
  def start_notify_debounce(socket, nickname, status) do
    key = String.downcase(nickname)
    timers = socket.assigns.notify_debounce_timers

    timers =
      case Map.get(timers, key) do
        nil ->
          timers

        {old_ref, _old_status} ->
          Process.cancel_timer(old_ref)
          Map.delete(timers, key)
      end

    ref = Process.send_after(self(), {:notify_debounce, nickname, status}, 10_000)
    new_timers = Map.put(timers, key, {ref, status})
    assign(socket, notify_debounce_timers: new_timers)
  end

  @spec cancel_notify_timer(Phoenix.LiveView.Socket.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  def cancel_notify_timer(socket, nickname) do
    key = String.downcase(nickname)
    timers = socket.assigns.notify_debounce_timers

    case Map.pop(timers, key) do
      {nil, _} ->
        socket

      {{ref, _status}, new_timers} ->
        Process.cancel_timer(ref)
        assign(socket, notify_debounce_timers: new_timers)
    end
  end

  @spec push_whois_info(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  def push_whois_info(socket, nickname) do
    alias RetroHexChat.Presence.NotifyList
    {:ok, info} = NotifyList.whois_info(nickname)

    info_lines = [dgettext("chat", "[Auto-Whois] %{nickname}:", nickname: nickname)]

    info_lines =
      if info.registered do
        registered =
          if info.identified,
            do: dgettext("chat", "identified"),
            else: dgettext("chat", "not identified")

        info_lines ++
          [dgettext("chat", "  Registered: yes (%{status})", status: registered)]
      else
        info_lines ++ [dgettext("chat", "  Registered: no")]
      end

    Enum.reduce(info_lines, socket, fn line, acc ->
      Messages.push_status_message(acc, line, :system)
    end)
  end

  # ── Sound / Flash ──────────────────────────────────────────

  @spec play_event_sound(Phoenix.LiveView.Socket.t(), atom(), Session.t()) ::
          Phoenix.LiveView.Socket.t()
  def play_event_sound(socket, event_type, session) do
    sound = SoundSettings.get_sound(session.sound_settings, event_type)

    if socket.assigns[:muted] == true or sound == "none" do
      socket
    else
      push_event(socket, "play_sound", %{type: sound})
    end
  end

  @spec maybe_play_highlight_sound(Phoenix.LiveView.Socket.t(), map(), Session.t()) ::
          Phoenix.LiveView.Socket.t()
  def maybe_play_highlight_sound(socket, %{highlighted: true}, session) do
    play_event_sound(socket, :highlight, session)
  end

  def maybe_play_highlight_sound(socket, _payload, _session), do: socket

  @spec maybe_flash_channel(Phoenix.LiveView.Socket.t(), String.t(), atom(), Session.t()) ::
          Phoenix.LiveView.Socket.t()
  def maybe_flash_channel(socket, channel_key, event_type, session) do
    if SoundSettings.get_flash(session.sound_settings, event_type) do
      flash = MapSet.put(socket.assigns.flash_channels, channel_key)

      socket
      |> assign(flash_channels: flash)
      |> push_event("title_flash_start", %{message: dgettext("chat", "* New activity")})
    else
      socket
    end
  end

  @doc """
  The URLs a message body carries, whatever format it claims to be in.

  Total on purpose: a row that names a format nobody recognises is read as IRC
  rather than dropped, because a link is a link either way.
  """
  @spec extract_content_urls(String.t(), Content.format_input()) :: [String.t()]
  def extract_content_urls(content, content_format) do
    case Content.normalize_format(content_format) do
      {:ok, normalized_format} -> Content.extract_urls(content, normalized_format)
      :error -> Content.extract_urls(content, :irc)
    end
  end

  # ── Session / Reconnect ────────────────────────────────────

  @doc """
  Write the snapshot where the next mount will look for it.

  Two stores, and only one of them is safe to fill at mount. The row is the
  server's own memory of the session. The client copy is handed to
  `ConnectionStatusHook`, which pushes it straight back as `restore_session`
  the moment the connection reports itself restored — so a copy handed over at
  mount is applied a second later and overwrites the conversation the person
  has since opened. Measured: the view jumped to a channel from an earlier
  session about a second after entering a new one.
  """
  @spec persist_reconnect_state(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def persist_reconnect_state(socket) do
    session = socket.assigns.session

    if session.identified do
      case ReconnectState.save(session.nickname, reconnect_snapshot(socket)) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.warning(
            "Failed to persist reconnect state for #{session.nickname}: #{inspect(reason)}"
          )
      end
    end

    socket
  end

  @spec push_reconnect_state(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def push_reconnect_state(socket) do
    socket = persist_reconnect_state(socket)

    push_event(socket, "save_reconnect_state", reconnect_snapshot(socket))
  end

  @spec clear_reconnect_state(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def clear_reconnect_state(socket) do
    session = socket.assigns.session

    if session.identified do
      case ReconnectState.delete(session.nickname) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.warning(
            "Failed to clear reconnect state for #{session.nickname}: #{inspect(reason)}"
          )
      end
    end

    socket
  end

  @spec reconnect_snapshot(Phoenix.LiveView.Socket.t()) :: map()
  def reconnect_snapshot(socket) do
    session = socket.assigns.session

    ReconnectState.to_client_state(session.nickname, %{
      channels: session.channels,
      active_channel: session.active_channel,
      active_pm: session.active_pm,
      open_pm_tabs: socket.assigns[:open_pm_tabs] || [],
      welcomed_channels: MapSet.to_list(session.welcomed_channels || MapSet.new())
    })
  end

  @spec restore_session(Phoenix.LiveView.Socket.t(), map()) :: Phoenix.LiveView.Socket.t()
  def restore_session(socket, params) do
    params = ReconnectState.normalize(params)
    restored_nick = params.nickname
    current_nick = socket.assigns.session.nickname

    if restored_nick != nil and restored_nick != current_nick do
      Logger.debug(
        "Ignoring reconnect state from different user: #{restored_nick} != #{current_nick}"
      )

      socket
    else
      do_restore_session(socket, params)
    end
  end

  defp do_restore_session(socket, params) do
    channels = params.channels
    active_channel = params.active_channel
    active_pm = params.active_pm

    open_pm_tabs =
      sanitize_open_pm_tabs(params.open_pm_tabs, socket.assigns.session.nickname)

    # Restore silently — this path only runs on a reconnect, and surfacing a
    # "Restoring session..." line on every deploy is noise the user never asked for.
    socket =
      socket
      |> restore_welcomed_channels(params.welcomed_channels)
      |> assign(
        reconnect_active_channel: active_channel,
        reconnect_active_pm: active_pm,
        reconnect_open_pm_tabs: open_pm_tabs,
        # Where the person is *now*, so the restore can tell whether they have
        # moved by the time it lands. The rejoin runs 200 ms after the mount and
        # a channel at a time after that; anything they open in between is a
        # deliberate choice, and a restore that overwrites it throws them out of
        # the conversation they just opened.
        reconnect_from: conversation_key(socket.assigns.session)
      )

    if channels != [] do
      Process.send_after(self(), {:execute_rejoin, 0, channels}, 200)
    end

    socket
  end

  @doc false
  @spec conversation_key(Session.t()) :: {String.t() | nil, String.t() | nil}
  def conversation_key(session), do: {session.active_channel, session.active_pm}

  defp sanitize_open_pm_tabs(tabs, own_nick) do
    tabs
    |> Enum.filter(&(String.trim(&1) != "" and &1 != own_nick))
    |> Enum.uniq()
    |> Enum.take(20)
  end

  defp restore_welcomed_channels(socket, channels) do
    session =
      Enum.reduce(channels, socket.assigns.session, fn channel, session ->
        Session.add_welcomed_channel(session, channel)
      end)

    assign(socket, session: session)
  end

  # ── Highlight ──────────────────────────────────────────────

  @spec maybe_highlight(map(), Session.t()) :: map()
  def maybe_highlight(%{type: type} = payload, session)
      when type in [:message, :action] do
    words = Session.get_highlight_words(session).entries

    case Highlight.check(
           payload.content,
           Map.get(payload, :content_format, "irc"),
           session.nickname,
           words,
           payload.author
         ) do
      {:highlight, color} ->
        Map.merge(payload, %{highlighted: true, highlight_color: color})

      :no_highlight ->
        payload
    end
  end

  def maybe_highlight(payload, _session), do: payload

  # ── Nick change / Quit / Away / Action ─────────────────────

  @spec handle_nick_change(Phoenix.LiveView.Socket.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  def handle_nick_change(socket, new_nick) do
    old_nick = socket.assigns.session.nickname

    session =
      socket.assigns.session
      |> Session.update_nickname(new_nick)
      |> Session.set_identified(false)

    Enum.each(session.channels, fn channel ->
      try do
        Server.rename_user(channel, old_nick, new_nick)
      rescue
        e ->
          Logger.warning("Failed to rename #{old_nick}->#{new_nick} in #{channel}: #{inspect(e)}")
      end
    end)

    Enum.each(session.channels, fn channel ->
      case Phoenix.PubSub.broadcast(
             RetroHexChat.PubSub,
             Topics.channel(channel),
             {:nick_changed, %{old_nick: old_nick, new_nick: new_nick}}
           ) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.warning(
            "PubSub nick_changed broadcast to channel:#{channel} failed: #{inspect(reason)}"
          )
      end
    end)

    client_meta = Map.get(socket.assigns, :client_info, %{})

    # Every topic the session is present on, the server-wide one included: left
    # out of this, the old nick stayed listed as online for good and the new one
    # was never there at all — which is what a private conversation, a whois and
    # a nick-in-use check all read.
    Enum.each(PresenceHelpers.session_topics(session), fn topic ->
      PresenceHelpers.safe_untrack_user(topic, old_nick)
      PresenceHelpers.safe_track_user(topic, new_nick, client_meta)
    end)

    Phoenix.PubSub.unsubscribe(RetroHexChat.PubSub, Topics.inbox(old_nick))
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.inbox(new_nick))

    # The fourth thing a rename moves. Every tab of this person is registered
    # under the name they had; left there, this window closing would count no
    # other surface and part the channels a call in another tab stands on.
    Surfaces.rename(old_nick, new_nick)

    users =
      Enum.map(socket.assigns.conversation_members, fn user ->
        if user.nickname == old_nick, do: %{user | nickname: new_nick}, else: user
      end)

    socket
    |> Messages.system_event(
      dgettext("chat", "You are now known as %{nickname}", nickname: new_nick)
    )
    |> assign(session: session, conversation_members: users)
    |> OpenSurfaces.follow_rename(old_nick, new_nick)
    |> Nicklist.reset(users)
  end

  @spec handle_quit(Phoenix.LiveView.Socket.t(), String.t() | nil) :: Phoenix.LiveView.Socket.t()
  def handle_quit(socket, reason) do
    session = socket.assigns.session
    quit_reason = reason || dgettext("chat", "Leaving")
    ChannelHelpers.cleanup_channels(session, quit_reason)

    socket
    |> assign(quit_reason: quit_reason)
    |> clear_reconnect_state()
    |> push_event("intentional_disconnect", %{})
    |> push_navigate(to: Paths.connect_path(socket))
  end

  @spec handle_action_message(Phoenix.LiveView.Socket.t(), Session.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  defdelegate handle_action_message(socket, session, content),
    to: RetroHexChatWeb.ChatLive.Helpers.PM

  # ── Mount helpers ─────────────────────────────────────────

  @spec maybe_start_nickserv_timer(
          Phoenix.LiveView.Socket.t(),
          String.t(),
          boolean(),
          boolean()
        ) :: Phoenix.LiveView.Socket.t()
  def maybe_start_nickserv_timer(socket, nickname, pre_identified \\ false, quiet \\ false) do
    cond do
      pre_identified or NickServ.identified?(nickname) ->
        # A reconnect trusts the signed `pre_identified` session, so re-seed
        # NickServ's in-memory set (wiped by a restart/deploy) too — otherwise it
        # disagrees with the client and downstream checks (virtual spaces, P2P)
        # wrongly deny access.
        NickServ.restore_identified(nickname)

        session =
          socket.assigns.session
          |> Session.set_identified(true)
          |> Persistence.load_persisted_data(nickname)

        socket =
          socket
          |> assign(session: session, muted: SoundSettings.muted?(session.sound_settings))
          |> rebuild_nick_color_fn(session)

        # On a reconnect the identity work still runs, but the greeting is
        # suppressed — the user never left, so re-announcing it is just noise.
        if quiet do
          socket
        else
          Messages.system_event(
            socket,
            dgettext("chat", "You are now identified as %{nickname}", nickname: nickname)
          )
        end

      NickServ.registered?(nickname) ->
        NickServ.start_identify_timer(nickname)

        notice =
          dgettext(
            "chat",
            "[NickServ] This nickname is registered. You have 60 seconds to identify via /ns identify <password> or you will be renamed."
          )

        Messages.service_event(socket, "NickServ", notice)

      true ->
        socket
    end
  end

  @spec maybe_join_channel(Phoenix.LiveView.Socket.t(), String.t() | nil) ::
          Phoenix.LiveView.Socket.t()
  def maybe_join_channel(socket, channel_name)
      when is_binary(channel_name) and channel_name != "" do
    ChannelHelpers.join_channel(socket, channel_name, socket.assigns.session)
  end

  def maybe_join_channel(socket, _channel_name), do: socket

  @spec maybe_trigger_perform(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def maybe_trigger_perform(socket) do
    session = socket.assigns.session

    if PerformList.enabled?(session.perform_list) and
         PerformList.count(session.perform_list) > 0 do
      send(self(), {:execute_perform, 0})
    else
      send(self(), {:execute_autojoin, 0})
    end

    socket
  end

  # Private helpers

  defp fetch_preview_for_url(url) do
    case Scraper.preview(url) do
      {:ok, page} -> send(self(), {:scraped_page, page_announcement(page)})
      :pending -> :ok
      :unknown -> :ok
    end
  end

  @spec page_announcement(RetroHexChat.Scraper.ScrapedPage.t()) :: map()
  defp page_announcement(page) do
    %{url: page.url, url_hash: page.url_hash, status: page.status, title: page.title}
  end
end
