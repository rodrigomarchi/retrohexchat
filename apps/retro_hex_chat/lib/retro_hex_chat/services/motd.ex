defmodule RetroHexChat.Services.Motd do
  @moduledoc """
  Manages the Message of the Day (MOTD) with in-memory cache.
  Uses Application env for caching to avoid a DB query on every connection.
  """

  alias RetroHexChat.Services.Queries

  @cache_key :motd_cache
  @pubsub RetroHexChat.PubSub
  @topic "server:settings"

  @spec get() :: String.t() | nil
  def get do
    case Application.get_env(:retro_hex_chat, @cache_key) do
      nil -> load_from_db()
      :unset -> nil
      value -> value
    end
  end

  @spec set(String.t(), String.t()) :: :ok | {:error, String.t()}
  def set(content, admin_nickname) do
    case Queries.upsert_setting("motd", content, admin_nickname) do
      {:ok, _} ->
        Application.put_env(:retro_hex_chat, @cache_key, content)
        Phoenix.PubSub.broadcast(@pubsub, @topic, {:motd_updated, %{content: content}})
        :ok

      {:error, _changeset} ->
        {:error, "Failed to save MOTD."}
    end
  end

  @spec clear(String.t()) :: :ok
  def clear(admin_nickname) do
    Queries.delete_setting("motd")
    Application.put_env(:retro_hex_chat, @cache_key, :unset)

    Phoenix.PubSub.broadcast(@pubsub, @topic, {:motd_updated, %{content: nil}})

    _ = admin_nickname
    :ok
  end

  @spec init_cache() :: :ok
  def init_cache do
    case Queries.get_setting("motd") do
      nil -> Application.put_env(:retro_hex_chat, @cache_key, :unset)
      value -> Application.put_env(:retro_hex_chat, @cache_key, value)
    end

    :ok
  end

  defp load_from_db do
    value = Queries.get_setting("motd")
    cache_value = if value, do: value, else: :unset
    Application.put_env(:retro_hex_chat, @cache_key, cache_value)
    value
  end
end
