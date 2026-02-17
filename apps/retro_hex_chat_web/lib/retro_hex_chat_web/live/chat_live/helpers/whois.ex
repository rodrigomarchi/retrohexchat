defmodule RetroHexChatWeb.ChatLive.Helpers.Whois do
  @moduledoc """
  Whois and Whowas text output helpers.
  """

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Chat.{TimeFormatter, UserBio}
  alias RetroHexChat.Presence.{Tracker, WhowasCache}
  alias RetroHexChat.Services.NickServ
  alias RetroHexChatWeb.ChatLive.Helpers.Messages

  @spec show_whois_text(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  def show_whois_text(socket, target) do
    session = socket.assigns.session
    target_meta = find_user_presence(target, session.channels)

    if target_meta == nil and target != session.nickname do
      Messages.system_event(socket, "* #{target} is not online.")
    else
      lines = build_whois_lines(socket, session, target, target_meta)

      Enum.reduce(lines, socket, fn line, acc ->
        Messages.system_event(acc, line)
      end)
    end
  end

  @spec show_whowas_text(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  def show_whowas_text(socket, target) do
    case WhowasCache.lookup(target) do
      {:ok, entry} ->
        lines = [
          "----- Whowas: #{entry.nickname} -----",
          "Last seen: #{TimeFormatter.format_relative(entry.disconnected_at)}",
          "Channels: #{Enum.join(entry.channels, ", ")}"
        ]

        lines =
          if entry.quit_message do
            lines ++ ["Quit message: #{entry.quit_message}"]
          else
            lines
          end

        lines = lines ++ ["-----------------------------"]

        Enum.reduce(lines, socket, fn line, acc ->
          Messages.system_event(acc, line)
        end)

      {:error, :not_found} ->
        Messages.system_event(socket, "* No whowas information available for #{target}.")
    end
  end

  # Private helpers

  defp build_whois_lines(socket, session, target, target_meta) do
    data = gather_whois_data(socket, session, target, target_meta)
    format_whois_lines(data, target, session.nickname)
  end

  defp gather_whois_data(socket, session, target, target_meta) do
    is_self = target == session.nickname
    target_channels = get_user_channels(target, session.channels)

    %{
      target_channels: target_channels,
      shared_channels: Enum.filter(target_channels, &(&1 in session.channels)),
      online_seconds: whois_online_seconds(is_self, session, target_meta),
      idle_seconds: whois_idle_seconds(is_self, socket, target_meta),
      registered: NickServ.registered?(target),
      away: target_meta && target_meta[:away],
      away_message: target_meta && target_meta[:away_message],
      bio: whois_bio(is_self, session, target_meta, target)
    }
  end

  defp whois_online_seconds(true, session, _meta), do: seconds_since(session.connected_at)
  defp whois_online_seconds(false, _session, meta), do: seconds_since(meta && meta[:joined_at])

  defp whois_idle_seconds(true, socket, _meta),
    do: seconds_since(socket.assigns.last_activity_at)

  defp whois_idle_seconds(false, _socket, meta),
    do: seconds_since(meta && meta[:last_activity_at])

  defp seconds_since(nil), do: 0
  defp seconds_since(dt), do: DateTime.diff(DateTime.utc_now(), dt, :second)

  defp whois_bio(true, session, _meta, _target), do: Session.get_bio(session)

  defp whois_bio(false, _session, meta, target) do
    presence_bio = meta && meta[:bio]

    presence_bio ||
      case UserBio.load(target) do
        {:ok, text} -> text
        _ -> nil
      end
  end

  defp format_whois_lines(data, target, my_nick) do
    lines = ["----- Whois: #{target} -----"]

    lines =
      maybe_append(
        lines,
        data.target_channels != [],
        "Channels: #{Enum.join(data.target_channels, ", ")}"
      )

    lines =
      maybe_append(
        lines,
        data.shared_channels != [] and target != my_nick,
        "Shared channels: #{Enum.join(data.shared_channels, ", ")}"
      )

    lines = lines ++ ["Online for: #{TimeFormatter.format_duration(data.online_seconds)}"]
    lines = lines ++ ["Idle for: #{TimeFormatter.format_duration(data.idle_seconds)}"]
    lines = lines ++ ["Registered: #{if data.registered, do: "Yes", else: "No"}"]
    lines = maybe_append(lines, data.away, "Away: #{data.away_message || ""}")
    lines = maybe_append(lines, data.bio != nil, "Bio: #{data.bio}")
    lines ++ ["-----------------------------"]
  end

  defp maybe_append(lines, true, line), do: lines ++ [line]
  defp maybe_append(lines, _, _line), do: lines

  defp find_user_presence(target, channels) do
    Enum.find_value(channels, fn channel ->
      users = Tracker.list_users("channel:#{channel}")

      Enum.find(users, fn user ->
        String.downcase(user.nickname) == String.downcase(target)
      end)
    end)
  end

  defp get_user_channels(target, requester_channels) do
    target_lower = String.downcase(target)

    Elixir.Registry.select(RetroHexChat.Channels.ChannelRegistry, [
      {{:"$1", :_, :_}, [], [:"$1"]}
    ])
    |> Enum.filter(&channel_has_member?(&1, target_lower))
    |> Enum.reject(fn channel_name ->
      # Filter out +s (secret) channels unless requester is also a member
      channel_name not in requester_channels and channel_is_secret?(channel_name)
    end)
    |> Enum.sort()
  end

  defp channel_is_secret?(channel_name) do
    case Server.get_state(channel_name) do
      {:ok, state} -> Map.get(state.modes_detail, :secret, false)
      _ -> false
    end
  end

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
end
