defmodule RetroHexChat.Jobs.PageScrapeWorkerTest do
  @moduledoc """
  The durable envelope around one scrape.

  Every broadcast assertion here is paired with an assertion about the stored row,
  so a test cannot pass on the message alone — the message is the notification,
  the row is the result.
  """
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.Jobs.PageScrapeWorker
  alias RetroHexChat.Scraper
  alias RetroHexChat.Scraper.{Cache, Client, Store}

  @moduletag :integration

  defmodule SuccessClient do
    @behaviour Client

    @impl true
    def scrape(_url, _opts) do
      {:ok,
       %{
         metadata: %{title: "Worker title", site_name: "Example"},
         final_url: "https://example.com/story",
         http_status: 200,
         content_type: "text/html",
         etag: ~s("v1"),
         last_modified: nil
       }}
    end
  end

  defmodule RetryableClient do
    @behaviour Client

    @impl true
    def scrape(_url, _opts), do: {:error, {:http_status, 503}}
  end

  defmodule NotFoundClient do
    @behaviour Client

    @impl true
    def scrape(_url, _opts), do: {:error, {:http_status, 404}}
  end

  setup do
    previous = Application.get_env(:retro_hex_chat, :page_scraper)
    Cache.clear()

    on_exit(fn ->
      Cache.clear()

      case previous do
        nil -> Application.delete_env(:retro_hex_chat, :page_scraper)
        module -> Application.put_env(:retro_hex_chat, :page_scraper, module)
      end
    end)

    :ok
  end

  test "stores the page, caches it and tells subscribers" do
    url = "https://example.com/story"
    %{url_hash: url_hash} = prepared_url!(url)

    Application.put_env(:retro_hex_chat, :page_scraper, SuccessClient)
    Scraper.subscribe()
    attach_telemetry()

    assert {:ok, :fetched} = perform(url, url_hash, 1)

    page = Store.get_by_hash(url_hash)

    assert page.status == "ready"
    assert page.title == "Worker title"
    assert page.site_name == "Example"
    assert page.etag == ~s("v1")
    assert page.http_status == 200
    assert {:ok, %{title: "Worker title"}} = Cache.get(url_hash)

    assert_receive {:scraped_page, %{url_hash: ^url_hash, status: "ready", title: "Worker title"}}

    assert_receive {:telemetry_event, [:retro_hex_chat, :scraper, :fetch, :stop],
                    %{duration: duration}, metadata}

    assert is_integer(duration)
    assert metadata.context == "scraper"
    assert metadata.operation == "fetch"
    assert metadata.result == "ok"
  end

  test "the whole URL Catcher path: a captured link becomes an answered one" do
    url = "https://example.com/captured"
    Application.put_env(:retro_hex_chat, :page_scraper, SuccessClient)
    Scraper.subscribe()

    # What the LiveView does when a link scrolls past: ask, get told it is on its
    # way, and let the durable job fill it in. Asserting the pieces separately hid
    # a defect that only this order exposes — `request/1` writes a pending row and
    # the worker then read that row as though it were the answer.
    assert Scraper.preview(url) == :pending

    %{url_hash: url_hash} = prepared_url!(url)
    assert Store.get_by_hash(url_hash).status == "pending"

    assert %{success: 1, failure: 0} =
             Oban.drain_queue(queue: :scrape, with_scheduled: true)

    page = Store.get_by_hash(url_hash)
    assert page.status == "ready"
    assert page.title == "Worker title"
    assert page.attempts == 1

    assert_receive {:scraped_page, %{url_hash: ^url_hash, status: "ready"}}

    # And from then on the view is answered without anyone touching the network.
    Cache.clear()
    assert {:ok, %{title: "Worker title"}} = Scraper.preview(url)
  end

  test "the stored title is the publisher's, not an escaped copy of it" do
    defmodule AmpersandClient do
      @behaviour Client

      @impl true
      def scrape(_url, _opts) do
        {:ok, %{metadata: %{title: ~s(Q&A "Bob's" <live>)}, final_url: "https://example.com/qa"}}
      end
    end

    url = "https://example.com/qa"
    %{url_hash: url_hash} = prepared_url!(url)

    Application.put_env(:retro_hex_chat, :page_scraper, AmpersandClient)

    assert {:ok, :fetched} = perform(url, url_hash, 1)
    assert Store.get_by_hash(url_hash).title == ~s(Q&A "Bob's" <live>)
  end

  test "hands a retryable status back to Oban without announcing a verdict" do
    url = "https://example.com/unavailable"
    %{url_hash: url_hash} = prepared_url!(url)

    Application.put_env(:retro_hex_chat, :page_scraper, RetryableClient)
    Scraper.subscribe()

    assert {:error, {:http_status, 503}} = perform(url, url_hash, 1)

    page = Store.get_by_hash(url_hash)

    assert page.status == "pending"
    assert page.attempts == 1
    assert page.error_reason == "http_503"

    refute_receive {:scraped_page, %{status: "failed"}}
  end

  test "settles on the last attempt" do
    url = "https://example.com/still-unavailable"
    %{url_hash: url_hash} = prepared_url!(url)

    Application.put_env(:retro_hex_chat, :page_scraper, RetryableClient)
    Scraper.subscribe()

    assert {:ok, :failed} = perform(url, url_hash, 3)

    page = Store.get_by_hash(url_hash)

    assert page.status == "pending"
    assert page.attempts == 3
    assert page.error_reason == "http_503"

    assert_receive {:scraped_page, %{url_hash: ^url_hash, title: nil}}
  end

  test "does not retry a status the publisher meant" do
    url = "https://example.com/missing"
    %{url_hash: url_hash} = prepared_url!(url)

    Application.put_env(:retro_hex_chat, :page_scraper, NotFoundClient)

    assert {:ok, :failed} = perform(url, url_hash, 1)

    page = Store.get_by_hash(url_hash)

    assert page.status == "failed"
    assert page.attempts == 1
    assert page.error_reason == "http_404"
  end

  defp perform(url, url_hash, attempt) do
    PageScrapeWorker.perform(%Oban.Job{
      args: %{"url" => url, "url_hash" => url_hash},
      attempt: attempt,
      max_attempts: 3
    })
  end

  defp prepared_url!(url) do
    assert {:ok, prepared} = Store.prepare_url(url)
    prepared
  end

  defp attach_telemetry do
    test_pid = self()
    handler_id = {__MODULE__, make_ref()}

    :telemetry.attach_many(
      handler_id,
      [
        [:retro_hex_chat, :scraper, :fetch, :stop],
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
