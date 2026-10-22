defmodule RetroHexChat.Bots.Feeds do
  @moduledoc """
  The feed list of a bot's RSS capability, as an administrator manages it.

  The same list the `!Bot rss` commands manipulate, reached from the admin
  dialog instead of from a channel. Both write to `bot.capabilities["rss"]`,
  which is the copy that survives a restart, and both tell the running bot to
  pick up the change so a feed added here starts polling without a redeploy.
  """

  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Bots.Capabilities.RSS
  alias RetroHexChat.Bots.Capabilities.RSS.Scheduler
  alias RetroHexChat.Bots.{Lifecycle, Queries}
  alias RetroHexChat.Channels.Name
  alias RetroHexChat.Net.URLGuard

  require Logger

  @cap "rss"

  @type feed :: map()

  @doc "Every feed configured on this bot, in the order they were added."
  @spec list(map()) :: [feed()]
  def list(bot) do
    get_in(bot.capabilities, [@cap, "feeds"]) || []
  end

  @doc """
  Adds a feed, refusing an address the server should not be fetching.

  A newly added feed carries no memory of what it has seen, so its first poll
  publishes the current page, records it, and then announces only what appears
  afterwards.
  """
  @spec add(map(), String.t(), String.t()) :: {:ok, map()} | {:error, String.t()}
  def add(bot, url, channel) do
    request = %{
      bot_name: bot.name,
      joined_channels: Enum.map(Queries.list_channel_configs(bot.id), & &1.channel_name),
      feeds: list(bot),
      max_feeds: max_feeds(bot.capabilities[@cap] || %{})
    }

    with {:ok, feed} <- build(request, url, channel) do
      write(bot, list(bot) ++ [feed])
    end
  end

  @typedoc "What a new feed is checked against: the bot, where it is, what it carries."
  @type build_request :: %{
          bot_name: String.t(),
          joined_channels: [String.t()],
          feeds: [feed()],
          max_feeds: pos_integer()
        }

  @doc """
  A new feed for `url` posting to `channel`, or the reason it is refused.

  The one set of checks for every way a feed is added — the admin dialog and
  `!Bot rss add` alike: the address must be fetchable, the channel named, the
  bot already in it, and the bot below its feed limit. Refusals are worded for
  the person adding it.
  """
  @spec build(build_request(), String.t(), String.t()) :: {:ok, feed()} | {:error, String.t()}
  def build(request, url, channel) do
    url = String.trim(url)
    channel = channel |> String.trim() |> Name.ensure_prefix()

    with :ok <- check_url(url),
         :ok <- check_channel(channel),
         :ok <- check_membership(request, channel),
         :ok <- check_room(request) do
      {:ok,
       %{
         "id" => generate_id(),
         "url" => url,
         "channel" => channel,
         "title" => nil,
         "seen" => [],
         "etag" => nil,
         "last_modified" => nil,
         "last_polled_at" => nil,
         "last_error" => nil
       }}
    end
  end

  @doc "How many feeds an RSS configuration allows."
  @spec max_feeds(map()) :: pos_integer()
  def max_feeds(config), do: Map.get(config, "max_feeds") || RSS.default_config()["max_feeds"]

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

  @spec check_url(String.t()) :: :ok | {:error, String.t()}
  defp check_url(url) do
    case URLGuard.check(url) do
      :ok ->
        :ok

      {:error, reason} ->
        {:error, dgettext("bots", "Refusing %{url}: %{reason}", url: url, reason: reason)}
    end
  end

  @spec check_channel(String.t()) :: :ok | {:error, String.t()}
  defp check_channel("#"),
    do: {:error, dgettext("bots", "Write the channel name after the #.")}

  defp check_channel(_), do: :ok

  # A feed pointed at a room the bot has not joined publishes into a void: the
  # channel refuses the message, the failure reaches a log nobody is reading, and
  # the feed looks healthy. Better to refuse the arrangement while someone is
  # looking at it.
  @spec check_membership(build_request(), String.t()) :: :ok | {:error, String.t()}
  defp check_membership(%{joined_channels: joined, bot_name: bot_name}, channel) do
    if channel in joined do
      :ok
    else
      {:error,
       dgettext("bots", "%{bot} has not joined %{channel}. Add %{channel} to the bot first.",
         bot: bot_name,
         channel: channel
       )}
    end
  end

  @spec check_room(build_request()) :: :ok | {:error, String.t()}
  defp check_room(%{feeds: feeds, max_feeds: max}) do
    if length(feeds) >= max do
      {:error, dgettext("bots", "Maximum %{max} feeds reached.", max: max)}
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
    case Lifecycle.reload_capabilities_or_start(bot) do
      :ok ->
        :ok

      {:error, :disabled} ->
        :ok

      {:error, reason} ->
        Logger.warning("Bot #{bot.nickname} failed to reload RSS feeds: #{inspect(reason)}")
        :ok
    end
  end

  @spec generate_id() :: String.t()
  defp generate_id, do: "f" <> (:crypto.strong_rand_bytes(3) |> Base.encode16(case: :lower))
end
