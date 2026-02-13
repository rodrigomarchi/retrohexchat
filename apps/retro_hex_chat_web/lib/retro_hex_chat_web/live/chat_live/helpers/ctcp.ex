defmodule RetroHexChatWeb.ChatLive.Helpers.CTCP do
  @moduledoc """
  CTCP reply handling and rate limiting.
  """

  import Phoenix.Component, only: [assign: 2]

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Chat.{CtcpSettings, FloodProtection}

  @spec maybe_send_ctcp_reply(
          Phoenix.LiveView.Socket.t(),
          Session.t(),
          map(),
          atom(),
          String.t(),
          String.t(),
          integer()
        ) :: Phoenix.LiveView.Socket.t()
  def maybe_send_ctcp_reply(
        socket,
        _session,
        %{enabled: false},
        _type,
        _sender,
        _req_id,
        _sent_at
      ),
      do: socket

  def maybe_send_ctcp_reply(socket, session, _settings, type, sender, req_id, sent_at) do
    flood_settings = session.flood_protection
    reply_limit = FloodProtection.get_ctcp_reply_limit(flood_settings)
    reply_window = FloodProtection.get_ctcp_reply_window_seconds(flood_settings)

    if ctcp_reply_allowed?(socket.assigns.ctcp_reply_tracker, reply_limit, reply_window) do
      socket = record_ctcp_reply(socket)
      value = generate_ctcp_reply_value(session, type)

      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        "user:#{sender}",
        {:ctcp_reply,
         %{
           type: type,
           replier: session.nickname,
           request_id: req_id,
           value: value,
           sent_at: sent_at
         }}
      )

      socket
    else
      socket
    end
  end

  @spec ctcp_reply_allowed?(map(), integer(), integer()) :: boolean()
  def ctcp_reply_allowed?(tracker, limit, window_seconds) do
    now = System.monotonic_time(:millisecond)
    cutoff = now - window_seconds * 1000

    recent =
      Enum.count(tracker.timestamps, fn ts -> ts > cutoff end)

    recent < limit
  end

  # Private helpers

  defp record_ctcp_reply(socket) do
    tracker = socket.assigns.ctcp_reply_tracker
    now = System.monotonic_time(:millisecond)
    new_tracker = %{tracker | timestamps: [now | tracker.timestamps]}
    assign(socket, ctcp_reply_tracker: new_tracker)
  end

  defp generate_ctcp_reply_value(session, type) do
    settings = Session.get_ctcp_settings(session)

    case type do
      :ping ->
        ""

      :version ->
        CtcpSettings.get_version_string(settings)

      :time ->
        Calendar.strftime(DateTime.utc_now(), "%Y-%m-%d %H:%M:%S UTC")

      :finger ->
        case CtcpSettings.get_finger_text(settings) do
          nil ->
            idle_seconds = DateTime.diff(DateTime.utc_now(), session.last_message_at, :second)
            "#{session.nickname} - idle #{format_idle_time(idle_seconds)}"

          custom ->
            custom
        end
    end
  end

  defp format_idle_time(seconds) when seconds < 60, do: "#{seconds} seconds"

  defp format_idle_time(seconds) when seconds < 3600 do
    minutes = div(seconds, 60)
    if minutes == 1, do: "1 minute", else: "#{minutes} minutes"
  end

  defp format_idle_time(seconds) when seconds < 86_400 do
    hours = div(seconds, 3600)
    if hours == 1, do: "1 hour", else: "#{hours} hours"
  end

  defp format_idle_time(seconds) do
    days = div(seconds, 86_400)
    if days == 1, do: "1 day", else: "#{days} days"
  end
end
