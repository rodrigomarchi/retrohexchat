defmodule RetroHexChat.Presence.Tracker do
  @moduledoc """
  Phoenix Presence-based user tracking.
  Tracks online users per channel with metadata (away status, etc.).
  """
  use Phoenix.Presence,
    otp_app: :retro_hex_chat,
    pubsub_server: RetroHexChat.PubSub

  alias RetroHexChat.Topics

  @spec track_user(String.t(), String.t(), map()) :: {:ok, binary()} | {:error, any()}
  def track_user(topic, nickname, meta \\ %{}) do
    default_meta = %{
      nickname: nickname,
      away: false,
      away_message: nil,
      joined_at: DateTime.utc_now(),
      last_activity_at: DateTime.utc_now()
    }

    track(self(), topic, nickname, Map.merge(default_meta, meta))
  end

  @spec untrack_user(String.t(), String.t()) :: :ok
  def untrack_user(topic, nickname) do
    untrack(self(), topic, nickname)
  end

  @spec list_users(String.t()) :: [map()]
  def list_users(topic) do
    topic
    |> list()
    |> Enum.map(fn {nickname, %{metas: [meta | _]}} ->
      Map.put(meta, :nickname, nickname)
    end)
  end

  @doc """
  Somebody's presence entry, wherever it can be found.

  A person's away state, client and idle time are the same wherever they are
  standing, so the server-wide entry answers the question — including for
  somebody you share no channel with, which is what the hover card and `/whois`
  used to go blank on. `channels` stays as the fallback for an entry that
  predates the current tracking.
  """
  @spec find_user(String.t(), [String.t()]) :: map() | nil
  def find_user(nickname, channels) do
    meta(Topics.presence(), nickname) || find_user_in_channels(nickname, channels)
  end

  @spec find_user_in_channels(String.t(), [String.t()]) :: map() | nil
  defp find_user_in_channels(nickname, channels) do
    Enum.find_value(channels, fn channel ->
      channel
      |> Topics.channel()
      |> meta(nickname)
    end)
  end

  @doc """
  One person's presence entry on `topic`, or `nil` when they are not on it.

  Keyed straight off the presence table. `list_users/1` materializes every meta
  on the topic, which is the wrong shape for a question about one nickname —
  `presence:global` holds the whole server.

  A nickname is tracked under the case it connected with, so a lookup that
  misses falls back to a case-insensitive scan: a nick read back from a stored
  conversation or typed into a command does not have to match that case.
  """
  @spec meta(String.t(), String.t()) :: map() | nil
  def meta(topic, nickname) do
    case get_by_key(topic, nickname) do
      %{metas: [meta | _rest]} -> Map.put(meta, :nickname, nickname)
      _missing -> scan_for_meta(topic, nickname)
    end
  end

  @spec online?(String.t(), String.t()) :: boolean()
  def online?(topic, nickname), do: meta(topic, nickname) != nil

  @spec update_away(String.t(), String.t(), boolean(), String.t() | nil) ::
          {:ok, binary()} | {:error, any()}
  def update_away(topic, nickname, away, message \\ nil) do
    update(self(), topic, nickname, fn meta ->
      %{meta | away: away, away_message: message}
    end)
  end

  @spec update_activity(String.t(), String.t()) :: {:ok, binary()} | {:error, any()}
  def update_activity(topic, nickname) do
    update(self(), topic, nickname, fn meta ->
      Map.put(meta, :last_activity_at, DateTime.utc_now())
    end)
  end

  @spec update_bio(String.t(), String.t(), String.t() | nil) ::
          {:ok, binary()} | {:error, any()}
  def update_bio(topic, nickname, bio) do
    update(self(), topic, nickname, fn meta ->
      Map.put(meta, :bio, bio)
    end)
  end

  @spec scan_for_meta(String.t(), String.t()) :: map() | nil
  defp scan_for_meta(topic, nickname) do
    target = String.downcase(nickname)

    topic
    |> list_users()
    |> Enum.find(&(String.downcase(&1.nickname) == target))
  end
end
