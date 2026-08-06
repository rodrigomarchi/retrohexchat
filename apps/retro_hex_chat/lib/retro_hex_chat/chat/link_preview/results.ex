defmodule RetroHexChat.Chat.LinkPreview.Results do
  @moduledoc """
  Durable storage boundary for URL Catcher link previews.
  """

  import Ecto.Query

  alias RetroHexChat.Chat.LinkPreview.Result
  alias RetroHexChat.Net.HTTPRetry
  alias RetroHexChat.Repo

  @success_ttl_seconds :timer.hours(1) |> div(1_000)
  @error_ttl_seconds :timer.minutes(5) |> div(1_000)
  @pending_ttl_seconds :timer.minutes(10) |> div(1_000)

  @type cache_result :: {:ok, String.t() | :error} | :miss
  @type prepared_url :: %{url: String.t(), url_hash: String.t()}
  @type fetch_error :: atom() | {:http_status, pos_integer()} | term()

  @spec prepare_url(String.t()) :: {:ok, prepared_url()} | {:error, :invalid_url}
  def prepare_url(url) when is_binary(url) do
    with {:ok, normalized_url} <- normalize_url(url),
         {:ok, url_hash} <- hash_url(normalized_url) do
      {:ok, %{url: normalized_url, url_hash: url_hash}}
    end
  end

  @spec normalize_url(String.t()) :: {:ok, String.t()} | {:error, :invalid_url}
  def normalize_url(url) when is_binary(url) do
    uri = url |> String.trim() |> URI.parse()

    with scheme when scheme in ["http", "https"] <- normalized_scheme(uri.scheme),
         host when is_binary(host) and host != "" <- normalized_host(uri.host) do
      uri =
        %URI{
          uri
          | scheme: scheme,
            host: host,
            port: normalized_port(uri.port, scheme),
            fragment: nil
        }

      {:ok, URI.to_string(uri)}
    else
      _other -> {:error, :invalid_url}
    end
  rescue
    _error -> {:error, :invalid_url}
  end

  @spec hash_url(String.t()) :: {:ok, String.t()} | {:error, :invalid_url}
  def hash_url(url) when is_binary(url) do
    with {:ok, normalized_url} <- normalize_url(url) do
      {:ok, digest(normalized_url)}
    end
  end

  @spec get_fresh(String.t(), keyword()) :: cache_result()
  def get_fresh(url, opts \\ []) do
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)

    with {:ok, %{url_hash: url_hash}} <- prepare_url(url),
         %Result{} = result <- get_by_hash(url_hash),
         true <- fresh?(result, now) do
      result_to_cache(result)
    else
      _other -> :miss
    end
  end

  @spec pending?(String.t(), keyword()) :: boolean()
  def pending?(url, opts \\ []) do
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)

    with {:ok, %{url_hash: url_hash}} <- prepare_url(url),
         %Result{status: "pending"} = result <- get_by_hash(url_hash) do
      fresh?(result, now)
    else
      _other -> false
    end
  end

  @spec ensure_pending(String.t(), keyword()) ::
          {:ok, Result.t()} | {:error, :invalid_url | Ecto.Changeset.t()}
  def ensure_pending(url, opts \\ []) do
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)

    with {:ok, prepared} <- prepare_url(url) do
      attrs = %{
        url: prepared.url,
        url_hash: prepared.url_hash,
        status: "pending",
        title: nil,
        metadata: %{},
        error_reason: nil,
        error_detail: %{},
        attempts: 0,
        last_attempted_at: nil,
        fetched_at: nil,
        expires_at: DateTime.add(now, @pending_ttl_seconds, :second)
      }

      case get_by_hash(prepared.url_hash) do
        %Result{} = result ->
          result
          |> Result.changeset(attrs)
          |> Repo.update()

        nil ->
          %Result{}
          |> Result.changeset(attrs)
          |> Repo.insert()
      end
    end
  end

  @spec record_success(String.t(), String.t(), keyword()) ::
          {:ok, Result.t()} | {:error, :invalid_url | Ecto.Changeset.t()}
  def record_success(url, title, opts \\ []) when is_binary(title) do
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)
    attempt = Keyword.get(opts, :attempt, 1)

    upsert_result(url, %{
      status: "ready",
      title: title,
      metadata: %{},
      error_reason: nil,
      error_detail: %{},
      attempts: max(attempt, 1),
      last_attempted_at: now,
      fetched_at: now,
      expires_at: DateTime.add(now, @success_ttl_seconds, :second)
    })
  end

  @spec record_retryable_failure(String.t(), fetch_error(), keyword()) ::
          {:ok, Result.t()} | {:error, :invalid_url | Ecto.Changeset.t()}
  def record_retryable_failure(url, reason, opts \\ []) do
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)
    attempt = Keyword.get(opts, :attempt, 1)

    upsert_result(url, %{
      status: "pending",
      title: nil,
      metadata: %{},
      error_reason: error_reason(reason),
      error_detail: error_detail(reason),
      attempts: max(attempt, 1),
      last_attempted_at: now,
      fetched_at: nil,
      expires_at: DateTime.add(now, @pending_ttl_seconds, :second)
    })
  end

  @spec record_failure(String.t(), fetch_error(), keyword()) ::
          {:ok, Result.t()} | {:error, :invalid_url | Ecto.Changeset.t()}
  def record_failure(url, reason, opts \\ []) do
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)
    attempt = Keyword.get(opts, :attempt, 1)

    upsert_result(url, %{
      status: "failed",
      title: nil,
      metadata: %{},
      error_reason: error_reason(reason),
      error_detail: error_detail(reason),
      attempts: max(attempt, 1),
      last_attempted_at: now,
      fetched_at: now,
      expires_at: DateTime.add(now, @error_ttl_seconds, :second)
    })
  end

  @spec stats(keyword()) :: [map()]
  def stats(opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)

    Result
    |> group_by([result], result.status)
    |> select([result], %{
      status: result.status,
      count: count(result.id),
      expired: fragment("count(*) filter (where ? <= ?)", result.expires_at, ^now),
      oldest_attempted_at: min(result.last_attempted_at),
      newest_fetched_at: max(result.fetched_at)
    })
    |> repo.all()
  end

  @spec expired_count(keyword()) :: non_neg_integer()
  def expired_count(opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)

    repo.one(
      from result in Result,
        where: result.expires_at <= ^now,
        select: count(result.id)
    )
  end

  @spec error_reason(fetch_error()) :: String.t()
  def error_reason({:http_status, status}) when is_integer(status), do: "http_#{status}"
  def error_reason(reason) when is_atom(reason), do: Atom.to_string(reason)
  def error_reason(reason) when is_binary(reason), do: reason
  def error_reason(_reason), do: "unknown"

  @spec retryable_error?(fetch_error()) :: boolean()
  def retryable_error?(reason), do: HTTPRetry.retryable?(reason)

  @spec get_by_hash(String.t()) :: Result.t() | nil
  def get_by_hash(url_hash) when is_binary(url_hash) do
    Repo.get_by(Result, url_hash: url_hash)
  end

  defp upsert_result(url, attrs) do
    with {:ok, prepared} <- prepare_url(url) do
      attrs = Map.merge(attrs, %{url: prepared.url, url_hash: prepared.url_hash})

      case get_by_hash(prepared.url_hash) do
        %Result{} = result ->
          result
          |> Result.changeset(attrs)
          |> Repo.update()

        nil ->
          %Result{}
          |> Result.changeset(attrs)
          |> Repo.insert()
      end
    end
  end

  defp fresh?(%Result{expires_at: expires_at}, %DateTime{} = now) do
    DateTime.compare(expires_at, now) == :gt
  end

  defp result_to_cache(%Result{status: "ready", title: title}), do: {:ok, title}
  defp result_to_cache(%Result{status: "failed"}), do: {:ok, :error}
  defp result_to_cache(_result), do: :miss

  defp normalized_scheme(nil), do: nil
  defp normalized_scheme(scheme), do: String.downcase(scheme)

  defp normalized_host(nil), do: nil
  defp normalized_host(host), do: String.downcase(host)

  defp normalized_port(80, "http"), do: nil
  defp normalized_port(443, "https"), do: nil
  defp normalized_port(port, _scheme), do: port

  defp digest(url) do
    :sha256
    |> :crypto.hash(url)
    |> Base.encode16(case: :lower)
  end

  defp error_detail({:http_status, status}) when is_integer(status),
    do: %{"http_status" => status}

  defp error_detail(_reason), do: %{}
end
