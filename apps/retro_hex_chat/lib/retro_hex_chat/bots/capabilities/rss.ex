defmodule RetroHexChat.Bots.Capabilities.RSS do
  @moduledoc """
  RSS/Atom feed reader capability. Polls feeds and posts new items to channels.

  Commands:
  - `!Bot rss add <url> <#channel>` — add a feed
  - `!Bot rss list` — list feeds
  - `!Bot rss remove <id>` — remove a feed
  - `!Bot rss check <id>` — force check now
  """
  use Gettext, backend: RetroHexChat.Gettext

  @behaviour RetroHexChat.Bots.Capability

  alias RetroHexChat.Bots.Capabilities.RSS.FeedParser
  alias RetroHexChat.Bots.Capabilities.RSS.Fetcher
  alias RetroHexChat.Bots.Capabilities.RSS.Scheduler
  alias RetroHexChat.Bots.Capabilities.RSS.UrlGuard
  alias RetroHexChat.Bots.Policy
  alias RetroHexChat.Scraper
  alias RetroHexChat.Scraper.Card

  require Logger

  @impl true
  @spec name() :: atom()
  def name, do: :rss

  @impl true
  @spec description() :: String.t()
  def description, do: dgettext("bots", "RSS feed reader that posts updates to channels")

  # The feed list and, inside it, the record of what has already been seen.
  # Both have to outlive a deploy: without the first the bot forgets its feeds,
  # without the second it greets the restart by republishing the feed page.
  @impl true
  @spec durable_keys() :: [atom()]
  def durable_keys, do: [:feeds]

  # How many item identities to remember per feed. Comfortably more than the
  # feeds' windows, so an item cannot rotate out of memory while still on the
  # page and come back as news.
  @seen_limit 10_000
  @parse_timeout_ms 20_000

  # How many items one poll announces. A feed page is not a burst budget: a
  # first read of a busy newsroom carries a hundred items, and delivering them
  # together auto-ignored the wire bots for every reader counting. What does not
  # fit is not dropped — it stays unseen and the next batch takes it, which is
  # why a remainder schedules a follow-up in minutes rather than waiting out the
  # feed's whole interval.
  @default_max_items_per_poll 10
  # How soon a feed with a backlog comes back for the rest.
  @drain_interval_ms :timer.seconds(45)

  @type decoded_feed_result ::
          {:ok, FeedParser.feed_info(), Fetcher.headers()}
          | {:not_modified}
          | {:error, String.t()}
  @type planned_result :: :ignore | {:items, [FeedParser.feed_item()], String.t() | nil}

  @impl true
  @spec init_state(map()) :: map()
  def init_state(config) do
    feeds = Map.get(config, "feeds", [])
    poll_interval_ms = Map.get(config, "poll_interval_min", 30) * 60 * 1000

    %{
      feeds: Enum.map(feeds, &normalize_feed/1),
      poll_interval_ms: poll_interval_ms
    }
  end

  # Feeds stored before the seen-set existed carry a single `last_seen_link`.
  # Seeding from it keeps that one item from being announced twice.
  @spec normalize_feed(map()) :: map()
  defp normalize_feed(feed) do
    seen =
      case {Map.get(feed, "seen"), Map.get(feed, "last_seen_link")} do
        {seen, _} when is_list(seen) -> seen
        {_, link} when is_binary(link) -> [link]
        _ -> []
      end

    Map.merge(
      %{
        "etag" => nil,
        "last_modified" => nil,
        "title" => nil,
        "last_error" => nil,
        "last_polled_at" => nil
      },
      Map.put(feed, "seen", seen)
    )
  end

  @impl true
  @spec init_timers(map(), atom(), map(), map()) :: map()
  # A feed that has never been polled is fetched almost at once so provisioning
  # publishes the current page and records it as history. Feeds already running
  # keep their cadence.
  @first_poll_delay_ms 3_000

  def init_timers(server_state, _cap_name, config, cap_state) do
    interval = Map.get(config, "poll_interval_min", 30) * 60 * 1000

    Enum.each(cap_state.feeds, fn feed ->
      delay = jitter(if feed["last_polled_at"], do: interval, else: @first_poll_delay_ms)

      case Scheduler.schedule_poll(server_state.bot_id, feed["id"], delay) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.warning("RSS poll schedule failed for #{feed["id"]}: #{inspect(reason)}")
      end
    end)

    server_state
  end

  @impl true
  @spec handle_message(String.t(), String.t(), RetroHexChat.Bots.Capability.bot_context()) ::
          RetroHexChat.Bots.Capability.capability_result()
  def handle_message(content, _author, ctx) do
    prefix = ctx.command_prefix
    bot_name = ctx.bot_nickname
    state = ctx.capability_state
    config = ctx.config

    case parse_command(content, prefix, bot_name) do
      {:rss, "list"} ->
        if_admin(ctx, fn -> handle_list(state) end)

      {:rss, "add " <> rest} ->
        if_admin(ctx, fn -> handle_add(rest, state, config) end)

      {:rss, "remove " <> id} ->
        if_admin(ctx, fn -> handle_remove(String.trim(id), state, ctx) end)

      {:rss, "check " <> id} ->
        if_admin(ctx, fn -> handle_check(String.trim(id), state, config, ctx.channel) end)

      :ignore ->
        :ignore
    end
  end

  # A bot's feed list is server configuration, not channel furniture. Changing it
  # points the server's own HTTP client at a URL somebody chose and aims the
  # output at a channel they may not even be in; reading it hands back every
  # address the server has been told to fetch. Both belong to whoever runs the
  # server — not to whoever happens to hold ops in the room the bot is sitting in.
  @spec if_admin(map(), (-> RetroHexChat.Bots.Capability.capability_result())) ::
          RetroHexChat.Bots.Capability.capability_result()
  defp if_admin(ctx, fun) do
    if Policy.admin?(Map.get(ctx, :author)) do
      fun.()
    else
      {:reply, dgettext("bots", "Only server administrators can manage feeds.")}
    end
  end

  @impl true
  @spec handle_event(atom(), map(), RetroHexChat.Bots.Capability.bot_context()) ::
          RetroHexChat.Bots.Capability.capability_result()
  def handle_event(_event, _payload, _ctx), do: :ignore

  @impl true
  @spec handle_timer(term(), map(), RetroHexChat.Bots.Capability.bot_context()) ::
          {RetroHexChat.Bots.Capability.capability_result(), map()}
  def handle_timer(%{type: :poll, feed_id: feed_id}, state, ctx) do
    poll_feed(feed_id, state, ctx.config)
  end

  def handle_timer(_payload, state, _ctx), do: {:ignore, state}

  @impl true
  @spec reschedule_delay(map(), map()) :: :no_reschedule
  def reschedule_delay(_payload, _cap_state), do: :no_reschedule

  @impl true
  @spec default_config() :: map()
  def default_config do
    %{
      "enabled" => true,
      "feeds" => [],
      "poll_interval_min" => 30,
      "max_feeds" => 5,
      "max_items_per_poll" => @default_max_items_per_poll
    }
  end

  @impl true
  @spec validate_config(map()) :: :ok | {:error, String.t()}
  def validate_config(_config), do: :ok

  @impl true
  @spec commands() :: [%{trigger: String.t(), description: String.t()}]
  def commands do
    [
      %{trigger: "rss add", description: dgettext("bots", "Add an RSS feed")},
      %{trigger: "rss list", description: dgettext("bots", "List RSS feeds")},
      %{trigger: "rss remove", description: dgettext("bots", "Remove an RSS feed")},
      %{trigger: "rss check", description: dgettext("bots", "Force check a feed now")}
    ]
  end

  # ── Command Parsing ──

  @spec parse_command(String.t(), String.t(), String.t()) :: {:rss, String.t()} | :ignore
  defp parse_command(content, prefix, bot_name) do
    lower = String.downcase(content)
    cmd_prefix = String.downcase(prefix) <> String.downcase(bot_name)

    if String.starts_with?(lower, cmd_prefix <> " rss ") do
      sub =
        content
        |> String.slice(String.length(cmd_prefix <> " rss ")..-1//1)
        |> String.trim()

      {:rss, String.downcase(sub)}
    else
      :ignore
    end
  end

  # ── Handlers ──

  @spec handle_list(map()) :: RetroHexChat.Bots.Capability.capability_result()
  defp handle_list(state) do
    feeds = state.feeds

    if feeds == [] do
      {:reply, dgettext("bots", "No RSS feeds configured.")}
    else
      lines =
        Enum.map(feeds, fn f ->
          title = f["title"] || dgettext("bots", "(untitled)")

          dgettext("bots", "  %{id} | %{title} | %{channel} | %{url}",
            id: f["id"],
            title: title,
            channel: f["channel"],
            url: truncate(f["url"], 40)
          )
        end)

      {:multi_reply, [dgettext("bots", "RSS Feeds:") | lines]}
    end
  end

  @spec handle_add(String.t(), map(), map()) :: RetroHexChat.Bots.Capability.capability_result()
  defp handle_add(rest, state, config) do
    max = Map.get(config, "max_feeds", 5)

    if length(state.feeds) >= max do
      {:reply, dgettext("bots", "Maximum %{max} feeds reached.", max: max)}
    else
      case String.split(rest, " ", parts: 2) do
        [url, channel] ->
          add_feed(url, ensure_hash(String.trim(channel)), state)

        [_url] ->
          {:reply, dgettext("bots", "Missing channel. Usage: rss add <url> <#channel>")}

        _ ->
          {:reply, dgettext("bots", "Usage: rss add <url> <#channel>")}
      end
    end
  end

  @spec add_feed(String.t(), String.t(), map()) ::
          RetroHexChat.Bots.Capability.capability_result()
  defp add_feed(url, channel, state) do
    case UrlGuard.check(url) do
      :ok ->
        do_add_feed(url, channel, state)

      {:error, reason} ->
        {:reply, dgettext("bots", "Refusing %{url}: %{reason}", url: url, reason: reason)}
    end
  end

  @spec do_add_feed(String.t(), String.t(), map()) ::
          RetroHexChat.Bots.Capability.capability_result()
  defp do_add_feed(url, channel, state) do
    id = generate_id()

    feed = %{
      "id" => id,
      "url" => url,
      "channel" => channel,
      "title" => nil,
      "seen" => [],
      "etag" => nil,
      "last_modified" => nil,
      "last_polled_at" => nil,
      "last_error" => nil
    }

    {:reply,
     dgettext("bots", "Feed '%{id}' added: %{url} → %{channel}",
       id: id,
       url: url,
       channel: channel
     ), %{state | feeds: state.feeds ++ [feed]}}
  end

  @spec handle_remove(String.t(), map(), map()) ::
          RetroHexChat.Bots.Capability.capability_result()
  defp handle_remove(id, state, ctx) do
    if find_feed(state.feeds, id) do
      new_feeds = Enum.reject(state.feeds, &(&1["id"] == id))
      Scheduler.cancel_poll(Map.get(ctx, :bot_id), id)
      {:reply, dgettext("bots", "Feed '%{id}' removed.", id: id), %{state | feeds: new_feeds}}
    else
      {:reply, dgettext("bots", "Feed '%{id}' not found.", id: id)}
    end
  end

  @spec handle_check(String.t(), map(), map(), String.t()) ::
          RetroHexChat.Bots.Capability.capability_result()
  # A forced check is a poll that happens now, so it must publish what it finds.
  # Reporting "new items found" and dropping the headlines marked them as seen
  # without anyone having seen them — the news was consumed and could never
  # arrive, not even on the next scheduled poll.
  defp handle_check(id, state, config, channel) do
    case find_feed(state.feeds, id) do
      nil ->
        {:reply, dgettext("bots", "Feed '%{id}' not found.", id: id)}

      %{"channel" => target} when target != channel ->
        # Publishing here would put the feed's items in the wrong room. Leave
        # them for the scheduled poll rather than consume them out of sight.
        {:reply,
         dgettext("bots", "Feed '%{id}' posts to %{channel}. Ask there to check it.",
           id: id,
           channel: target
         )}

      _feed ->
        case poll_feed(id, state, config) do
          {{:multi_output, outputs}, new_state} ->
            {:multi_output, outputs, new_state}

          {:ignore, new_state} ->
            # Keep the state: it carries when the poll ran and why it failed.
            {:reply, dgettext("bots", "Feed '%{id}' checked. Nothing new.", id: id), new_state}
        end
    end
  end

  # ── Polling ──

  @spec poll_feed(String.t(), map(), map()) ::
          {RetroHexChat.Bots.Capability.capability_result(), map()}
  def poll_feed(feed_id, state, config) do
    case find_feed(state.feeds, feed_id) do
      nil ->
        {:ignore, state}

      feed ->
        decoded = feed |> fetch_feed() |> decode_fetch_result(feed)
        {planned, new_state} = apply_decoded_result(feed, decoded, state, config)
        {format_planned_result(planned), new_state}
    end
  end

  @spec fetch_feed(map()) :: Fetcher.result()
  def fetch_feed(feed) do
    Fetcher.impl().fetch(feed["url"], feed["etag"], feed["last_modified"])
  end

  @spec decode_fetch_result(Fetcher.result(), map()) :: decoded_feed_result()
  def decode_fetch_result({:ok, xml, headers}, _feed) do
    case parse_feed(xml) do
      {:ok, feed_info} ->
        {:ok, feed_info, headers}

      {:error, reason} ->
        {:error, "unreadable feed: #{inspect(reason)}"}
    end
  end

  def decode_fetch_result({:not_modified}, _feed), do: {:not_modified}

  def decode_fetch_result({:error, reason}, feed) do
    Logger.warning("RSS fetch error for #{feed["url"]}: #{inspect(reason)}")
    {:error, describe_error(reason)}
  end

  @spec apply_decoded_result(map(), decoded_feed_result(), map(), map()) ::
          {planned_result(), map()}
  def apply_decoded_result(feed, {:ok, feed_info, headers}, state, config) do
    max_items = Map.get(config, "max_items_per_poll", @default_max_items_per_poll)
    publish(feed, feed_info, headers, state, max_items)
  end

  def apply_decoded_result(feed, {:not_modified}, state, _config) do
    {:ignore, note_poll(state, feed, nil)}
  end

  def apply_decoded_result(feed, {:error, reason}, state, _config) do
    {:ignore, note_poll(state, feed, reason)}
  end

  @spec format_planned_result(planned_result()) ::
          RetroHexChat.Bots.Capability.capability_result()
  def format_planned_result(:ignore), do: :ignore

  def format_planned_result({:items, items, feed_title}),
    do: {:multi_output, format_items(items, feed_title)}

  @spec parse_feed(String.t()) :: {:ok, FeedParser.feed_info()} | {:error, term()}
  defp parse_feed(xml) do
    task = Task.async(fn -> FeedParser.parse(xml) end)

    case Task.yield(task, @parse_timeout_ms) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} -> result
      {:exit, reason} -> {:error, reason}
      nil -> {:error, :timeout}
    end
  end

  @spec publish(map(), FeedParser.feed_info(), map(), map(), integer()) ::
          {planned_result(), map()}
  defp publish(feed, feed_info, headers, state, max_items) do
    seen = feed["seen"] || []
    {to_post, identities_to_remember} = plan_publication(seen, feed_info.items, max_items)
    pending = pending_count(seen, feed_info.items, length(to_post))

    updated =
      feed
      |> Map.put("title", feed_info.title || feed["title"])
      |> Map.put("etag", headers[:etag])
      |> Map.put("last_modified", headers[:last_modified])
      # Only the batch, never the page: what is left stays unseen so the next
      # poll takes it. `pending` is what tells the worker to come back soon.
      |> Map.put("seen", Enum.take(identities_to_remember ++ seen, @seen_limit))
      |> Map.put("pending", pending)
      |> Map.put("last_polled_at", DateTime.utc_now() |> DateTime.to_iso8601())
      |> Map.put("last_error", nil)

    new_state = update_feed(state, feed["id"], updated)

    if to_post == [] do
      {:ignore, new_state}
    else
      {{:items, to_post, updated["title"]}, new_state}
    end
  end

  @doc """
  Decides what to announce, given what has already been announced.

  Pure on purpose: this is the whole "only new items, never twice" rule, and it
  is worth testing without a network in the way.

    * An item is recognised by identity, not by position, so a feed that pins a
      post to the top or reorders on update cannot make old news look new.
    * Only what is actually posted is marked seen, so the per-poll ceiling
      drains across later polls instead of losing items. That holds for the
      first sight of a feed too: a page of a hundred leaves ninety unseen and
      the follow-up poll takes the next ten.
    * Oldest first, so a backlog drains in the order it was published rather
      than newest-first and backwards.

  The first sight used to be a separate rule — announce the newest few, then
  mark the *whole page* seen so a restart would not replay it. That silently
  discarded everything the ceiling excluded, which only looked harmless while
  the ceiling was ten thousand. Marking just the batch makes the two cases the
  same rule, and a restart mid-drain resumes instead of replaying.

  Returns `{items_to_post, identities_to_remember}`, oldest first.
  """
  @spec plan_publication([String.t()], [FeedParser.feed_item()], pos_integer()) ::
          {[FeedParser.feed_item()], [String.t()]}
  def plan_publication(seen, items, max_items) do
    batch =
      items
      |> Enum.reject(&(identity(&1) in seen))
      |> Enum.reverse()
      |> Enum.take(max_items)

    {batch, Enum.map(batch, &identity/1)}
  end

  @doc """
  How many unseen items this poll is leaving behind.

  Drives the follow-up: a feed with a backlog comes back in seconds rather than
  waiting out its whole interval, so "publish everything" stays true without
  publishing everything at once.
  """
  @spec pending_count([String.t()], [FeedParser.feed_item()], non_neg_integer()) ::
          non_neg_integer()
  def pending_count(seen, items, published_count) do
    unseen = Enum.count(items, &(identity(&1) not in seen))
    max(unseen - published_count, 0)
  end

  @doc "How soon a feed with a backlog should be polled again."
  @spec drain_interval_ms() :: pos_integer()
  def drain_interval_ms, do: @drain_interval_ms

  @doc """
  Spreads a delay by up to a tenth, so feeds sharing an interval drift apart.

  The interval is configured per bot, so a bot's feeds share a number and come
  due together, and provisioning gave 132 feeds the same twenty minutes. Worse,
  a restart reschedules every feed from the same instant, so each deploy
  realigns whatever had drifted apart — which is why this belongs on the boot
  path and not only on the follow-up.

  A cohort is what exhausted the file descriptors, and it is what puts several
  feeds of one bot on a reader's flood counter at the same moment. A tenth
  breaks the alignment within a poll or two and is small enough that no feed's
  cadence visibly changes.
  """
  @spec jitter(non_neg_integer()) :: non_neg_integer()
  def jitter(delay_ms) when delay_ms > 0 do
    spread = max(div(delay_ms, 10), 1)
    delay_ms - div(spread, 2) + :rand.uniform(spread + 1) - 1
  end

  def jitter(delay_ms), do: delay_ms

  # An item's identity: its guid when the feed publishes one, its link otherwise.
  # Comparing identities rather than walking down from the newest makes the check
  # immune to feeds that pin an item to the top or reorder on update.
  @spec identity(FeedParser.feed_item()) :: String.t()
  defp identity(item) do
    case Map.get(item, :guid) do
      guid when is_binary(guid) and guid != "" -> guid
      _ -> item.link || item.title
    end
  end

  @spec describe_error(term()) :: String.t()
  defp describe_error({:http_status, status}) when is_integer(status),
    do: dgettext("bots", "HTTP %{status}", status: status)

  defp describe_error({:blocked, reason}), do: reason
  defp describe_error(%{reason: reason}), do: inspect(reason)
  defp describe_error(reason) when is_binary(reason), do: reason
  defp describe_error(reason), do: inspect(reason)

  @spec note_poll(map(), map(), String.t() | nil) :: map()
  defp note_poll(state, feed, error) do
    updated =
      feed
      |> Map.put("last_polled_at", DateTime.utc_now() |> DateTime.to_iso8601())
      |> Map.put("last_error", error)

    update_feed(state, feed["id"], updated)
  end

  @preview_max_concurrency 8
  @preview_fetch_timeout_ms 20_000
  @feed_card_excerpt_length 360

  @spec format_items([FeedParser.feed_item()], String.t() | nil) :: [map()]
  defp format_items(items, feed_title) do
    items
    |> Enum.zip(fetch_preview_metadata(items))
    |> Enum.map(fn {item, metadata} ->
      %{
        delivery: "public",
        content: format_item(item, feed_title, metadata),
        content_format: "markdown"
      }
    end)
  end

  # The bot does not read these pages itself: it asks the archive. A feed that
  # republishes a link, a second feed carrying the same article, and a link
  # somebody already pasted in a channel all resolve from the same store, so the
  # publisher is visited only for the ones nobody has read yet.
  @spec fetch_preview_metadata([FeedParser.feed_item()]) :: [Scraper.Client.metadata()]
  defp fetch_preview_metadata(items) do
    items
    |> Task.async_stream(
      fn item ->
        Scraper.fetch(item.link,
          metadata_hints: feed_item_metadata_hints(item),
          thumbnail: :sync,
          timeout: @preview_fetch_timeout_ms
        )
      end,
      max_concurrency: @preview_max_concurrency,
      ordered: true,
      on_timeout: :kill_task,
      timeout: @preview_fetch_timeout_ms
    )
    |> Enum.map(fn
      {:ok, {:ok, page}} -> Scraper.Client.to_metadata(page)
      {:ok, {:error, _reason}} -> %{}
      {:error, _reason} -> %{}
      {:exit, _reason} -> %{}
    end)
  end

  @spec feed_item_metadata_hints(FeedParser.feed_item()) :: Scraper.Client.metadata_hints()
  defp feed_item_metadata_hints(item) do
    published_at = feed_item_published_at(item)

    %{}
    |> maybe_put_hint(:title, Map.get(item, :title))
    |> maybe_put_hint(:description, Map.get(item, :description))
    |> maybe_put_hint(:content_text, Map.get(item, :content_text))
    |> maybe_put_hint(:author, Map.get(item, :author))
    |> maybe_put_hint(:published_at, published_at)
    |> maybe_put_hint(:tags, Map.get(item, :categories))
    |> maybe_put_hint(:feed_item, feed_item_raw_hints(item, published_at))
    |> maybe_put_hint(:image, Map.get(item, :image_url))
    |> maybe_put_hint(:image_alt, Map.get(item, :image_alt))
    |> maybe_put_hint(:image_source, Map.get(item, :image_source))
  end

  @spec maybe_put_hint(map(), atom(), term()) :: map()
  defp maybe_put_hint(map, _key, nil), do: map
  defp maybe_put_hint(map, _key, ""), do: map
  defp maybe_put_hint(map, _key, []), do: map
  defp maybe_put_hint(map, _key, value) when value == %{}, do: map
  defp maybe_put_hint(map, key, value), do: Map.put(map, key, value)

  @spec feed_item_raw_hints(FeedParser.feed_item(), DateTime.t() | nil) :: map()
  defp feed_item_raw_hints(item, published_at) do
    %{}
    |> maybe_put_raw_hint("title", Map.get(item, :title))
    |> maybe_put_raw_hint("link", Map.get(item, :link))
    |> maybe_put_raw_hint("guid", Map.get(item, :guid))
    |> maybe_put_raw_hint("published", Map.get(item, :published))
    |> maybe_put_raw_hint("published_at", iso8601(published_at))
    |> maybe_put_raw_hint("description", Map.get(item, :description))
    |> maybe_put_raw_hint("content_text", Map.get(item, :content_text))
    |> maybe_put_raw_hint("author", Map.get(item, :author))
    |> maybe_put_raw_hint("categories", Map.get(item, :categories))
    |> maybe_put_raw_hint("image_url", Map.get(item, :image_url))
    |> maybe_put_raw_hint("image_alt", Map.get(item, :image_alt))
    |> maybe_put_raw_hint("image_source", Map.get(item, :image_source))
  end

  @spec maybe_put_raw_hint(map(), String.t(), term()) :: map()
  defp maybe_put_raw_hint(map, _key, nil), do: map
  defp maybe_put_raw_hint(map, _key, ""), do: map
  defp maybe_put_raw_hint(map, _key, []), do: map
  defp maybe_put_raw_hint(map, key, value), do: Map.put(map, key, value)

  @spec iso8601(DateTime.t() | nil) :: String.t() | nil
  defp iso8601(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)
  defp iso8601(_datetime), do: nil

  @doc """
  A feed item as one Markdown card.

  Public so the shape can be asserted on directly: this is the house style for
  every RSS bot, not a per-bot decision, and it is the part a reader actually
  meets. The shape itself belongs to `Scraper.Card`, which renders the same card
  for a link pasted into a conversation.

  A feed item is a message on its own, so it always produces a card: where a
  pasted link with no title is left as a plain link, an item with no title is
  published under a placeholder rather than dropped.
  """
  @spec format_item(FeedParser.feed_item(), String.t() | nil, Scraper.Client.metadata() | nil) ::
          String.t()
  def format_item(item, feed_title, metadata \\ nil) do
    metadata = merge_card_metadata(metadata || %{}, feed_item_card_metadata(item))

    Card.markdown(metadata,
      fallback_title: item_title(item),
      fallback_source: source_label(feed_title),
      image_policy: :cached,
      url: item.link
    )
  end

  @spec item_title(FeedParser.feed_item()) :: String.t()
  defp item_title(%{title: title}) when is_binary(title) and title != "", do: title
  defp item_title(_item), do: dgettext("bots", "(no title)")

  @spec feed_item_card_metadata(FeedParser.feed_item()) :: Scraper.Client.metadata()
  defp feed_item_card_metadata(item) do
    content_text = Map.get(item, :content_text)

    %{}
    |> maybe_put_hint(:description, Map.get(item, :description) || excerpt(content_text))
    |> maybe_put_hint(:author, Scraper.Client.byline(Map.get(item, :author)))
    |> maybe_put_hint(:published_at, feed_item_published_at(item))
    |> maybe_put_hint(:tags, Map.get(item, :categories))
    |> maybe_put_hint(:word_count, word_count(content_text))
  end

  @spec merge_card_metadata(Scraper.Client.metadata(), Scraper.Client.metadata()) ::
          Scraper.Client.metadata()
  defp merge_card_metadata(page_metadata, feed_metadata) do
    Map.merge(feed_metadata, page_metadata, fn _key, feed_value, page_value ->
      present_metadata_value(page_value) || feed_value
    end)
  end

  @spec present_metadata_value(term()) :: term() | nil
  defp present_metadata_value(value) when is_binary(value) do
    if String.trim(value) == "", do: nil, else: value
  end

  defp present_metadata_value(value) when is_list(value),
    do: if(value == [], do: nil, else: value)

  defp present_metadata_value(nil), do: nil
  defp present_metadata_value(value), do: value

  @spec excerpt(String.t() | nil) :: String.t() | nil
  defp excerpt(nil), do: nil

  defp excerpt(text) do
    text
    |> truncate(@feed_card_excerpt_length)
    |> blank_to_nil()
  end

  @spec blank_to_nil(String.t()) :: String.t() | nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  @spec word_count(String.t() | nil) :: non_neg_integer() | nil
  defp word_count(text) when is_binary(text) and text != "" do
    text |> String.split() |> length()
  end

  defp word_count(_text), do: nil

  @spec feed_item_published_at(FeedParser.feed_item()) :: DateTime.t() | nil
  defp feed_item_published_at(item), do: item |> Map.get(:published) |> parse_feed_datetime()

  @spec parse_feed_datetime(String.t() | nil) :: DateTime.t() | nil
  defp parse_feed_datetime(nil), do: nil

  defp parse_feed_datetime(value) when is_binary(value) do
    value = String.trim(value)

    cond do
      value == "" ->
        nil

      datetime = iso8601_datetime(value) ->
        datetime

      datetime = rfc_datetime(value) ->
        datetime

      true ->
        nil
    end
  end

  defp parse_feed_datetime(_value), do: nil

  @spec iso8601_datetime(String.t()) :: DateTime.t() | nil
  defp iso8601_datetime(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} ->
        datetime

      {:error, _reason} ->
        case Date.from_iso8601(value) do
          {:ok, date} -> DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
          {:error, _reason} -> nil
        end
    end
  rescue
    _ -> nil
  end

  @spec rfc_datetime(String.t()) :: DateTime.t() | nil
  defp rfc_datetime(value) do
    case :httpd_util.convert_request_date(String.to_charlist(value)) do
      {{year, month, day}, {hour, minute, second}} ->
        DateTime.new!(
          Date.new!(year, month, day),
          Time.new!(hour, minute, second),
          "Etc/UTC"
        )

      _other ->
        nil
    end
  rescue
    _ -> nil
  end

  @doc """
  The label a feed's items carry.

  A feed that names itself is reduced to the publication behind the tagline; one
  that names itself nothing at all is still an RSS feed, which is more than a
  reader could infer from the item's host. A link pasted in a channel has no feed
  and falls back to the host instead — see `Scraper.Card`.
  """
  @spec source_label(String.t() | nil) :: String.t()
  def source_label(nil), do: dgettext("bots", "RSS")
  def source_label(title), do: Card.source_label(title)

  @spec find_feed([map()], String.t()) :: map() | nil
  defp find_feed(feeds, id), do: Enum.find(feeds, &(&1["id"] == id))

  @spec update_feed(map(), String.t(), map()) :: map()
  defp update_feed(state, id, updated_feed) do
    new_feeds = Enum.map(state.feeds, fn f -> if f["id"] == id, do: updated_feed, else: f end)
    %{state | feeds: new_feeds}
  end

  @spec generate_id() :: String.t()
  defp generate_id do
    "f" <> (:crypto.strong_rand_bytes(3) |> Base.encode16(case: :lower))
  end

  @spec truncate(String.t(), pos_integer()) :: String.t()
  defp truncate(str, max) do
    if String.length(str) > max do
      String.slice(str, 0, max - 3) <> "..."
    else
      str
    end
  end

  @spec ensure_hash(String.t()) :: String.t()
  defp ensure_hash("#" <> _ = ch), do: ch
  defp ensure_hash(ch), do: "#" <> ch
end
