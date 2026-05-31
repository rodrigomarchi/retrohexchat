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
  alias RetroHexChat.Bots.Server

  require Logger

  @impl true
  @spec name() :: atom()
  def name, do: :rss

  @impl true
  @spec description() :: String.t()
  def description, do: gettext("RSS feed reader that posts updates to channels")

  @impl true
  @spec init_state(map()) :: map()
  def init_state(config) do
    feeds = Map.get(config, "feeds", [])
    poll_interval_ms = Map.get(config, "poll_interval_min", 30) * 60 * 1000

    %{
      feeds:
        Enum.map(feeds, fn f ->
          Map.merge(
            %{"last_seen_link" => nil, "etag" => nil, "last_modified" => nil, "title" => nil},
            f
          )
        end),
      poll_interval_ms: poll_interval_ms
    }
  end

  @impl true
  @spec init_timers(map(), atom(), map(), map()) :: map()
  def init_timers(server_state, cap_name, config, cap_state) do
    interval = Map.get(config, "poll_interval_min", 30) * 60 * 1000

    Enum.reduce(cap_state.feeds, server_state, fn feed, acc ->
      payload = %{type: :poll, feed_id: feed["id"], channel: feed["channel"]}

      Server.schedule_capability_timer(acc, cap_name, payload, interval)
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
      {:rss, "list"} -> handle_list(state)
      {:rss, "add " <> rest} -> handle_add(rest, state, config)
      {:rss, "remove " <> id} -> handle_remove(String.trim(id), state)
      {:rss, "check " <> id} -> handle_check(String.trim(id), state, config)
      :ignore -> :ignore
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
      %{trigger: "rss add", description: gettext("Add an RSS feed")},
      %{trigger: "rss list", description: gettext("List RSS feeds")},
      %{trigger: "rss remove", description: gettext("Remove an RSS feed")},
      %{trigger: "rss check", description: gettext("Force check a feed now")}
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
      {:reply, gettext("No RSS feeds configured.")}
    else
      lines =
        Enum.map(feeds, fn f ->
          title = f["title"] || gettext("(untitled)")

          gettext("  %{id} | %{title} | %{channel} | %{url}",
            id: f["id"],
            title: title,
            channel: f["channel"],
            url: truncate(f["url"], 40)
          )
        end)

      {:multi_reply, [gettext("RSS Feeds:") | lines]}
    end
  end

  @spec handle_add(String.t(), map(), map()) :: RetroHexChat.Bots.Capability.capability_result()
  defp handle_add(rest, state, config) do
    max = Map.get(config, "max_feeds", 5)

    if length(state.feeds) >= max do
      {:reply, gettext("Maximum %{max} feeds reached.", max: max)}
    else
      case String.split(rest, " ", parts: 2) do
        [url, channel] ->
          add_feed(url, ensure_hash(String.trim(channel)), state)

        [_url] ->
          {:reply, gettext("Missing channel. Usage: rss add <url> <#channel>")}

        _ ->
          {:reply, gettext("Usage: rss add <url> <#channel>")}
      end
    end
  end

  @spec add_feed(String.t(), String.t(), map()) ::
          RetroHexChat.Bots.Capability.capability_result()
  defp add_feed(url, channel, state) do
    if valid_url?(url) do
      id = generate_id()

      feed = %{
        "id" => id,
        "url" => url,
        "channel" => channel,
        "title" => nil,
        "last_seen_link" => nil,
        "etag" => nil,
        "last_modified" => nil
      }

      new_state = %{state | feeds: state.feeds ++ [feed]}

      {:reply,
       gettext("Feed '%{id}' added: %{url} → %{channel}",
         id: id,
         url: url,
         channel: channel
       ), new_state}
    else
      {:reply, gettext("Invalid URL. Must start with http:// or https://")}
    end
  end

  @spec handle_remove(String.t(), map()) :: RetroHexChat.Bots.Capability.capability_result()
  defp handle_remove(id, state) do
    if find_feed(state.feeds, id) do
      new_feeds = Enum.reject(state.feeds, &(&1["id"] == id))
      {:reply, gettext("Feed '%{id}' removed.", id: id), %{state | feeds: new_feeds}}
    else
      {:reply, gettext("Feed '%{id}' not found.", id: id)}
    end
  end

  @spec handle_check(String.t(), map(), map()) ::
          RetroHexChat.Bots.Capability.capability_result()
  defp handle_check(id, state, config) do
    case find_feed(state.feeds, id) do
      nil ->
        {:reply, gettext("Feed '%{id}' not found.", id: id)}

      feed ->
        case do_poll_feed(feed, state, config) do
          {{:multi_reply, _lines}, new_state} ->
            {:reply, gettext("Checked feed '%{id}'. New items found.", id: id), new_state}

          {:ignore, _state} ->
            {:reply, gettext("Feed '%{id}' checked. No new items.", id: id)}
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
        {:ignore, state}

      {:error, reason} ->
        Logger.warning("RSS fetch error for #{feed["url"]}: #{inspect(reason)}")
        {:ignore, state}
    end
  end

  @spec process_feed_response(map(), String.t(), map(), map(), integer()) ::
          {RetroHexChat.Bots.Capability.capability_result(), map()}
  defp process_feed_response(feed, xml, headers, state, max_items) do
    case FeedParser.parse(xml) do
      {:ok, feed_info} ->
        new_items = filter_new_items(feed_info.items, feed["last_seen_link"])
        items_to_post = Enum.take(new_items, max_items)

        updated_feed =
          feed
          |> Map.put("title", feed_info.title || feed["title"])
          |> maybe_update_last_seen(items_to_post)
          |> Map.put("etag", headers[:etag])
          |> Map.put("last_modified", headers[:last_modified])

        new_state = update_feed(state, feed["id"], updated_feed)

        if items_to_post == [] do
          {:ignore, new_state}
        else
          lines = format_items(items_to_post, feed_info.title || feed["title"])
          {{:multi_reply, lines}, new_state}
        end

      {:error, _reason} ->
        {:ignore, state}
    end
  end

  @spec fetch_feed(String.t(), String.t() | nil, String.t() | nil) ::
          {:ok, String.t(), map()} | {:not_modified} | {:error, term()}
  defp fetch_feed(url, etag, last_modified) do
    headers = build_conditional_headers(etag, last_modified)

    case Req.get(url, headers: headers, receive_timeout: 15_000) do
      {:ok, %{status: 200, body: body, headers: resp_headers}} ->
        {:ok, body, parse_cache_headers(resp_headers)}

      {:ok, %{status: 304}} ->
        {:not_modified}

      {:ok, %{status: status}} ->
        {:error, gettext("HTTP %{status}", status: status)}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  @spec build_conditional_headers(String.t() | nil, String.t() | nil) :: [
          {String.t(), String.t()}
        ]
  defp build_conditional_headers(etag, last_modified) do
    headers = [{"user-agent", gettext("RetroHexChat-RSS/1.0")}]
    headers = if etag, do: [{"if-none-match", etag} | headers], else: headers
    if last_modified, do: [{"if-modified-since", last_modified} | headers], else: headers
  end

  @spec parse_cache_headers(%{String.t() => [String.t()]}) :: map()
  defp parse_cache_headers(headers) do
    etag = get_header(headers, "etag")
    last_mod = get_header(headers, "last-modified")
    %{etag: etag, last_modified: last_mod}
  end

  @spec get_header(%{String.t() => [String.t()]}, String.t()) :: String.t() | nil
  defp get_header(headers, name) do
    case Map.get(headers, name) do
      [value | _] -> value
      _ -> nil
    end
  end

  # ── Feed Processing ──

  @spec filter_new_items([FeedParser.feed_item()], String.t() | nil) :: [FeedParser.feed_item()]
  defp filter_new_items(items, nil), do: items

  defp filter_new_items(items, last_seen_link) do
    Enum.take_while(items, fn item -> item.link != last_seen_link end)
  end

  @spec maybe_update_last_seen(map(), [FeedParser.feed_item()]) :: map()
  defp maybe_update_last_seen(feed, []), do: feed

  defp maybe_update_last_seen(feed, [first | _]) do
    Map.put(feed, "last_seen_link", first.link)
  end

  @spec format_items([FeedParser.feed_item()], String.t() | nil) :: [String.t()]
  defp format_items(items, feed_title) do
    prefix = if feed_title, do: gettext("[%{title}]", title: feed_title), else: "[RSS]"

    Enum.map(items, fn item ->
      gettext("%{prefix} %{title} — %{link}",
        prefix: prefix,
        title: item.title,
        link: item.link
      )
    end)
  end

  # ── Helpers ──

  @spec find_feed([map()], String.t()) :: map() | nil
  defp find_feed(feeds, id), do: Enum.find(feeds, &(&1["id"] == id))

  @spec update_feed(map(), String.t(), map()) :: map()
  defp update_feed(state, id, updated_feed) do
    new_feeds =
      Enum.map(state.feeds, fn f ->
        if f["id"] == id, do: updated_feed, else: f
      end)

    %{state | feeds: new_feeds}
  end

  @spec valid_url?(String.t()) :: boolean()
  defp valid_url?(url) do
    String.starts_with?(url, "http://") or String.starts_with?(url, "https://")
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
