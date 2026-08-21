defmodule RetroHexChat.Scraper do
  @moduledoc """
  Reads a page from the open internet once, and serves it to everyone.

  The chat's URL Catcher and an RSS bot both want to know what a link points at.
  They used to ask separately: the catcher through a durable worker that kept only
  the title, the bot through a direct call that kept nothing at all. The same
  article arriving in two feeds, or a link posted in a channel and then published
  by a bot, cost a request every time. This context is the single place that asks,
  and `RetroHexChat.Scraper.Store` is the single place that remembers.

  ## Three ways in, because consumers genuinely differ

    * `preview/1` — what a render path wants: whatever is known right now, with a
      refresh arranged in the background if what is known has gone stale. Never
      blocks, never reaches the network on the calling process.
    * `fetch/2` and `fetch_many/2` — what a bot composing a message wants: the
      answer now, within a budget, scraping inline if nothing is stored.
    * `request/1` — fire and forget. Ensures a durable job exists and tells
      subscribers when it lands.

  ## Stale is not the same as absent

  With a 120-day archive an expired row is nearly always still right, so it is
  served immediately and revalidated behind the reader — usually with a conditional
  request the publisher answers `304`, which costs neither side a body. Returning
  `:miss` for an expired row would blank a preview that was about to be confirmed
  correct.
  """

  alias RetroHexChat.Jobs
  alias RetroHexChat.Jobs.PageScrapeWorker
  alias RetroHexChat.Observability
  alias RetroHexChat.Scraper.{Cache, Card, Client, ImageCache, ScrapedPage, Store}

  require Logger

  @topic "scraped_pages"

  @default_fetch_timeout_ms 2_000
  @default_max_concurrency 8

  @type preview :: {:ok, ScrapedPage.t()} | :pending | :unknown
  @type fetch_result :: {:ok, ScrapedPage.t()} | {:error, term()}

  # ── Reading ────────────────────────────────────────────────

  @doc """
  What is known about `url` right now, arranging a refresh if that is not enough.

  Returns `{:ok, page}` for anything worth showing — including an expired row,
  which is revalidated in the background. `:pending` means a fetch is on its way;
  `:unknown` means the page was tried and failed recently, and asking again before
  the failure expires would only repeat it.
  """
  @spec preview(String.t()) :: preview()
  def preview(url) do
    now = DateTime.utc_now()

    case lookup(url) do
      {:ok, page} -> preview_for(url, page, now)
      :miss -> request_and_report(url)
    end
  end

  @spec preview_for(String.t(), ScrapedPage.t(), DateTime.t()) :: preview()
  defp preview_for(url, page, now) do
    cond do
      Store.servable?(page) and Store.fresh?(page, now) ->
        record_hit(:fresh)
        _ = ImageCache.request(page)
        {:ok, page}

      Store.servable?(page) ->
        # Expired, but a 120-day-old title beats a blank line while the
        # conditional request that will confirm it is still in flight.
        record_hit(:stale)
        _ = ImageCache.request(page)
        _ = request(url)
        {:ok, page}

      page.status == "failed" and Store.fresh?(page, now) ->
        record_hit(:known_failure)
        :unknown

      page.status == "pending" and Store.fresh?(page, now) ->
        # Somebody already asked; saying so is different from saying there is
        # nothing to know, and the view renders the two differently.
        record_hit(:in_flight)
        :pending

      true ->
        request_and_report(url)
    end
  end

  @spec request_and_report(String.t()) :: :pending | :unknown
  defp request_and_report(url) do
    record_hit(:miss)

    case request(url) do
      :ok -> :pending
      {:error, _reason} -> :unknown
    end
  end

  @doc """
  The stored page for `url`, without ever reaching the network.

  Used where a request must not depend on the internet being reachable — and by
  tests that need to assert exactly that.
  """
  @spec get(String.t()) :: {:ok, ScrapedPage.t()} | :miss
  def get(url), do: lookup(url)

  @doc "Whether a page should be refreshed before it is trusted again."
  @spec stale?(ScrapedPage.t(), DateTime.t()) :: boolean()
  def stale?(%ScrapedPage{} = page, now \\ DateTime.utc_now()), do: not Store.fresh?(page, now)

  # ── Cards ──────────────────────────────────────────────────

  @doc """
  The identity the archive files a URL under, or `nil` if it files none.

  A render path holds it alongside the row it decorates, so a page that lands
  later can be matched to the rows waiting for it without re-parsing their text.
  Two addresses that differ only by campaign parameters share a fingerprint,
  which is the same reason they share a row.
  """
  @spec fingerprint(String.t()) :: String.t() | nil
  def fingerprint(url) do
    case Store.hash_url(url) do
      {:ok, url_hash} -> url_hash
      {:error, :invalid_url} -> nil
    end
  end

  @doc """
  The Markdown card for each fingerprint the archive can already answer.

  One query for a whole page of history, and never a request: a render path that
  could reach the network is a render path that can hang. Fingerprints with no
  stored page, or whose page has nothing worth showing, are absent from the map
  rather than present with `nil`.
  """
  @spec cards([String.t()]) :: %{String.t() => String.t()}
  def cards([]), do: %{}

  def cards(url_hashes) when is_list(url_hashes) do
    url_hashes
    |> Store.get_by_hashes()
    |> Enum.flat_map(fn {url_hash, page} -> card_entry(url_hash, page) end)
    |> Map.new()
  end

  @spec card_entry(String.t(), ScrapedPage.t()) :: [{String.t(), String.t()}]
  defp card_entry(url_hash, page) do
    case card(page) do
      nil -> []
      markdown -> [{url_hash, markdown}]
    end
  end

  @doc "The Markdown card for one page, or `nil` when it has nothing to show."
  @spec card(ScrapedPage.t()) :: String.t() | nil
  def card(%ScrapedPage{} = page) do
    if Store.servable?(page), do: Card.markdown(page)
  end

  # ── Fetching now ───────────────────────────────────────────

  @doc """
  Answers about `url` now, scraping if nothing usable is stored.

  Runs the request on the calling process, so callers on a latency budget pass
  `:timeout`. Two callers racing for the same URL do not both fetch: the first to
  claim it goes to the network and the rest read what it stores.
  """
  @spec fetch(String.t(), keyword()) :: fetch_result()
  def fetch(url, opts \\ []) do
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)

    with {:ok, prepared} <- Store.prepare_url(url) do
      case lookup_prepared(prepared) do
        {:ok, page} -> fetch_existing(prepared, page, opts, now)
        :miss -> scrape_now(prepared, nil, opts, now)
      end
    end
  end

  # Freshness alone is not a reason to skip the network — only an *answer* is. A
  # `pending` row is the note `request/1` leaves before enqueueing the job, and it
  # is fresh for the ten minutes that job has to run. Treating that as an answer
  # meant the worker looked at the note it had just written, concluded the page
  # was already handled, and returned without ever fetching it: the row stayed
  # `pending` for ever and the job completed successfully having done nothing.
  @spec fetch_existing(Store.prepared_url(), ScrapedPage.t(), keyword(), DateTime.t()) ::
          fetch_result()
  defp fetch_existing(prepared, page, opts, now) do
    cond do
      Store.servable?(page) and Store.fresh?(page, now) ->
        record_hit(:fresh)
        Store.touch_access(page, now: now)
        {:ok, prepare_thumbnail(page, opts)}

      Store.attempted?(page) and Store.fresh?(page, now) ->
        record_hit(:known_failure)
        {:error, stored_error(page)}

      true ->
        scrape_now(prepared, page, opts, now)
    end
  end

  @doc """
  `fetch/2` over many URLs at once, bounded.

  Results come back in the order the URLs were given, so a caller can zip them
  against whatever it is building.
  """
  @spec fetch_many([String.t()], keyword()) :: [fetch_result()]
  def fetch_many(urls, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_fetch_timeout_ms)
    max_concurrency = Keyword.get(opts, :max_concurrency, @default_max_concurrency)

    urls
    |> Task.async_stream(&fetch(&1, opts),
      max_concurrency: max_concurrency,
      ordered: true,
      on_timeout: :kill_task,
      timeout: timeout
    )
    |> Enum.map(fn
      {:ok, result} -> result
      {:exit, reason} -> {:error, reason}
    end)
  end

  @spec scrape_now(Store.prepared_url(), ScrapedPage.t() | nil, keyword(), DateTime.t()) ::
          fetch_result()
  defp scrape_now(prepared, existing, opts, now) do
    case Cache.claim(prepared.url_hash) do
      :ok ->
        try do
          do_scrape(prepared, existing, opts, now)
        after
          Cache.release(prepared.url_hash)
        end

      :taken ->
        # Somebody else is already asking the publisher. Their answer will be
        # stored in a moment; adding a second request would not make it arrive
        # sooner.
        record_hit(:in_flight)
        if existing && Store.servable?(existing), do: {:ok, existing}, else: {:error, :in_flight}
    end
  end

  @spec do_scrape(Store.prepared_url(), ScrapedPage.t() | nil, keyword(), DateTime.t()) ::
          fetch_result()
  defp do_scrape(prepared, existing, opts, now) do
    record_hit(:scrape)

    case Client.impl().scrape(prepared.url, conditional_opts(existing)) do
      {:ok, scrape} ->
        store_success(prepared.url, scrape, opts, now)

      {:not_modified} when not is_nil(existing) ->
        renew(existing, opts, now)

      {:not_modified} ->
        {:error, :not_modified}

      {:error, reason} ->
        store_failure(prepared, existing, reason, opts, now)
    end
  end

  @spec store_success(String.t(), Client.scrape(), keyword(), DateTime.t()) :: fetch_result()
  defp store_success(url, scrape, opts, now) do
    case Store.record_success(url, Client.to_page_attrs(scrape), now: now) do
      {:ok, page} ->
        page = prepare_thumbnail(page, opts)
        cache_and_announce(page)
        {:ok, page}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec renew(ScrapedPage.t(), keyword(), DateTime.t()) :: fetch_result()
  defp renew(page, opts, now) do
    case Store.record_not_modified(page, now: now) do
      {:ok, renewed} ->
        record_hit(:not_modified)
        renewed = prepare_thumbnail(renewed, opts)
        cache_and_announce(renewed)
        {:ok, renewed}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec prepare_thumbnail(ScrapedPage.t(), keyword()) :: ScrapedPage.t()
  defp prepare_thumbnail(%ScrapedPage{} = page, opts) do
    case Keyword.get(opts, :thumbnail, :async) do
      :sync ->
        case ImageCache.ensure_thumbnail(page, opts) do
          {:ok, updated} -> updated
          {:error, _reason, updated} -> updated
        end

      :skip ->
        page

      _async ->
        _ = ImageCache.request(page)
        page
    end
  end

  # A page that used to answer keeps answering when a refresh fails: the failure
  # is about this attempt, not about what was already read successfully.
  @spec store_failure(
          Store.prepared_url(),
          ScrapedPage.t() | nil,
          term(),
          keyword(),
          DateTime.t()
        ) :: fetch_result()
  defp store_failure(prepared, existing, reason, opts, now) do
    attempt = Keyword.get(opts, :attempt, 1)

    result =
      if Store.retryable_error?(reason) do
        Store.record_retryable_failure(prepared.url, reason, attempt: attempt, now: now)
      else
        Store.record_failure(prepared.url, reason, attempt: attempt, now: now)
      end

    case result do
      {:ok, page} ->
        cache_and_announce(page)
        if existing && Store.servable?(existing), do: {:ok, existing}, else: {:error, reason}

      {:error, store_error} ->
        {:error, store_error}
    end
  end

  @spec conditional_opts(ScrapedPage.t() | nil) :: Client.opts()
  defp conditional_opts(%ScrapedPage{status: "ready", etag: etag, last_modified: last_modified}),
    do: [if_none_match: etag, if_modified_since: last_modified]

  defp conditional_opts(_page), do: []

  # ── Asking for a fetch later ───────────────────────────────

  @doc """
  Ensures a durable scrape of `url` is on its way.

  Idempotent by URL: the worker's uniqueness constraint collapses repeat asks into
  one job, so a link posted to five channels at once is fetched once.
  """
  @spec request(String.t()) :: :ok | {:error, term()}
  def request(url) do
    with {:ok, pending} <- Store.ensure_pending(url),
         {:ok, _job} <-
           Jobs.insert(PageScrapeWorker.new(%{url: pending.url, url_hash: pending.url_hash})) do
      :ok
    else
      {:error, reason} ->
        Logger.warning("scrape_request_error reason=#{inspect(reason)}")
        {:error, reason}
    end
  end

  # ── Announcing ─────────────────────────────────────────────

  @doc "PubSub topic carrying scrape outcomes."
  @spec topic() :: String.t()
  def topic, do: @topic

  @spec subscribe() :: :ok | {:error, term()}
  def subscribe, do: Phoenix.PubSub.subscribe(RetroHexChat.PubSub, @topic)

  @doc """
  Tells subscribers a page settled.

  Deliberately thin. Every connected LiveView is on this topic, so the payload is
  copied into every one of them; the page itself stays in the store, and anyone
  who wants more than the headline calls `get/1`.
  """
  @spec announce(ScrapedPage.t()) :: :ok | {:error, term()}
  def announce(%ScrapedPage{} = page) do
    Phoenix.PubSub.broadcast(
      RetroHexChat.PubSub,
      @topic,
      {:scraped_page,
       %{
         url: page.url,
         url_hash: page.url_hash,
         status: page.status,
         title: page.title
       }}
    )
  end

  @spec cache_and_announce(ScrapedPage.t()) :: :ok
  def cache_and_announce(%ScrapedPage{} = page) do
    Cache.put(page)
    _ = announce(page)
    :ok
  end

  # ── Lookups ────────────────────────────────────────────────

  @spec lookup(String.t()) :: {:ok, ScrapedPage.t()} | :miss
  defp lookup(url) do
    case Store.prepare_url(url) do
      {:ok, prepared} -> lookup_prepared(prepared)
      {:error, :invalid_url} -> :miss
    end
  end

  @spec lookup_prepared(Store.prepared_url()) :: {:ok, ScrapedPage.t()} | :miss
  defp lookup_prepared(%{url_hash: url_hash}) do
    case Cache.get(url_hash) do
      {:ok, page} ->
        {:ok, page}

      :miss ->
        case Store.get_by_hash(url_hash) do
          %ScrapedPage{} = page ->
            Cache.put(page)
            {:ok, page}

          nil ->
            :miss
        end
    end
  end

  @spec stored_error(ScrapedPage.t()) :: term()
  defp stored_error(%ScrapedPage{error_reason: nil}), do: :no_metadata
  defp stored_error(%ScrapedPage{error_reason: reason}), do: reason

  # Whether sharing one archive across consumers actually stopped requests is not
  # a question a row count can answer — a hit leaves no trace. This counter is the
  # only evidence, and it is why the table carries no `hit_count` column.
  @spec record_hit(atom()) :: :ok
  defp record_hit(outcome) do
    Observability.record_event([:retro_hex_chat, :scraper, :lookup], %{count: 1}, %{
      outcome: outcome
    })
  end
end
