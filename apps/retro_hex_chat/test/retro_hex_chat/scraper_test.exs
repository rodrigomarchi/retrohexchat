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

  defmodule ImageClient do
    @moduledoc false
    @behaviour Client

    @impl true
    def scrape(url, _opts) do
      {:ok,
       %{
         metadata: %{
           title: "With image",
           site_name: "Example",
           image: "https://cdn.example.com/story.jpg"
         },
         final_url: url,
         http_status: 200
       }}
    end
  end

  defmodule StaticImageFetcher do
    @moduledoc false
    @behaviour RetroHexChat.Scraper.ImageFetcher

    @impl true
    def fetch(url, _opts) do
      {:ok, %{body: "original", content_type: "image/jpeg", final_url: url, byte_size: 8}}
    end
  end

  defmodule StaticImageThumbnailer do
    @moduledoc false
    @behaviour RetroHexChat.Scraper.ImageThumbnailer

    @impl true
    def thumbnail("original", _opts) do
      {:ok,
       %{
         body: "thumb",
         content_type: "image/jpeg",
         extension: "jpg",
         width: 640,
         height: 360,
         byte_size: 5
       }}
    end
  end

  setup do
    start_supervised!(%{
      id: CountingClient,
      start: {Agent, :start_link, [fn -> [] end, [name: CountingClient]]}
    })

    previous = Application.get_env(:retro_hex_chat, :page_scraper)
    previous_image_cache = Application.get_env(:retro_hex_chat, :scraped_image_cache)
    previous_base_url = Application.get_env(:retro_hex_chat, :base_url)
    Cache.clear()

    on_exit(fn ->
      Cache.clear()

      case previous do
        nil -> Application.delete_env(:retro_hex_chat, :page_scraper)
        module -> Application.put_env(:retro_hex_chat, :page_scraper, module)
      end

      restore_env(:scraped_image_cache, previous_image_cache)
      restore_env(:base_url, previous_base_url)
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

    test "passes feed metadata hints to the scraper client" do
      Application.put_env(:retro_hex_chat, :page_scraper, CountingClient)

      assert {:ok, _page} =
               Scraper.fetch(@url,
                 metadata_hints: %{
                   image: "https://cdn.example.com/feed.jpg",
                   image_alt: "Feed image",
                   image_source: "media_content"
                 }
               )

      assert [{@url, opts}] = CountingClient.calls()
      assert opts[:metadata_hints].image == "https://cdn.example.com/feed.jpg"
      assert opts[:metadata_hints].image_alt == "Feed image"
      assert opts[:metadata_hints].image_source == "media_content"
    end

    test "reprocesses a fresh weak image when a feed supplies a stronger image" do
      now = DateTime.utc_now()

      {:ok, _page} =
        Store.record_success(
          @url,
          %{
            title: "Already stored",
            image_url: "https://example.com/body.jpg",
            raw_metadata: %{"sources" => %{"image" => "article_image"}}
          },
          now: now
        )

      Cache.clear()
      Application.put_env(:retro_hex_chat, :page_scraper, CountingClient)

      assert {:ok, page} =
               Scraper.fetch(@url,
                 now: now,
                 metadata_hints: %{
                   image: "https://cdn.example.com/feed.jpg",
                   image_alt: "Feed image",
                   image_source: "media_content"
                 }
               )

      assert page.title == "Counted"
      assert CountingClient.count() == 1
      assert [{@url, opts}] = CountingClient.calls()
      assert opts[:if_none_match] == nil
      assert opts[:metadata_hints].image == "https://cdn.example.com/feed.jpg"
    end

    test "reprocesses a fresh thin page when feed hints can enrich it" do
      now = DateTime.utc_now()

      {:ok, _page} =
        Store.record_success(
          @url,
          %{
            title: "Already stored",
            etag: ~s("v1"),
            last_modified: "Wed, 21 Oct 2026 07:28:00 GMT"
          },
          now: now
        )

      Cache.clear()
      Application.put_env(:retro_hex_chat, :page_scraper, CountingClient)

      assert {:ok, page} =
               Scraper.fetch(@url,
                 now: now,
                 metadata_hints: %{
                   description: "The feed has the missing summary.",
                   content_text: "The feed has enough article text to improve the stored page."
                 }
               )

      assert page.title == "Counted"
      assert CountingClient.count() == 1
      assert [{@url, opts}] = CountingClient.calls()
      assert opts[:if_none_match] == nil
      assert opts[:if_modified_since] == nil
      assert opts[:metadata_hints].description == "The feed has the missing summary."
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

    test "can return the page with a local thumbnail already generated" do
      Application.put_env(:retro_hex_chat, :page_scraper, ImageClient)
      Application.put_env(:retro_hex_chat, :base_url, "https://chat.example.test")

      Application.put_env(:retro_hex_chat, :scraped_image_cache,
        storage: RetroHexChat.Chat.Attachments.TestStorage,
        fetcher: StaticImageFetcher,
        thumbnailer: StaticImageThumbnailer,
        bucket: "retrohexchat-uploads"
      )

      assert {:ok, page} = Scraper.fetch(@url, thumbnail: :sync)

      assert page.image_thumbnail_status == "ready"
      assert page.image_thumbnail_storage_key =~ "scraper/images/"

      metadata = Client.to_metadata(page)

      assert metadata.image ==
               "https://chat.example.test/chat/scraped-pages/#{page.url_hash}/thumbnail"

      assert metadata.original_image == "https://cdn.example.com/story.jpg"
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

  describe "cards/1 and fingerprint/1" do
    test "a page of history costs one query and no requests" do
      Application.put_env(:retro_hex_chat, :page_scraper, ExplodingClient)

      {:ok, _} = Store.record_success(@url, %{title: "First", site_name: "Example"})
      {:ok, _} = Store.record_success("https://example.com/b", %{title: "Second"})

      hashes = Enum.map([@url, "https://example.com/b"], &Scraper.fingerprint/1)
      cards = Scraper.cards(hashes)

      assert map_size(cards) == 2
      assert cards[Scraper.fingerprint(@url)] =~ "**Example** | First"
    end

    test "a fingerprint survives the campaign parameters a link was posted with" do
      assert Scraper.fingerprint("#{@url}?utm_source=newsletter") == Scraper.fingerprint(@url)
      assert Scraper.fingerprint("not a url") == nil
    end

    test "says nothing about a page that is still on its way, or that said nothing" do
      {:ok, _} = Store.ensure_pending("https://example.com/pending")
      {:ok, _} = Store.record_success("https://example.com/blank", %{title: nil})

      hashes =
        Enum.map(
          [
            "https://example.com/pending",
            "https://example.com/blank",
            "https://example.com/never"
          ],
          &Scraper.fingerprint/1
        )

      assert Scraper.cards(hashes) == %{}
    end
  end

  defp prepared!(url) do
    assert {:ok, prepared} = Store.prepare_url(url)
    prepared
  end

  defp restore_env(key, nil), do: Application.delete_env(:retro_hex_chat, key)
  defp restore_env(key, value), do: Application.put_env(:retro_hex_chat, key, value)
end
