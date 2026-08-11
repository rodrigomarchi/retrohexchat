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
  Somebody's presence entry, from the first of `channels` they are found in.

  A person's away state, client and idle time are the same wherever they are
  standing, so any channel both people are in answers the question. The hover
  card and `/whois` both ask it, and both were reaching for the channel's topic
  name to do so.
  """
  @spec find_user(String.t(), [String.t()]) :: map() | nil
  def find_user(nickname, channels) do
    target = String.downcase(nickname)

    Enum.find_value(channels, fn channel ->
      channel
      |> Topics.channel()
      |> list_users()
      |> Enum.find(&(String.downcase(&1.nickname) == target))
    end)
  end

  @spec online?(String.t(), String.t()) :: boolean()
  def online?(topic, nickname) do
    target = String.downcase(nickname)

    topic
    |> list()
    |> Map.keys()
    |> Enum.any?(&(String.downcase(&1) == target))
  end

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
end
