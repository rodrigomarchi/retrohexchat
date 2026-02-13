defmodule RetroHexChatWeb.ChatLive.Helpers.Presence do
  @moduledoc """
  Safe wrappers around the Presence Tracker for tracking, untracking,
  and updating user status.
  """

  import Phoenix.Component, only: [assign: 2]

  require Logger

  alias RetroHexChat.Presence.Tracker

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

    Enum.each(session.channels, fn channel ->
      safe_update_activity("channel:#{channel}", session.nickname)
    end)

    assign(socket, last_activity_at: now)
  end
end
