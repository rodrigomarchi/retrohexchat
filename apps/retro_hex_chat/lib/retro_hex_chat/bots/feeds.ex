defmodule RetroHexChat.Bots.Feeds do
  @moduledoc """
  The feed list of a bot's RSS capability, as an administrator manages it.

  The same list the `!Bot rss` commands manipulate, reached from the admin
  dialog instead of from a channel. Both write to `bot.capabilities["rss"]`,
  which is the copy that survives a restart, and both tell the running bot to
  pick up the change so a feed added here starts polling without a redeploy.
  """

  alias RetroHexChat.Bots.Capabilities.RSS
  alias RetroHexChat.Bots.Capabilities.RSS.Scheduler
  alias RetroHexChat.Bots.Capabilities.RSS.UrlGuard
  alias RetroHexChat.Bots.{Queries, Server}

  @cap "rss"

  @type feed :: map()

  @doc "Every feed configured on this bot, in the order they were added."
  @spec list(map()) :: [feed()]
  def list(bot) do
    get_in(bot.capabilities, [@cap, "feeds"]) || []
  end

  @doc """
  Adds a feed, refusing an address the server should not be fetching.

  A newly added feed carries no memory of what it has seen, which is what
  makes its first poll silent: it records the page as it stands and announces
  only what appears afterwards.
  """
  @spec add(map(), String.t(), String.t()) :: {:ok, map()} | {:error, String.t()}
  def add(bot, url, channel) do
    url = String.trim(url)
    channel = channel |> String.trim() |> ensure_hash()

    with :ok <- UrlGuard.check(url),
         :ok <- check_channel(channel),
         :ok <- check_membership(bot, channel),
         :ok <- check_room(bot) do
      feed = %{
        "id" => generate_id(),
        "url" => url,
        "channel" => channel,
        "title" => nil,
        "seen" => [],
        "etag" => nil,
        "last_modified" => nil,
        "last_polled_at" => nil,
        "last_error" => nil
      }

      write(bot, list(bot) ++ [feed])
    end
  end

  @doc "Removes a feed by id. Its poll stops with it."
  @spec remove(map(), String.t()) :: {:ok, map()} | {:error, String.t()}
  def remove(bot, feed_id) do
    feeds = list(bot)

    if Enum.any?(feeds, &(&1["id"] == feed_id)) do
      with {:ok, updated} <- write(bot, Enum.reject(feeds, &(&1["id"] == feed_id))) do
        Scheduler.cancel_poll(updated.id, feed_id)
        {:ok, updated}
      end
    else
      {:error, "no feed with that id"}
    end
  end

  @spec check_channel(String.t()) :: :ok | {:error, String.t()}
  defp check_channel("#"), do: {:error, "name the channel the feed should post to"}
  defp check_channel(_), do: :ok

  # A feed pointed at a room the bot has not joined publishes into a void: the
  # channel refuses the message, the failure reaches a log nobody is reading, and
  # the feed looks healthy. Better to refuse the arrangement while someone is
  # looking at it.
  @spec check_membership(map(), String.t()) :: :ok | {:error, String.t()}
  defp check_membership(bot, channel) do
    joined = Enum.map(Queries.list_channel_configs(bot.id), & &1.channel_name)

    if channel in joined do
      :ok
    else
      {:error, "#{bot.name} is not in #{channel} — add the channel to the bot first"}
    end
  end

  @spec check_room(map()) :: :ok | {:error, String.t()}
  defp check_room(bot) do
    max = get_in(bot.capabilities, [@cap, "max_feeds"]) || RSS.default_config()["max_feeds"]

    if length(list(bot)) >= max do
      {:error, "this bot already carries its maximum of #{max} feeds"}
    else
      :ok
    end
  end

  # Stored first, then announced to the process: if the write fails there is
  # nothing to undo, and if the bot is not running the feed is still waiting for
  # it at boot.
  @spec write(map(), [feed()]) :: {:ok, map()} | {:error, String.t()}
  defp write(bot, feeds) do
    rss = Map.merge(existing_config(bot), %{"feeds" => feeds})
    capabilities = Map.put(bot.capabilities, @cap, rss)

    case Queries.update_bot(bot, %{capabilities: capabilities}) do
      {:ok, updated} ->
        reload(updated)
        {:ok, updated}

      {:error, _changeset} ->
        {:error, "could not save the feed"}
    end
  end

  @spec existing_config(map()) :: map()
  defp existing_config(bot) do
    Map.get(bot.capabilities, @cap) || Map.put(RSS.default_config(), "feeds", [])
  end

  @spec reload(map()) :: :ok
  defp reload(bot) do
    Server.reload_capabilities(bot.nickname, bot.capabilities)
  catch
    :exit, _ -> :ok
  end

  @spec ensure_hash(String.t()) :: String.t()
  defp ensure_hash("#" <> _ = channel), do: channel
  defp ensure_hash(channel), do: "#" <> channel

  @spec generate_id() :: String.t()
  defp generate_id, do: "f" <> (:crypto.strong_rand_bytes(3) |> Base.encode16(case: :lower))
end
