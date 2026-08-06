defmodule RetroHexChat.Chat.LinkPreview do
  @moduledoc """
  Behaviour for fetching lightweight page preview metadata from URLs.
  """

  alias RetroHexChat.Chat.LinkPreview.{Cache, Results}
  alias RetroHexChat.Jobs
  alias RetroHexChat.Jobs.LinkPreviewFetchWorker

  @type metadata :: %{
          optional(:title) => String.t() | nil,
          optional(:description) => String.t() | nil,
          optional(:image) => String.t() | nil,
          optional(:url) => String.t() | nil,
          optional(:site_name) => String.t() | nil
        }

  @type fetch_error :: atom() | {:http_status, pos_integer()} | term()

  @callback fetch_title(String.t()) :: {:ok, String.t()} | {:error, atom()}
  @callback fetch_metadata(String.t()) :: {:ok, metadata()} | {:error, atom()}
  @callback fetch_title_result(String.t()) :: {:ok, String.t()} | {:error, fetch_error()}

  @optional_callbacks fetch_title_result: 1

  @topic "link_previews"

  @doc "The link preview implementation in force. Configure `:link_preview_fetcher` to substitute one."
  @spec impl() :: module()
  def impl do
    Application.get_env(
      :retro_hex_chat,
      :link_preview_fetcher,
      RetroHexChat.Chat.LinkPreview.HTTP
    )
  end

  @doc "PubSub topic for durable link preview result updates."
  @spec topic() :: String.t()
  def topic, do: @topic

  @doc "Subscribe the current process to durable link preview results."
  @spec subscribe() :: :ok | {:error, term()}
  def subscribe do
    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, @topic)
  end

  @doc "Broadcast a durable link preview result."
  @spec broadcast_result(String.t(), {:ok, String.t()} | {:error, fetch_error()}) ::
          :ok | {:error, term()}
  def broadcast_result(url, result) do
    with {:ok, prepared} <- Results.prepare_url(url) do
      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        @topic,
        {:link_preview_result,
         %{url: prepared.url, url_hash: prepared.url_hash, result: normalize_result(result)}}
      )
    end
  end

  @doc "Enqueue a durable fetch for a URL Catcher preview."
  @spec enqueue_fetch(String.t()) :: :ok | {:error, term()}
  def enqueue_fetch(url) do
    with {:ok, pending} <- Results.ensure_pending(url),
         {:ok, _job} <-
           Jobs.insert(
             LinkPreviewFetchWorker.new(%{
               url: pending.url,
               url_hash: pending.url_hash
             })
           ) do
      Cache.mark_pending(pending.url)
      :ok
    end
  end

  @doc "Fetch a title using the configured implementation, preserving rich error causes when available."
  @spec fetch_title_result(String.t()) :: {:ok, String.t()} | {:error, fetch_error()}
  def fetch_title_result(url) do
    fetcher = impl()

    if function_exported?(fetcher, :fetch_title_result, 1) do
      fetcher.fetch_title_result(url)
    else
      fetcher.fetch_title(url)
    end
  end

  defp normalize_result({:ok, title}) when is_binary(title), do: {:ok, title}
  defp normalize_result({:error, reason}), do: {:error, Results.error_reason(reason)}
end
