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
  alias RetroHexChat.Bots.Capabilities.RSS.UrlGuard
  alias RetroHexChat.Bots.Server

  require Logger

  @impl true
  @spec name() :: atom()
  def name, do: :rss

  @impl true
  @spec description() :: String.t()
  def description, do: dgettext("bots", "RSS feed reader that posts updates to channels")

  # The feed list and, inside it, the record of what has already been announced.
  # Both have to outlive a deploy: without the first the bot forgets its feeds,
  # without the second it greets the restart by republishing the whole feed.
  @impl true
  @spec durable_keys() :: [atom()]
  def durable_keys, do: [:feeds]

  # How many item identities to remember per feed. Comfortably more than any
  # feed's window, so an item cannot rotate out of memory while still on the
  # page and come back as news.
  @seen_limit 200

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
  # Waiting half an hour to find out whether a feed works is how a feature gets
  # called broken. A feed that has never been polled is polled almost at once,
  # posts its newest item as proof of life, and remembers the rest of the page.
  # Feeds already running keep their cadence.
  @first_poll_delay_ms 3_000

  def init_timers(server_state, cap_name, config, cap_state) do
    interval = Map.get(config, "poll_interval_min", 30) * 60 * 1000

    Enum.reduce(cap_state.feeds, server_state, fn feed, acc ->
      payload = %{type: :poll, feed_id: feed["id"], channel: feed["channel"]}
      delay = if feed["last_polled_at"], do: interval, else: @first_poll_delay_ms

      Server.schedule_capability_timer(acc, cap_name, payload, delay)
    end)
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
        handle_list(state)

      {:rss, "add " <> rest} ->
        if_privileged(ctx, fn -> handle_add(rest, state, config) end)

      {:rss, "remove " <> id} ->
        if_privileged(ctx, fn -> handle_remove(String.trim(id), state) end)

      {:rss, "check " <> id} ->
        if_privileged(ctx, fn -> handle_check(String.trim(id), state, config, ctx.channel) end)

      :ignore ->
        :ignore
    end
  end

  # Reading the feed list is harmless. Changing it points the server's own HTTP
  # client at a URL somebody chose, and aims the output at a channel they may not
  # even be in — that belongs to whoever runs the room.
  @spec if_privileged(map(), (-> RetroHexChat.Bots.Capability.capability_result())) ::
          RetroHexChat.Bots.Capability.capability_result()
  defp if_privileged(ctx, fun) do
    if Map.get(ctx, :author_privileged?, false) do
      fun.()
    else
      {:reply, dgettext("bots", "Only channel operators can change the feed list.")}
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
    config = ctx.config

    case find_feed(state.feeds, feed_id) do
      nil ->
        {:ignore, state}

      feed ->
        do_poll_feed(feed, state, config)
    end
  end

  def handle_timer(_payload, state, _ctx), do: {:ignore, state}

  @impl true
  @spec reschedule_delay(map(), map()) :: {:reschedule, non_neg_integer(), map()} | :no_reschedule
  def reschedule_delay(%{type: :poll, feed_id: feed_id} = payload, cap_state) do
    if find_feed(cap_state.feeds, feed_id) do
      {:reschedule, cap_state.poll_interval_ms, payload}
    else
      :no_reschedule
    end
  end

  def reschedule_delay(_payload, _cap_state), do: :no_reschedule

  @impl true
  @spec default_config() :: map()
  def default_config do
    %{
      "enabled" => true,
      "feeds" => [],
      "poll_interval_min" => 30,
      "max_feeds" => 5,
      "max_items_per_poll" => 3
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

  @spec handle_remove(String.t(), map()) :: RetroHexChat.Bots.Capability.capability_result()
  defp handle_remove(id, state) do
    if find_feed(state.feeds, id) do
      new_feeds = Enum.reject(state.feeds, &(&1["id"] == id))
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

      feed ->
        case do_poll_feed(feed, state, config) do
          {{:multi_reply, lines}, new_state} ->
            {:multi_reply, lines, new_state}

          {:ignore, new_state} ->
            # Keep the state: it carries when the poll ran and why it failed.
            {:reply, dgettext("bots", "Feed '%{id}' checked. Nothing new.", id: id), new_state}
        end
    end
  end

  # ── Polling ──

  @spec do_poll_feed(map(), map(), map()) ::
          {RetroHexChat.Bots.Capability.capability_result(), map()}
  defp do_poll_feed(feed, state, config) do
    max_items = Map.get(config, "max_items_per_poll", 3)

    case fetch_feed(feed["url"], feed["etag"], feed["last_modified"]) do
      {:ok, xml, headers} ->
        process_feed_response(feed, xml, headers, state, max_items)

      {:not_modified} ->
        {:ignore, note_poll(state, feed, nil)}

      {:error, reason} ->
        Logger.warning("RSS fetch error for #{feed["url"]}: #{inspect(reason)}")
        {:ignore, note_poll(state, feed, describe_error(reason))}
    end
  end

  @spec process_feed_response(map(), String.t(), map(), map(), integer()) ::
          {RetroHexChat.Bots.Capability.capability_result(), map()}
  defp process_feed_response(feed, xml, headers, state, max_items) do
    case FeedParser.parse(xml) do
      {:ok, feed_info} ->
        publish(feed, feed_info, headers, state, max_items)

      {:error, reason} ->
        {:ignore, note_poll(state, feed, "unreadable feed: #{inspect(reason)}")}
    end
  end

  @spec publish(map(), FeedParser.feed_info(), map(), map(), integer()) ::
          {RetroHexChat.Bots.Capability.capability_result(), map()}
  defp publish(feed, feed_info, headers, state, max_items) do
    seen = feed["seen"] || []
    {to_post, newly_seen} = plan_publication(seen, feed_info.items, max_items)

    updated =
      feed
      |> Map.put("title", feed_info.title || feed["title"])
      |> Map.put("etag", headers[:etag])
      |> Map.put("last_modified", headers[:last_modified])
      # Only what was actually posted is marked seen, so anything over the
      # per-poll ceiling is picked up next time rather than lost.
      |> Map.put("seen", Enum.take(newly_seen ++ seen, @seen_limit))
      |> Map.put("last_polled_at", DateTime.utc_now() |> DateTime.to_iso8601())
      |> Map.put("last_error", nil)

    new_state = update_feed(state, feed["id"], updated)

    if to_post == [] do
      {:ignore, new_state}
    else
      {{:multi_reply, format_items(to_post, updated["title"])}, new_state}
    end
  end

  @doc """
  Decides what to announce, given what has already been announced.

  Pure on purpose: this is the whole "only new items, never twice" rule, and it
  is worth testing without a network in the way.

    * The first sight of a feed announces its newest item and remembers the
      rest. Saying nothing at all was the tidier rule and the wrong one: an
      operator who has just added a feed has no way to tell a working one from a
      typo until the next poll, twenty minutes to an hour later. One headline
      answers that in seconds, and is not an archive dump.
    * An item is recognised by identity, not by position, so a feed that pins a
      post to the top or reorders on update cannot make old news look new.
    * Only what is actually posted is marked seen, so anything above the
      per-poll ceiling waits for the next poll instead of being lost.

  Returns `{items_to_post, identities_to_remember}`, oldest first.
  """
  @spec plan_publication([String.t()], [FeedParser.feed_item()], pos_integer()) ::
          {[FeedParser.feed_item()], [String.t()]}
  def plan_publication([], [], _max_items), do: {[], []}

  def plan_publication([], [newest | _] = items, _max_items) do
    {[newest], Enum.map(items, &identity/1)}
  end

  def plan_publication(seen, items, max_items) do
    batch =
      items
      |> Enum.reject(&(identity(&1) in seen))
      |> Enum.reverse()
      |> Enum.take(max_items)

    {batch, Enum.map(batch, &identity/1)}
  end

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

  @spec fetch_feed(String.t(), String.t() | nil, String.t() | nil) ::
          {:ok, String.t(), map()} | {:not_modified} | {:error, term()}
  defp fetch_feed(url, etag, last_modified) do
    Fetcher.impl().fetch(url, etag, last_modified)
  end

  @spec format_items([FeedParser.feed_item()], String.t() | nil) :: [String.t()]
  defp format_items(items, feed_title) do
    Enum.map(items, &format_item(&1, feed_title))
  end

  # One line, three jobs, in the order the eye needs them: which wire it came
  # from, what happened, and where to read it. Undifferentiated text made all
  # three compete — a source name as loud as the headline, and a URL as loud as
  # both, wrapping across lines.
  @ctrl_bold <<0x02>>
  @ctrl_colour <<0x03>>
  @ctrl_reset <<0x0F>>

  # Fixed hex against the window's white, so these are picked to stay legible on
  # it: navy carries the source, grey retires the link out of the way. The
  # headline keeps the default colour — it is the thing being read.
  @colour_source "02"
  @colour_link "14"

  # A source label is a name, not a sentence; a headline that runs past this is
  # a paper title, and the link carries the whole of it.
  @source_limit 24
  @headline_limit 140

  @doc """
  A feed item as one readable line.

  Public so the shape can be asserted on directly: this is the house style for
  every RSS bot, not a per-bot decision, and it is the part a reader actually
  meets.
  """
  @spec format_item(FeedParser.feed_item(), String.t() | nil) :: String.t()
  def format_item(item, feed_title) do
    source = feed_title |> source_label() |> truncate(@source_limit)
    headline = item.title |> to_string() |> collapse_space() |> truncate(@headline_limit)

    colour(@colour_source, @ctrl_bold <> "[" <> source <> "]") <>
      " " <> headline <> link_suffix(item.link)
  end

  # Publishers put their whole positioning statement in the feed title —
  # "cs.LG updates on arXiv.org", "Phys.org - latest science and technology news
  # stories", "Al Jazeera – Breaking News, World News and Video". As a label
  # repeated on every line that is noise, and truncating it lands mid-sentence.
  # The part before the first separator is the name; the rest is the tagline.
  @label_separators [" updates on ", " - ", " – ", " — ", " | ", ": "]

  @spec source_label(String.t() | nil) :: String.t()
  def source_label(nil), do: dgettext("bots", "RSS")

  def source_label(title) do
    title = collapse_space(title)

    Enum.reduce(@label_separators, title, fn separator, current ->
      case String.split(current, separator, parts: 2) do
        [head, _tail] when head != "" -> head
        _ -> current
      end
    end)
  end

  @spec link_suffix(String.t() | nil) :: String.t()
  defp link_suffix(link) when is_binary(link) and link != "" do
    " " <> colour(@colour_link, link)
  end

  defp link_suffix(_link), do: ""

  @spec colour(String.t(), String.t()) :: String.t()
  defp colour(code, text), do: @ctrl_colour <> code <> text <> @ctrl_reset

  # Feed titles arrive with newlines and runs of spaces from the source's own
  # markup; a headline that carries them breaks the line before it is truncated.
  @spec collapse_space(String.t()) :: String.t()
  defp collapse_space(text), do: text |> String.split() |> Enum.join(" ")

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
