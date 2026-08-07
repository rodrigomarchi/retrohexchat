defmodule RetroHexChat.Scraper.Store do
  @moduledoc """
  Persistence boundary for scraped pages.

  Everything that decides *what a URL is* lives here — normalisation, hashing,
  freshness — because two URLs that name the same page must reach the same row or
  the whole point of scraping once is lost.

  Retention is 120 days, which makes this an archive rather than a cache. Three
  consequences follow, and they are why the module looks the way it does:

    * An expired row is **revalidated, not discarded**. `etag`/`last_modified` go
      back to the publisher as a conditional request; a `304` renews the row for
      another 120 days without downloading anything.
    * Pruning keys on `last_accessed_at`, never on `expires_at`. Over 120 days those
      mean opposite things: expired says "check this again", idle says "nobody asks
      for this any more". Deleting by `expires_at` would evict exactly the pages
      still in use.
    * Improving the extractor leaves four months of rows parsed by the old one, so
      `scraper_version` is part of the staleness test and not merely a record.
  """

  import Ecto.Query

  alias RetroHexChat.Net.HTTPRetry
  alias RetroHexChat.Repo
  alias RetroHexChat.Scraper.ScrapedPage

  @success_ttl_seconds 120 * 24 * 60 * 60
  @deterministic_error_ttl_seconds 7 * 24 * 60 * 60
  @transient_error_ttl_seconds 15 * 60
  @pending_ttl_seconds 10 * 60

  # Bumped when the extractor learns to read something it previously missed.
  # Rows below the current version are stale regardless of `expires_at`.
  @scraper_version 1

  # Parameters that identify a campaign, not a page. Feeds are saturated with
  # them, so leaving them in means scraping the same article once per referrer.
  @tracking_params ~w(fbclid gclid dclid msclkid)
  @tracking_prefixes ~w(utm_)

  @type prepared_url :: %{url: String.t(), url_hash: String.t()}
  @type fetch_error :: atom() | {:http_status, pos_integer()} | term()

  @doc "The extractor generation rows are currently written with."
  @spec scraper_version() :: pos_integer()
  def scraper_version, do: @scraper_version

  @doc "How long a successful scrape stays fresh, in seconds."
  @spec success_ttl_seconds() :: pos_integer()
  def success_ttl_seconds, do: @success_ttl_seconds

  # ── URL identity ───────────────────────────────────────────

  @spec prepare_url(String.t()) :: {:ok, prepared_url()} | {:error, :invalid_url}
  def prepare_url(url) when is_binary(url) do
    with {:ok, normalized_url} <- normalize_url(url) do
      {:ok, %{url: normalized_url, url_hash: digest(normalized_url)}}
    end
  end

  def prepare_url(_url), do: {:error, :invalid_url}

  @doc """
  Reduces a URL to the page it names.

  Drops the fragment (never sent to a server), the default port, and campaign
  parameters; downcases scheme and host, which are case-insensitive. Path and the
  remaining query are left exactly as written — they routinely select content.
  """
  @spec normalize_url(String.t()) :: {:ok, String.t()} | {:error, :invalid_url}
  def normalize_url(url) when is_binary(url) do
    uri = url |> String.trim() |> URI.parse()

    with scheme when scheme in ["http", "https"] <- normalized_scheme(uri.scheme),
         host when is_binary(host) and host != "" <- normalized_host(uri.host) do
      uri = %URI{
        uri
        | scheme: scheme,
          host: host,
          port: normalized_port(uri.port, scheme),
          query: normalized_query(uri.query),
          fragment: nil
      }

      {:ok, URI.to_string(uri)}
    else
      _other -> {:error, :invalid_url}
    end
  rescue
    _error -> {:error, :invalid_url}
  end

  def normalize_url(_url), do: {:error, :invalid_url}

  @spec hash_url(String.t()) :: {:ok, String.t()} | {:error, :invalid_url}
  def hash_url(url) when is_binary(url) do
    with {:ok, normalized_url} <- normalize_url(url), do: {:ok, digest(normalized_url)}
  end

  def hash_url(_url), do: {:error, :invalid_url}

  # ── Reads ──────────────────────────────────────────────────

  @spec get_by_hash(String.t()) :: ScrapedPage.t() | nil
  def get_by_hash(url_hash) when is_binary(url_hash) do
    Repo.get_by(ScrapedPage, url_hash: url_hash)
  end

  @spec get_by_url(String.t()) :: ScrapedPage.t() | nil
  def get_by_url(url) do
    case prepare_url(url) do
      {:ok, %{url_hash: url_hash}} -> get_by_hash(url_hash)
      {:error, :invalid_url} -> nil
    end
  end

  @doc """
  Whether a row still answers without going back to the publisher.

  A row written by an older extractor is stale even inside its TTL: the point of
  a new extractor is that it reads something the old one could not.
  """
  @spec fresh?(ScrapedPage.t(), DateTime.t()) :: boolean()
  def fresh?(%ScrapedPage{expires_at: expires_at, scraper_version: version}, %DateTime{} = now) do
    version >= @scraper_version and DateTime.compare(expires_at, now) == :gt
  end

  @doc """
  Whether a row carries content worth showing while it is refreshed.

  This is what makes an expired page render instantly instead of blanking: the
  120-day-old title is still a better answer than nothing while the conditional
  request is in flight.
  """
  @spec servable?(ScrapedPage.t()) :: boolean()
  def servable?(%ScrapedPage{status: "ready"}), do: true
  def servable?(%ScrapedPage{}), do: false

  @doc """
  Whether the publisher has actually been contacted about this row.

  The difference between the two kinds of `pending` row, and it matters. One is
  the note `request/1` leaves before enqueueing a job — never attempted, and
  reading it must not stop the fetch it exists to announce. The other is a
  transient failure backing off, and reading *that* must not start a new fetch on
  every lookup, or a site that is briefly down gets hammered instead of retried.
  """
  @spec attempted?(ScrapedPage.t()) :: boolean()
  def attempted?(%ScrapedPage{status: "failed"}), do: true
  def attempted?(%ScrapedPage{attempts: attempts}), do: attempts > 0

  @doc "Records that a row answered a question, so pruning can tell hot from idle."
  @spec touch_access(ScrapedPage.t() | String.t(), keyword()) :: :ok
  def touch_access(%ScrapedPage{url_hash: url_hash}, opts), do: touch_access(url_hash, opts)

  def touch_access(url_hash, opts) when is_binary(url_hash) do
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)

    ScrapedPage
    |> where([page], page.url_hash == ^url_hash)
    |> Repo.update_all(set: [last_accessed_at: now])

    :ok
  end

  # ── Writes ─────────────────────────────────────────────────

  @doc """
  Writes a row for `url`, replacing whatever was there.

  A real upsert, not read-then-write: two pollers finishing the same page at the
  same instant used to race into a lost update or a unique violation, and the
  shared cache makes that collision the normal case rather than the exotic one.

  `attrs` must describe the row completely — the conflict clause replaces every
  column, so a partial map would blank the fields it omits.
  """
  @spec upsert(String.t(), map(), keyword()) ::
          {:ok, ScrapedPage.t()} | {:error, :invalid_url | Ecto.Changeset.t()}
  def upsert(url, attrs, opts \\ []) do
    with {:ok, prepared} <- prepare_url(url) do
      now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)

      attrs =
        attrs
        |> Map.merge(%{url: prepared.url, url_hash: prepared.url_hash})
        |> Map.put_new(:last_accessed_at, now)
        |> Map.put_new(:scraper_version, @scraper_version)

      %ScrapedPage{}
      |> ScrapedPage.changeset(attrs)
      |> Repo.insert(
        on_conflict: {:replace_all_except, [:id, :inserted_at, :url_hash]},
        conflict_target: :url_hash,
        returning: true
      )
    end
  end

  @doc """
  Marks a URL as being scraped.

  Unlike the row it replaces, this never blanks content: a page already `ready`
  keeps its title and image and only gains `revalidating_since`, so a refresh in
  flight is invisible to whoever is reading.
  """
  @spec ensure_pending(String.t(), keyword()) ::
          {:ok, ScrapedPage.t()} | {:error, :invalid_url | Ecto.Changeset.t()}
  def ensure_pending(url, opts \\ []) do
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)

    with {:ok, prepared} <- prepare_url(url) do
      case get_by_hash(prepared.url_hash) do
        nil ->
          upsert(
            url,
            %{
              status: "pending",
              raw_metadata: %{},
              error_detail: %{},
              attempts: 0,
              revalidating_since: now,
              expires_at: DateTime.add(now, @pending_ttl_seconds, :second)
            },
            now: now
          )

        %ScrapedPage{} = page ->
          page
          |> ScrapedPage.changeset(%{revalidating_since: now})
          |> Repo.update()
      end
    end
  end

  @spec record_success(String.t(), map(), keyword()) ::
          {:ok, ScrapedPage.t()} | {:error, :invalid_url | Ecto.Changeset.t()}
  def record_success(url, page_attrs, opts \\ []) do
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)
    attempt = opts |> Keyword.get(:attempt, 1) |> max(1)

    attrs =
      page_attrs
      |> Map.merge(%{
        status: "ready",
        error_reason: nil,
        error_detail: %{},
        attempts: attempt,
        last_attempted_at: now,
        fetched_at: now,
        revalidating_since: nil,
        expires_at: DateTime.add(now, @success_ttl_seconds, :second)
      })
      |> Map.put_new(:raw_metadata, %{})

    upsert(url, attrs, now: now)
  end

  @doc """
  Extends a row that the publisher answered `304 Not Modified` for.

  The cheapest possible refresh: no body was transferred, nothing about the page
  changed, so only the clock moves. `fetched_at` deliberately stays put — it
  records when the content was last actually read, which is what a reader of this
  table wants to know.
  """
  @spec record_not_modified(ScrapedPage.t(), keyword()) ::
          {:ok, ScrapedPage.t()} | {:error, Ecto.Changeset.t()}
  def record_not_modified(%ScrapedPage{} = page, opts \\ []) do
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)

    page
    |> ScrapedPage.changeset(%{
      last_attempted_at: now,
      revalidating_since: nil,
      expires_at: DateTime.add(now, @success_ttl_seconds, :second)
    })
    |> Repo.update()
  end

  @doc """
  Records a failure that is worth trying again shortly.

  Stays `pending` on purpose: the row is not an answer, and leaving it `failed`
  would make a blip look like a verdict.
  """
  @spec record_retryable_failure(String.t(), fetch_error(), keyword()) ::
          {:ok, ScrapedPage.t()} | {:error, :invalid_url | Ecto.Changeset.t()}
  def record_retryable_failure(url, reason, opts \\ []) do
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)
    attempt = opts |> Keyword.get(:attempt, 1) |> max(1)

    upsert(
      url,
      %{
        status: "pending",
        raw_metadata: %{},
        error_reason: error_reason(reason),
        error_detail: error_detail(reason),
        attempts: attempt,
        last_attempted_at: now,
        fetched_at: nil,
        expires_at: DateTime.add(now, @transient_error_ttl_seconds, :second)
      },
      now: now
    )
  end

  @spec record_failure(String.t(), fetch_error(), keyword()) ::
          {:ok, ScrapedPage.t()} | {:error, :invalid_url | Ecto.Changeset.t()}
  def record_failure(url, reason, opts \\ []) do
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)
    attempt = opts |> Keyword.get(:attempt, 1) |> max(1)

    upsert(
      url,
      %{
        status: "failed",
        raw_metadata: %{},
        error_reason: error_reason(reason),
        error_detail: error_detail(reason),
        attempts: attempt,
        last_attempted_at: now,
        fetched_at: now,
        revalidating_since: nil,
        expires_at: DateTime.add(now, failure_ttl_seconds(reason), :second)
      },
      now: now
    )
  end

  # A 404 or a 410 is the publisher's answer, not a hiccup, so it is worth
  # remembering for a week. It is not worth remembering for the full 120 days: a
  # mistyped path gets fixed, and a page that returns for good should not stay
  # dead in the archive until autumn.
  @spec failure_ttl_seconds(fetch_error()) :: pos_integer()
  defp failure_ttl_seconds({:http_status, status}) when status in [404, 410],
    do: @deterministic_error_ttl_seconds

  defp failure_ttl_seconds(:not_found), do: @deterministic_error_ttl_seconds
  defp failure_ttl_seconds(_reason), do: @transient_error_ttl_seconds

  @spec error_reason(fetch_error()) :: String.t()
  def error_reason({:http_status, status}) when is_integer(status), do: "http_#{status}"
  def error_reason(reason) when is_atom(reason), do: Atom.to_string(reason)
  def error_reason(reason) when is_binary(reason), do: reason
  def error_reason(_reason), do: "unknown"

  @spec retryable_error?(fetch_error()) :: boolean()
  def retryable_error?(reason), do: HTTPRetry.retryable?(reason)

  # ── Reporting and upkeep ───────────────────────────────────

  @spec stats(keyword()) :: [map()]
  def stats(opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)

    ScrapedPage
    |> group_by([page], page.status)
    |> select([page], %{
      status: page.status,
      count: count(page.id),
      retrying:
        fragment(
          """
          count(*) filter (
            where ? = 'pending'
              and (
                ? in ('fetch_failed', 'server_error', 'timeout', 'http_408', 'http_425', 'http_429')
                or ? like 'http_5%'
              )
          )
          """,
          page.status,
          page.error_reason,
          page.error_reason
        ),
      final_failures: fragment("count(*) filter (where ? = 'failed')", page.status),
      expired: fragment("count(*) filter (where ? <= ?)", page.expires_at, ^now),
      oldest_attempted_at: min(page.last_attempted_at),
      newest_fetched_at: max(page.fetched_at)
    })
    |> repo.all()
  end

  @ready_idle_days 90
  @failure_grace_days 7

  @doc """
  Deletes rows nobody asks for any more.

  Keyed on `last_accessed_at`, not `expires_at` — see the module doc. Returns the
  same shape as the other maintenance workers so it needs no new telemetry keys.
  """
  @spec prune(keyword()) :: %{
          candidates: non_neg_integer(),
          deleted: non_neg_integer(),
          oldest_expired_age_ms: non_neg_integer()
        }
  def prune(opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)
    limit = Keyword.get(opts, :limit, 500)

    idle_before = DateTime.add(now, -@ready_idle_days * 24 * 60 * 60, :second)
    failure_before = DateTime.add(now, -@failure_grace_days * 24 * 60 * 60, :second)

    query = prunable(idle_before, failure_before)
    candidates = repo.one(from page in subquery(query), select: count(page.id))
    oldest = repo.one(from page in subquery(query), select: min(page.last_accessed_at))

    ids = query |> select([page], page.id) |> limit(^limit) |> repo.all()

    {deleted, _} =
      ScrapedPage
      |> where([page], page.id in ^ids)
      |> repo.delete_all()

    %{
      candidates: candidates || 0,
      deleted: deleted,
      oldest_expired_age_ms: age_ms(oldest, now)
    }
  end

  @spec prunable(DateTime.t(), DateTime.t()) :: Ecto.Query.t()
  defp prunable(idle_before, failure_before) do
    from page in ScrapedPage,
      where:
        (page.status == "ready" and page.last_accessed_at < ^idle_before) or
          (page.status != "ready" and page.expires_at < ^failure_before)
  end

  @spec age_ms(DateTime.t() | nil, DateTime.t()) :: non_neg_integer()
  defp age_ms(nil, _now), do: 0
  defp age_ms(%DateTime{} = oldest, now), do: max(DateTime.diff(now, oldest, :millisecond), 0)

  # ── URL helpers ────────────────────────────────────────────

  @spec normalized_scheme(String.t() | nil) :: String.t() | nil
  defp normalized_scheme(nil), do: nil
  defp normalized_scheme(scheme), do: String.downcase(scheme)

  @spec normalized_host(String.t() | nil) :: String.t() | nil
  defp normalized_host(nil), do: nil
  defp normalized_host(host), do: String.downcase(host)

  @spec normalized_port(non_neg_integer() | nil, String.t()) :: non_neg_integer() | nil
  defp normalized_port(80, "http"), do: nil
  defp normalized_port(443, "https"), do: nil
  defp normalized_port(port, _scheme), do: port

  @spec normalized_query(String.t() | nil) :: String.t() | nil
  defp normalized_query(nil), do: nil

  defp normalized_query(query) do
    case query |> URI.query_decoder() |> Enum.reject(&tracking_param?/1) do
      [] -> nil
      kept -> URI.encode_query(kept)
    end
  rescue
    _error -> query
  end

  @spec tracking_param?({String.t(), String.t()}) :: boolean()
  defp tracking_param?({key, _value}) do
    key = String.downcase(key)
    key in @tracking_params or Enum.any?(@tracking_prefixes, &String.starts_with?(key, &1))
  end

  @spec digest(String.t()) :: String.t()
  defp digest(url), do: :sha256 |> :crypto.hash(url) |> Base.encode16(case: :lower)

  @spec error_detail(fetch_error()) :: map()
  defp error_detail({:http_status, status}) when is_integer(status),
    do: %{"http_status" => status}

  defp error_detail(_reason), do: %{}
end
