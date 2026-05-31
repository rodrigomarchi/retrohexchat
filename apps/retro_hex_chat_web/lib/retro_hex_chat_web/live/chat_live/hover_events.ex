defmodule RetroHexChatWeb.ChatLive.HoverEvents do
  @moduledoc """
  Handle interactive element events: channel hover/click, nick hover/dismiss/dblclick.

  Attached as `attach_hook(:hover_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Chat.{IgnoreList, TimeFormatter}
  alias RetroHexChat.Presence.Tracker
  alias RetroHexChat.Services.NickServ
  alias RetroHexChatWeb.ChatLive.Helpers.Channel, as: ChannelHelper
  alias RetroHexChatWeb.ChatLive.Helpers.PM

  @default_hover_card %{visible: false, nick: nil, x: 0, y: 0, loading: false, data: nil}

  @spec default_hover_card() :: map()
  def default_hover_card, do: @default_hover_card

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
      # Show loading state immediately, then populate with data
      socket =
        socket
        |> assign(
          hover_card: %{
            @default_hover_card
            | visible: true,
              nick: nick,
              x: x,
              y: y,
              loading: true
          }
        )
        |> populate_hover_card(nick)

      {:halt, socket}
    end
  end

  # -- nick_hover_dismiss --

  def handle_event("nick_hover_dismiss", _params, socket) do
    {:halt, assign(socket, hover_card: @default_hover_card)}
  end

  # -- nick_dblclick --

  def handle_event("nick_dblclick", %{"nick" => nick}, socket) do
    {:halt,
     socket
     |> assign(hover_card: @default_hover_card)
     |> PM.open_pm_conversation(nick)}
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

  @spec populate_hover_card(Phoenix.LiveView.Socket.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  defp populate_hover_card(socket, nick) do
    session = socket.assigns.session
    target_meta = find_user_presence(nick, session.channels)

    data =
      %{
        nickname: nick,
        hostname: target_meta && target_meta[:hostname],
        online_for: format_online_time(target_meta),
        channels: get_visible_channels(nick, session.channels),
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

    hover_card = socket.assigns.hover_card
    assign(socket, hover_card: Map.merge(hover_card, hover_card_fields(data)))
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

  @spec extract_client_fields(map() | nil) :: map()
  defp extract_client_fields(nil), do: %{}

  defp extract_client_fields(meta) do
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

  @spec find_user_presence(String.t(), [String.t()]) :: map() | nil
  defp find_user_presence(target, channels) do
    Enum.find_value(channels, fn channel ->
      users = Tracker.list_users("channel:#{channel}")

      Enum.find(users, fn user ->
        String.downcase(user.nickname) == String.downcase(target)
      end)
    end)
  end

  @spec get_visible_channels(String.t(), [String.t()]) :: [String.t()]
  defp get_visible_channels(target, requester_channels) do
    target_lower = String.downcase(target)

    Elixir.Registry.select(RetroHexChat.Channels.ChannelRegistry, [
      {{:"$1", :_, :_}, [], [:"$1"]}
    ])
    |> Enum.filter(&channel_has_member?(&1, target_lower))
    |> Enum.reject(fn channel_name ->
      channel_name not in requester_channels and channel_is_secret?(channel_name)
    end)
    |> Enum.sort()
  end

  @spec channel_is_secret?(String.t()) :: boolean()
  defp channel_is_secret?(channel_name) do
    case Server.get_state(channel_name) do
      {:ok, state} -> Map.get(state.modes_detail, :secret, false)
      _ -> false
    end
  end

  @spec channel_has_member?(String.t(), String.t()) :: boolean()
  defp channel_has_member?(channel_name, target_lower) do
    case Server.get_state(channel_name) do
      {:ok, state} ->
        Enum.any?(state.members, fn {nick, _role} ->
          String.downcase(nick) == target_lower
        end)

      _ ->
        false
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
