defmodule RetroHexChat.Presence.Tracker do
  @moduledoc """
  Phoenix Presence-based user tracking.
  Tracks online users per channel with metadata (away status, etc.).
  """
  use Phoenix.Presence,
    otp_app: :retro_hex_chat,
    pubsub_server: RetroHexChat.PubSub

  @spec track_user(String.t(), String.t(), map()) :: {:ok, binary()} | {:error, any()}
  def track_user(topic, nickname, meta \\ %{}) do
    default_meta = %{
      nickname: nickname,
      away: false,
      away_message: nil,
      joined_at: DateTime.utc_now()
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

  @spec update_away(String.t(), String.t(), boolean(), String.t() | nil) ::
          {:ok, binary()} | {:error, any()}
  def update_away(topic, nickname, away, message \\ nil) do
    update(self(), topic, nickname, fn meta ->
      %{meta | away: away, away_message: message}
    end)
  end
end
