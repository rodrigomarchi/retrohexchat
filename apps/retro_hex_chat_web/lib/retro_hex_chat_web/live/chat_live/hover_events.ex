defmodule RetroHexChatWeb.ChatLive.HoverEvents do
  @moduledoc """
  Handle interactive element events: channel hover/click, nick hover/dismiss/dblclick.

  The nick hover card's state lives in `Components.HoverCard`; this module gathers
  the presence/registration/contact data (it has the `session`) and pushes the
  finished map to that component via `send_update/2`.

  Attached as `attach_hook(:hover_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3, send_update: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Channels.Visibility
  alias RetroHexChat.Chat.{IgnoreList, TimeFormatter}
  alias RetroHexChat.Presence.Tracker
  alias RetroHexChat.Services.NickServ
  alias RetroHexChatWeb.ChatLive.Components.HoverCard
  alias RetroHexChatWeb.ChatLive.Helpers.Channel, as: ChannelHelper
  alias RetroHexChatWeb.ChatLive.Helpers.PM

  # -- channel_hover --

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:halt, Phoenix.LiveView.Socket.t()} | {:cont, Phoenix.LiveView.Socket.t()}
  def handle_event("channel_hover", %{"channel" => channel}, socket) do
    {count, joined} = channel_info(channel, socket.assigns.session)

    {:halt,
     push_event(socket, "channel_tooltip", %{channel: channel, count: count, joined: joined})}
  end

  # -- channel_click --

  def handle_event("channel_click", %{"channel" => channel}, socket) do
    session = socket.assigns.session

    if channel in session.channels do
      # Already joined — switch to it
      new_session = Session.set_active_channel(session, channel)

      {:halt,
       socket
       |> assign(session: new_session, show_status_tab: false)
       |> ChannelHelper.load_channel_users(channel)
       |> ChannelHelper.load_channel_messages_with_pagination(channel)}
    else
      {:halt, ChannelHelper.join_channel(socket, channel, session)}
    end
  end

  # -- nick_hover --

  def handle_event("nick_hover", %{"nick" => nick, "x" => x, "y" => y}, socket) do
    session = socket.assigns.session

    # FR-014: suppress own nick hover card
    if nick == session.nickname do
      {:halt, socket}
    else
      send_update(HoverCard,
        id: HoverCard.id(),
        action: {:set, build_hover_card(session, nick, x, y)}
      )

      {:halt, socket}
    end
  end

  # -- nick_hover_dismiss --

  def handle_event("nick_hover_dismiss", _params, socket) do
    send_update(HoverCard, id: HoverCard.id(), action: :dismiss)
    {:halt, socket}
  end

  # -- nick_dblclick --

  def handle_event("nick_dblclick", %{"nick" => nick}, socket) do
    send_update(HoverCard, id: HoverCard.id(), action: :dismiss)
    {:halt, PM.open_pm_conversation(socket, nick)}
  end

  # Unmatched events — pass through
  def handle_event(_event, _params, socket), do: {:cont, socket}

  # -- Private helpers --

  @spec channel_info(String.t(), Session.t()) :: {non_neg_integer(), boolean()}
  defp channel_info(channel, session) do
    count =
      case Server.get_state(channel) do
        {:ok, state} -> state.member_count
        {:error, _} -> 0
      end

    joined = channel in session.channels
    {count, joined}
  end

  # Resolves all presence/registration/contact fields for `nick` and returns the
  # full hover-card map the component renders (no socket — pure, sent via :set).
  @spec build_hover_card(Session.t(), String.t(), integer(), integer()) :: map()
  defp build_hover_card(session, nick, x, y) do
    target_meta = Tracker.find_user(nick, session.channels)

    data =
      %{
        nickname: nick,
        hostname: target_meta && target_meta[:hostname],
        online_for: format_online_time(target_meta),
        channels: Visibility.channels_of(nick, session.channels),
        away: (target_meta && target_meta[:away]) || false,
        away_message: target_meta && target_meta[:away_message],
        registered: NickServ.registered?(nick),
        idle: format_idle_time(target_meta),
        role: get_role_in_active_channel(nick, session.active_channel),
        is_contact: contact?(nick, session.contacts),
        contact_note: contact_note(nick, session.contacts),
        is_ignored: IgnoreList.get_entry(session.ignore_list, nick) != nil
      }
      |> Map.merge(extract_client_fields(target_meta))

    base = %{HoverCard.default() | visible: true, nick: nick, x: x, y: y, loading: true}
    Map.merge(base, hover_card_fields(data))
  end

  defp hover_card_fields(data) do
    %{
      loading: false,
      data: data,
      away: if(data.away, do: data.away_message || dgettext("chat", "Away")),
      host: data.hostname,
      registered: data.registered,
      online_for: data.online_for,
      idle: data.idle,
      channels: data.channels,
      browser: data.browser,
      os: data.os,
      screen_resolution: data.screen,
      language: data.language,
      timezone_info: data.client_timezone,
      role: hover_role(data.role),
      is_contact: data.is_contact,
      contact_note: data.contact_note,
      is_ignored: data.is_ignored
    }
  end

  # Total for nil meta (offline/untracked nick): every client field must be
  # present — hover_card_fields/1 reads them with dot access, and a missing key
  # crashes the whole LiveView session.
  @spec extract_client_fields(map() | nil) :: map()
  defp extract_client_fields(meta) do
    meta = meta || %{}

    %{
      browser: meta[:browser],
      os: meta[:os],
      language: meta[:language],
      screen: meta[:screen],
      client_timezone: meta[:timezone]
    }
  end

  @spec format_online_time(map() | nil) :: String.t()
  defp format_online_time(nil), do: dgettext("chat", "Unknown")

  defp format_online_time(meta) do
    joined_at = meta[:joined_at] || meta[:connected_at]

    if joined_at do
      seconds = DateTime.diff(DateTime.utc_now(), joined_at, :second)
      TimeFormatter.format_duration(seconds)
    else
      dgettext("chat", "Unknown")
    end
  end

  @spec format_idle_time(map() | nil) :: String.t()
  defp format_idle_time(nil), do: dgettext("chat", "Unknown")

  defp format_idle_time(meta) do
    case meta[:last_activity_at] do
      nil ->
        dgettext("chat", "Unknown")

      last_activity_at ->
        seconds = DateTime.diff(DateTime.utc_now(), last_activity_at, :second)
        TimeFormatter.format_duration(seconds)
    end
  end

  @spec get_role_in_active_channel(String.t(), String.t() | nil) :: atom() | nil
  defp get_role_in_active_channel(_nick, nil), do: nil

  defp get_role_in_active_channel(nick, channel) do
    with {:ok, state} <- Server.get_state(channel),
         nick_lower = String.downcase(nick),
         {_nick, role} <-
           Enum.find(state.members, fn {m, _} -> String.downcase(m) == nick_lower end) do
      role
    else
      _ -> nil
    end
  end

  defp hover_role(role) when role in [:owner, :operator, :half_operator, :voiced, :bot], do: role
  defp hover_role(_role), do: nil

  @spec contact?(String.t(), map()) :: boolean()
  defp contact?(nick, contacts) do
    find_contact(nick, contacts) != nil
  end

  defp contact_note(nick, contacts) do
    case find_contact(nick, contacts) do
      nil -> nil
      entry -> entry.note
    end
  end

  defp find_contact(nick, contacts) do
    nick_lower = String.downcase(nick)

    Enum.find(contacts.entries, &(String.downcase(&1.contact_nickname) == nick_lower))
  end
end
