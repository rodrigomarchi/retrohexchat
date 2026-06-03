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
    Highlight,
    LinkPreview,
    PerformList,
    SoundSettings,
    URLDetector
  }

  alias RetroHexChat.Services.NickServ
  alias RetroHexChatWeb.ChatLive.Helpers.Channel, as: ChannelHelpers
  alias RetroHexChatWeb.ChatLive.Helpers.Messages
  alias RetroHexChatWeb.ChatLive.Helpers.PathHelpers
  alias RetroHexChatWeb.ChatLive.Helpers.Persistence
  alias RetroHexChatWeb.ChatLive.Helpers.PM
  alias RetroHexChatWeb.ChatLive.Helpers.Presence, as: PresenceHelpers

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
    assign(socket, nick_color_fn: build_nick_color_fn(session))
  end

  @spec refresh_active_message_stream(Phoenix.LiveView.Socket.t(), Session.t()) ::
          Phoenix.LiveView.Socket.t()
  def refresh_active_message_stream(socket, session) do
    limit = max(socket.assigns[:loaded_message_count] || 50, 50)

    cond do
      present?(session.active_pm) ->
        PM.load_pm_messages_with_pagination(socket, session.active_pm, limit)

      present?(session.active_channel) ->
        ChannelHelpers.load_channel_messages_with_pagination(
          socket,
          session.active_channel,
          limit
        )

      true ->
        socket
    end
  end

  # ── URL capture ────────────────────────────────────────────

  @spec capture_urls(Phoenix.LiveView.Socket.t(), String.t(), String.t(), atom(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  def capture_urls(socket, content, source, source_type, author) do
    urls = URLDetector.extract_urls(content)

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

      socket
      |> assign(url_catcher_entries: new_entries ++ socket.assigns.url_catcher_entries)
      |> maybe_fetch_previews(urls)
    end
  end

  @spec maybe_fetch_previews(Phoenix.LiveView.Socket.t(), [String.t()]) ::
          Phoenix.LiveView.Socket.t()
  def maybe_fetch_previews(socket, urls) do
    lv_pid = self()
    Enum.each(urls, &fetch_preview_for_url(&1, lv_pid))
    socket
  end

  @spec spawn_preview_fetch(String.t(), pid()) :: :ok | Task.t()
  def spawn_preview_fetch(url, lv_pid) do
    unless LinkPreview.Cache.pending?(url) do
      LinkPreview.Cache.mark_pending(url)

      Task.Supervisor.async_nolink(RetroHexChat.LinkPreviewTasks, fn ->
        result = LinkPreview.HTTP.fetch_title(url)
        send(lv_pid, {:link_preview_result, url, result})
      end)
    end
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

    if sound == "none" do
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

  # ── Session / Reconnect ────────────────────────────────────

  @spec push_reconnect_state(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def push_reconnect_state(socket) do
    session = socket.assigns.session

    push_event(socket, "save_reconnect_state", %{
      nickname: session.nickname,
      channels: session.channels,
      active_channel: session.active_channel,
      active_pm: session.active_pm,
      welcomed_channels: MapSet.to_list(session.welcomed_channels || MapSet.new())
    })
  end

  @spec restore_session(Phoenix.LiveView.Socket.t(), map()) :: Phoenix.LiveView.Socket.t()
  def restore_session(socket, params) do
    restored_nick = Map.get(params, "nickname")
    current_nick = socket.assigns.session.nickname

    if restored_nick != nil and restored_nick != current_nick do
      Logger.info(
        "Ignoring reconnect state from different user: #{restored_nick} != #{current_nick}"
      )

      socket
    else
      do_restore_session(socket, params)
    end
  end

  defp do_restore_session(socket, params) do
    channels = Map.get(params, "channels", [])
    active_channel = Map.get(params, "active_channel")
    active_pm = Map.get(params, "active_pm")

    socket =
      socket
      |> restore_welcomed_channels(Map.get(params, "welcomed_channels", []))
      |> assign(reconnect_active_channel: active_channel, reconnect_active_pm: active_pm)
      |> Messages.system_event(dgettext("chat", "* Restoring session..."))

    if channels != [] do
      Process.send_after(self(), {:execute_rejoin, 0, channels}, 200)
    end

    socket
  end

  defp restore_welcomed_channels(socket, channels) when is_list(channels) do
    session =
      Enum.reduce(channels, socket.assigns.session, fn
        channel, session when is_binary(channel) ->
          Session.add_welcomed_channel(session, channel)

        _other, session ->
          session
      end)

    assign(socket, session: session)
  end

  defp restore_welcomed_channels(socket, _channels), do: socket

  # ── Context menu ───────────────────────────────────────────

  @spec close_context_menu(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def close_context_menu(socket) do
    assign(socket,
      context_menu: %{visible: false, x: 0, y: 0, target_nick: nil},
      show_context_color_picker: false,
      conversations_context_menu: %{
        visible: false,
        x: 0,
        y: 0,
        type: nil,
        channel: nil,
        nick: nil
      }
    )
  end

  # ── Highlight ──────────────────────────────────────────────

  @spec maybe_highlight(map(), Session.t()) :: map()
  def maybe_highlight(%{type: type} = payload, session)
      when type in [:message, :action] do
    words = Session.get_highlight_words(session).entries

    case Highlight.check(
           payload.content,
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
             "channel:#{channel}",
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

    Enum.each(session.channels, fn channel ->
      PresenceHelpers.safe_untrack_user("channel:#{channel}", old_nick)
      PresenceHelpers.safe_track_user("channel:#{channel}", new_nick, client_meta)
    end)

    Phoenix.PubSub.unsubscribe(RetroHexChat.PubSub, "user:#{old_nick}")
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "user:#{new_nick}")

    users =
      Enum.map(socket.assigns.channel_users, fn user ->
        if user.nickname == old_nick, do: %{user | nickname: new_nick}, else: user
      end)

    socket
    |> Messages.system_event(
      dgettext("chat", "You are now known as %{nickname}", nickname: new_nick)
    )
    |> assign(session: session, channel_users: users)
  end

  @spec handle_quit(Phoenix.LiveView.Socket.t(), String.t() | nil) :: Phoenix.LiveView.Socket.t()
  def handle_quit(socket, reason) do
    session = socket.assigns.session
    quit_reason = reason || dgettext("chat", "Leaving")
    ChannelHelpers.cleanup_channels(session, quit_reason)

    socket
    |> assign(quit_reason: quit_reason)
    |> push_event("intentional_disconnect", %{})
    |> push_navigate(to: PathHelpers.connect_path(socket))
  end

  @spec handle_set_away(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  def handle_set_away(socket, message) do
    session = Session.set_away(socket.assigns.session, message)

    Enum.each(session.channels, fn channel ->
      PresenceHelpers.safe_update_away("channel:#{channel}", session.nickname, true, message)
    end)

    socket
    |> Messages.system_event(dgettext("chat", "You are now away: %{message}", message: message))
    |> assign(session: session)
  end

  @spec handle_action_message(Phoenix.LiveView.Socket.t(), Session.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  defdelegate handle_action_message(socket, session, content),
    to: RetroHexChatWeb.ChatLive.Helpers.PM

  # ── Mount helpers ─────────────────────────────────────────

  @spec maybe_start_nickserv_timer(Phoenix.LiveView.Socket.t(), String.t(), boolean()) ::
          Phoenix.LiveView.Socket.t()
  def maybe_start_nickserv_timer(socket, nickname, pre_identified \\ false) do
    cond do
      pre_identified or NickServ.identified?(nickname) ->
        session =
          socket.assigns.session
          |> Session.set_identified(true)
          |> Persistence.load_persisted_data(nickname)

        socket
        |> assign(session: session)
        |> rebuild_nick_color_fn(session)
        |> Messages.system_event(
          dgettext("chat", "You are now identified as %{nickname}", nickname: nickname)
        )

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

  defp fetch_preview_for_url(url, lv_pid) do
    case LinkPreview.Cache.get(url) do
      {:ok, :error} -> :ok
      {:ok, title} -> send(lv_pid, {:link_preview_result, url, {:ok, title}})
      :miss -> spawn_preview_fetch(url, lv_pid)
    end
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_value), do: false
end
