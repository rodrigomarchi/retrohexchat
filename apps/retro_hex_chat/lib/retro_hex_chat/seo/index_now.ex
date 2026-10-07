defmodule RetroHexChat.SEO.IndexNow do
  @moduledoc """
  Tells search engines which public URLs changed, instead of waiting for them to crawl.

  IndexNow is one POST shared by Bing, Yandex, Seznam and Naver: the host, a
  key, where the key is published, and up to ten thousand URLs. The engine
  fetches the key from that location to prove the host sent it, so the key is
  public by design and lives in config, not in a secret store; the web layer
  serves it at `/indexnow.txt`.

  Every URL in a request must be on one host, and that host is read from the
  URLs themselves, so what is announced is always what the sitemap names.
  """

  @endpoint "https://api.indexnow.org/indexnow"
  @key_path "/indexnow.txt"
  @batch_size 10_000

  @type reason :: {:http_status, pos_integer()} | :timeout | :fetch_failed | :mixed_hosts
  @type summary :: %{submitted: non_neg_integer(), batches: non_neg_integer()}

  @doc "Whether announcing is switched on; off everywhere but production."
  @spec enabled?() :: boolean()
  def enabled?, do: config(:enabled, false) == true

  @doc "The key the engines verify against `/indexnow.txt`."
  @spec key() :: String.t()
  def key, do: config(:key, "")

  @doc "Where the key is published, relative to the host."
  @spec key_path() :: String.t()
  def key_path, do: @key_path

  @doc """
  Announces `urls`, in as many requests as the protocol's limit requires.

  Stops at the first refused request: the ones after it would be refused for
  the same reason, and a retry resends them all anyway.
  """
  @spec submit([String.t()]) :: {:ok, summary()} | {:error, reason()}
  def submit(urls) when is_list(urls) do
    urls = Enum.uniq(urls)

    with {:ok, payloads} <- payloads(urls, key()) do
      Enum.reduce_while(payloads, {:ok, %{submitted: 0, batches: 0}}, &send_batch/2)
    end
  end

  @spec send_batch(map(), {:ok, summary()}) ::
          {:cont, {:ok, summary()}} | {:halt, {:error, reason()}}
  defp send_batch(payload, {:ok, acc}) do
    case post(payload) do
      :ok ->
        {:cont,
         {:ok, %{submitted: acc.submitted + length(payload.urlList), batches: acc.batches + 1}}}

      {:error, reason} ->
        {:halt, {:error, reason}}
    end
  end

  @doc """
  The request bodies for `urls`, one per batch of at most ten thousand.

  Refuses URLs on more than one host: the protocol rejects the whole request,
  and saying so here names the cause instead of an HTTP 422.
  """
  @spec payloads([String.t()], String.t()) :: {:ok, [map()]} | {:error, :mixed_hosts}
  def payloads([], _key), do: {:ok, []}

  def payloads(urls, key) do
    origins = urls |> Enum.map(&origin/1) |> Enum.uniq()

    case origins do
      [{scheme, host}] ->
        {:ok,
         urls
         |> Enum.chunk_every(@batch_size)
         |> Enum.map(fn batch ->
           %{
             host: host,
             key: key,
             keyLocation: "#{scheme}://#{host}#{@key_path}",
             urlList: batch
           }
         end)}

      _ ->
        {:error, :mixed_hosts}
    end
  end

  @spec origin(String.t()) :: {String.t(), String.t()}
  defp origin(url) do
    uri = URI.parse(url)
    {uri.scheme, uri.host}
  end

  # 200 is "received", 202 is "received, key not yet verified": both mean the
  # engine has the list. Everything else is a refusal or a failure.
  @spec post(map()) :: :ok | {:error, reason()}
  defp post(payload) do
    [url: @endpoint, json: payload, receive_timeout: 10_000, retry: false]
    |> Keyword.merge(Application.get_env(:retro_hex_chat, :index_now_req_options, []))
    |> Req.post()
    |> case do
      {:ok, %Req.Response{status: status}} when status in [200, 202] -> :ok
      {:ok, %Req.Response{status: status}} -> {:error, {:http_status, status}}
      {:error, %Req.TransportError{reason: :timeout}} -> {:error, :timeout}
      {:error, _exception} -> {:error, :fetch_failed}
    end
  end

  @spec config(atom(), term()) :: term()
  defp config(name, default) do
    :retro_hex_chat |> Application.get_env(:index_now, []) |> Keyword.get(name, default)
  end
end
