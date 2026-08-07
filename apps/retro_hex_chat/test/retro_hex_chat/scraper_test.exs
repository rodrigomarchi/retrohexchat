defmodule RetroHexChat.ScraperTest do
  @moduledoc """
  The promise the whole refactor rests on: a page is read once, and every
  consumer after that is served from the archive.

  The counting client is how that is proved. A cache hit leaves no trace in the
  data — the row looks identical whether it was just fetched or fetched in March —
  so the only honest assertion is on how many times the network was asked.
  """
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.Scraper
  alias RetroHexChat.Scraper.{Cache, Client, Store}

  @moduletag :integration

  @url "https://example.com/story"

  defmodule CountingClient do
    @moduledoc false
    @behaviour Client

    @impl true
    def scrape(url, opts) do
      Agent.update(__MODULE__, &[{url, opts} | &1])

      {:ok,
       %{
         metadata: %{title: "Counted", site_name: "Example"},
         final_url: url,
         http_status: 200,
         etag: ~s("v1"),
         last_modified: "Wed, 21 Oct 2026 07:28:00 GMT"
       }}
    end

    def calls, do: Agent.get(__MODULE__, & &1)
    def count, do: length(calls())
  end

  defmodule NotModifiedClient do
    @moduledoc false
    @behaviour Client

    @impl true
    def scrape(_url, opts) do
      Agent.update(CountingClient, &[{:conditional, opts} | &1])
      {:not_modified}
    end
  end

  defmodule ExplodingClient do
    @moduledoc false
    @behaviour Client

    @impl true
    def scrape(_url, _opts), do: raise("the network must not be reached here")
  end

  setup do
    start_supervised!(%{
      id: CountingClient,
      start: {Agent, :start_link, [fn -> [] end, [name: CountingClient]]}
    })

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

  describe "fetch/2" do
    test "asks the publisher once, however many consumers ask afterwards" do
      Application.put_env(:retro_hex_chat, :page_scraper, CountingClient)

      assert {:ok, first} = Scraper.fetch(@url)
      assert {:ok, second} = Scraper.fetch(@url)
      assert {:ok, third} = Scraper.fetch("https://example.com/story?utm_source=feed")

      assert first.id == second.id
      assert second.id == third.id
      assert CountingClient.count() == 1
    end

    test "serves a page read 119 days ago without touching the network" do
      now = DateTime.utc_now()
      {:ok, _} = Store.record_success(@url, %{title: "Archived"}, now: now)
      Cache.clear()

      Application.put_env(:retro_hex_chat, :page_scraper, ExplodingClient)

      assert {:ok, page} = Scraper.fetch(@url, now: DateTime.add(now, 119 * 86_400, :second))
      assert page.title == "Archived"
    end

    test "revalidates an expired page with a conditional request" do
      now = DateTime.utc_now()
      Application.put_env(:retro_hex_chat, :page_scraper, CountingClient)

      assert {:ok, _} = Scraper.fetch(@url, now: now)
      Cache.clear()

      Application.put_env(:retro_hex_chat, :page_scraper, NotModifiedClient)
      later = DateTime.add(now, 121 * 86_400, :second)

      assert {:ok, renewed} = Scraper.fetch(@url, now: later)

      assert renewed.title == "Counted"
      assert Store.fresh?(renewed, later)

      assert {:conditional, opts} = hd(CountingClient.calls())
      assert opts[:if_none_match] == ~s("v1")
      assert opts[:if_modified_since] == "Wed, 21 Oct 2026 07:28:00 GMT"
    end

    test "a second caller does not open its own connection while one is in flight" do
      Application.put_env(:retro_hex_chat, :page_scraper, CountingClient)
      %{url_hash: url_hash} = prepared!(@url)

      :ok = Cache.claim(url_hash)

      assert {:error, :in_flight} = Scraper.fetch(@url)
      assert CountingClient.count() == 0

      Cache.release(url_hash)

      assert {:ok, _page} = Scraper.fetch(@url)
      assert CountingClient.count() == 1
    end
  end

  describe "the pending row request/1 leaves behind" do
    test "does not stop the worker that was enqueued to fill it" do
      Application.put_env(:retro_hex_chat, :page_scraper, CountingClient)

      # Exactly what `request/1` writes before enqueueing the job. It is fresh for
      # the ten minutes the job has to run, and treating that freshness as an
      # answer meant the worker read its own note, concluded the page was handled
      # and returned without ever fetching it — leaving the row pending for ever
      # while the job reported success.
      {:ok, pending} = Store.ensure_pending(@url)
      assert pending.status == "pending"

      assert {:ok, page} = Scraper.fetch(@url)

      assert page.status == "ready"
      assert page.title == "Counted"
      assert CountingClient.count() == 1
    end

    test "is reported as on its way, not as nothing to know" do
      {:ok, _} = Store.ensure_pending(@url)
      Cache.clear()

      assert Scraper.preview(@url) == :pending
    end

    test "is told apart from a transient failure that is backing off" do
      Application.put_env(:retro_hex_chat, :page_scraper, CountingClient)

      # A row that has been attempted and failed is also `pending`, because the
      # failure is transient — but reading it must not start a new fetch, or a
      # site that is briefly down is hammered once per lookup instead of retried
      # once per back-off.
      {:ok, _} = Store.record_retryable_failure(@url, :timeout, attempt: 1)
      Cache.clear()

      assert {:error, "timeout"} = Scraper.fetch(@url)
      assert CountingClient.count() == 0
    end
  end

  describe "get/1" do
    test "never reaches the network, even for a URL nobody has scraped" do
      Application.put_env(:retro_hex_chat, :page_scraper, ExplodingClient)

      assert Scraper.get("https://example.com/never-seen") == :miss
    end

    test "ignores an address that is not a page" do
      assert Scraper.get("not a url") == :miss
    end
  end

  describe "preview/1" do
    test "answers from the archive and arranges a refresh when it has aged out" do
      now = DateTime.utc_now()
      {:ok, _} = Store.record_success(@url, %{title: "Old but right"}, now: now)

      Store.get_by_url(@url)
      |> Ecto.Changeset.change(expires_at: DateTime.add(now, -1, :second))
      |> Repo.update!()

      Cache.clear()

      assert {:ok, page} = Scraper.preview(@url)
      assert page.title == "Old but right"
      assert Store.get_by_url(@url).revalidating_since
    end

    test "does not ask again for a failure that is still recent" do
      {:ok, _} = Store.record_failure(@url, {:http_status, 404})
      Cache.clear()

      assert Scraper.preview(@url) == :unknown
    end

    test "reports a URL it has never seen as on its way" do
      assert Scraper.preview("https://example.com/fresh") == :pending
      assert Store.get_by_url("https://example.com/fresh").status == "pending"
    end
  end

  defp prepared!(url) do
    assert {:ok, prepared} = Store.prepare_url(url)
    prepared
  end
end
