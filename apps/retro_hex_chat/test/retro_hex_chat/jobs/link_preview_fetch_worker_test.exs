defmodule RetroHexChat.Jobs.LinkPreviewFetchWorkerTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  alias RetroHexChat.Chat.LinkPreview
  alias RetroHexChat.Chat.LinkPreview.{Cache, Results}
  alias RetroHexChat.Jobs.LinkPreviewFetchWorker

  defmodule SuccessPreview do
    @behaviour LinkPreview

    @impl true
    def fetch_title(_url), do: {:ok, "Worker title"}

    @impl true
    def fetch_metadata(_url), do: {:error, :fetch_failed}

    @impl true
    def fetch_title_result(_url), do: {:ok, "Worker title"}
  end

  defmodule RetryableStatusPreview do
    @behaviour LinkPreview

    @impl true
    def fetch_title(_url), do: {:error, :server_error}

    @impl true
    def fetch_metadata(_url), do: {:error, :server_error}

    @impl true
    def fetch_title_result(_url), do: {:error, {:http_status, 503}}
  end

  defmodule NotFoundPreview do
    @behaviour LinkPreview

    @impl true
    def fetch_title(_url), do: {:error, :not_found}

    @impl true
    def fetch_metadata(_url), do: {:error, :not_found}

    @impl true
    def fetch_title_result(_url), do: {:error, {:http_status, 404}}
  end

  setup do
    previous = Application.get_env(:retro_hex_chat, :link_preview_fetcher)

    on_exit(fn ->
      case previous do
        nil -> Application.delete_env(:retro_hex_chat, :link_preview_fetcher)
        module -> Application.put_env(:retro_hex_chat, :link_preview_fetcher, module)
      end
    end)

    :ok
  end

  test "fetches, persists, caches and broadcasts a title" do
    url = "https://example.com/story"
    %{url_hash: url_hash} = prepared_url!(url)

    Application.put_env(:retro_hex_chat, :link_preview_fetcher, SuccessPreview)
    LinkPreview.subscribe()
    attach_telemetry()

    assert {:ok, :fetched} =
             LinkPreviewFetchWorker.perform(%Oban.Job{
               args: %{"url" => url, "url_hash" => url_hash},
               attempt: 1,
               max_attempts: 3
             })

    assert Results.get_fresh(url) == {:ok, "Worker title"}
    assert Cache.get(url) == {:ok, "Worker title"}

    assert_receive {:link_preview_result, %{url_hash: ^url_hash, result: {:ok, "Worker title"}}}

    assert_receive {:telemetry_event, [:retro_hex_chat, :link_preview, :fetch, :stop],
                    %{duration: duration}, metadata}

    assert is_integer(duration)
    assert metadata.context == "link_preview"
    assert metadata.operation == "fetch"
    assert metadata.result == "ok"
  end

  test "retries retryable HTTP statuses before the third attempt" do
    url = "https://example.com/unavailable"
    %{url_hash: url_hash} = prepared_url!(url)

    Application.put_env(:retro_hex_chat, :link_preview_fetcher, RetryableStatusPreview)
    LinkPreview.subscribe()

    assert {:error, {:http_status, 503}} =
             LinkPreviewFetchWorker.perform(%Oban.Job{
               args: %{"url" => url, "url_hash" => url_hash},
               attempt: 1,
               max_attempts: 3
             })

    result = Results.get_by_hash(url_hash)

    assert result.status == "pending"
    assert result.attempts == 1
    assert result.error_reason == "http_503"

    refute_receive {:link_preview_result, _}
  end

  test "records final failure on the third retryable HTTP attempt" do
    url = "https://example.com/still-unavailable"
    %{url_hash: url_hash} = prepared_url!(url)

    Application.put_env(:retro_hex_chat, :link_preview_fetcher, RetryableStatusPreview)
    LinkPreview.subscribe()

    assert {:ok, :failed} =
             LinkPreviewFetchWorker.perform(%Oban.Job{
               args: %{"url" => url, "url_hash" => url_hash},
               attempt: 3,
               max_attempts: 3
             })

    result = Results.get_by_hash(url_hash)

    assert result.status == "failed"
    assert result.attempts == 3
    assert result.error_reason == "http_503"
    assert Cache.get(url) == {:ok, :error}

    assert_receive {:link_preview_result, %{url_hash: ^url_hash, result: {:error, "http_503"}}}
  end

  test "does not retry deterministic HTTP statuses" do
    url = "https://example.com/missing"
    %{url_hash: url_hash} = prepared_url!(url)

    Application.put_env(:retro_hex_chat, :link_preview_fetcher, NotFoundPreview)

    assert {:ok, :failed} =
             LinkPreviewFetchWorker.perform(%Oban.Job{
               args: %{"url" => url, "url_hash" => url_hash},
               attempt: 1,
               max_attempts: 3
             })

    result = Results.get_by_hash(url_hash)

    assert result.status == "failed"
    assert result.attempts == 1
    assert result.error_reason == "http_404"
  end

  defp prepared_url!(url) do
    assert {:ok, prepared} = Results.prepare_url(url)
    prepared
  end

  defp attach_telemetry do
    test_pid = self()
    handler_id = {__MODULE__, make_ref()}

    :telemetry.attach_many(
      handler_id,
      [
        [:retro_hex_chat, :link_preview, :fetch, :stop],
        [:retro_hex_chat, :observability, :operation, :stop]
      ],
      fn event, measurements, metadata, _config ->
        send(test_pid, {:telemetry_event, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)
  end
end
