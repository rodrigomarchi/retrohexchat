defmodule RetroHexChatWeb.ChatLive.Helpers.Presence do
  @moduledoc """
  Safe wrappers around the Presence Tracker for tracking, untracking,
  and updating user status.

  A session is present in two places at once: on each channel it joined, and on
  the server-wide topic it is tracked on from mount to disconnect. Anything that
  describes the person rather than their membership — away, bio, last activity —
  belongs on both, because the questions asked of it are not all channel-shaped:
  a private conversation, a hover card or a `/whois` about someone you share no
  channel with has only the server-wide entry to read. Writing one and not the
  other left that entry frozen at its connect-time defaults.

  So the writes are published from here, per session, rather than looped over
  `session.channels` by each caller.
  """

  import Phoenix.Component, only: [assign: 2]

  require Logger

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Presence.Tracker
  alias RetroHexChat.Topics

  @spec safe_track_user(String.t(), String.t(), map()) :: :ok
  def safe_track_user(topic, nickname, extra_meta \\ %{}) do
    case Tracker.track_user(topic, nickname, extra_meta) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.warning("Tracker.track_user(#{topic}, #{nickname}): #{inspect(reason)}")
    end
  end

  @spec safe_untrack_user(String.t(), String.t()) :: :ok
  def safe_untrack_user(topic, nickname) do
    Tracker.untrack_user(topic, nickname)
  rescue
    e -> Logger.warning("Tracker.untrack_user(#{topic}, #{nickname}): #{inspect(e)}")
  end

  @spec safe_update_away(String.t(), String.t(), boolean(), String.t() | nil) :: :ok
  def safe_update_away(topic, nickname, away, message) do
    case Tracker.update_away(topic, nickname, away, message) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.warning("Tracker.update_away(#{topic}, #{nickname}): #{inspect(reason)}")
    end
  end

  @spec safe_update_activity(String.t(), String.t()) :: :ok
  def safe_update_activity(topic, nickname) do
    case Tracker.update_activity(topic, nickname) do
      {:ok, _} ->
        :ok

      {:error, :nopresence} ->
        :ok

      {:error, reason} ->
        Logger.debug("Tracker.update_activity(#{topic}, #{nickname}): #{inspect(reason)}")
    end
  end

  @spec safe_update_bio(String.t(), String.t(), String.t() | nil) :: :ok
  def safe_update_bio(topic, nickname, bio) do
    case Tracker.update_bio(topic, nickname, bio) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.warning("Tracker.update_bio(#{topic}, #{nickname}): #{inspect(reason)}")
    end
  end

  @spec reset_activity(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def reset_activity(socket) do
    session = socket.assigns.session
    now = DateTime.utc_now()

    Enum.each(session_topics(session), &safe_update_activity(&1, session.nickname))

    assign(socket, last_activity_at: now)
  end

  @doc """
  Records an away change everywhere this session is present, and tells both
  audiences about it.

  The channels hear a `:user_away_changed` naming the channel, which is what
  their rosters key on. The server-wide topic hears a `:user_presence_changed`
  under a name of its own: a channel-less `:user_away_changed` would satisfy the
  channel handler's "no channel means the active one" clause and make every
  session in the server rebuild a roster the change never touched.
  """
  @spec publish_away(Session.t(), boolean(), String.t() | nil) :: :ok
  def publish_away(%Session{} = session, away, message) do
    Enum.each(session_topics(session), &safe_update_away(&1, session.nickname, away, message))

    Enum.each(session.channels, fn channel ->
      broadcast(
        Topics.channel(channel),
        {:user_away_changed,
         %{
           channel: channel,
           nickname: session.nickname,
           away: away,
           away_message: message
         }}
      )
    end)

    broadcast(
      Topics.presence(),
      {:user_presence_changed, %{nickname: session.nickname, away: away, away_message: message}}
    )
  end

  @doc "Records a bio change everywhere this session is present."
  @spec publish_bio(Session.t(), String.t() | nil) :: :ok
  def publish_bio(%Session{} = session, bio) do
    Enum.each(session_topics(session), &safe_update_bio(&1, session.nickname, bio))
  end

  @doc "Every presence topic this session is tracked on."
  @spec session_topics(Session.t()) :: [String.t()]
  def session_topics(%Session{channels: channels}) do
    [Topics.presence() | Enum.map(channels || [], &Topics.channel/1)]
  end

  defp broadcast(topic, message) do
    Phoenix.PubSub.broadcast(RetroHexChat.PubSub, topic, message)
  end
end
