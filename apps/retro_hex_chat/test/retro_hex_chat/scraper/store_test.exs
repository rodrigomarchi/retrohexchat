defmodule RetroHexChat.Scraper.StoreTest do
  @moduledoc """
  The rules that decide what a URL *is* and how long the answer lasts.

  Runs `async: false` because the upsert-race test needs a shared sandbox
  connection across spawned tasks — and that race is the whole reason the store
  writes with `on_conflict` instead of read-then-write.
  """
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.Scraper.{ScrapedPage, Store}

  @moduletag :integration

  @url "https://example.com/story"

  describe "normalize_url/1" do
    test "drops the fragment, the default port and a lowercase-able scheme and host" do
      assert {:ok, "https://example.com/story"} =
               Store.normalize_url("HTTPS://Example.COM:443/story#section")

      assert {:ok, "http://example.com/story"} =
               Store.normalize_url("http://example.com:80/story")
    end

    test "strips campaign parameters so one article is one row" do
      assert Store.hash_url("https://example.com/a?utm_source=rss&utm_medium=feed") ==
               Store.hash_url("https://example.com/a")

      assert Store.hash_url("https://example.com/a?fbclid=xyz") ==
               Store.hash_url("https://example.com/a")
    end

    test "keeps parameters that select content" do
      assert {:ok, "https://example.com/a?id=7"} =
               Store.normalize_url("https://example.com/a?id=7")

      assert {:ok, "https://example.com/a?id=7"} =
               Store.normalize_url("https://example.com/a?id=7&utm_source=x")
    end

    test "refuses anything that is not an http(s) address" do
      assert {:error, :invalid_url} = Store.normalize_url("ftp://example.com/a")
      assert {:error, :invalid_url} = Store.normalize_url("not a url")
      assert {:error, :invalid_url} = Store.normalize_url("https:///nohost")
    end
  end

  describe "upsert/3" do
    test "two concurrent writers leave exactly one row" do
      results =
        [1, 2]
        |> Enum.map(fn n ->
          Task.async(fn -> Store.record_success(@url, %{title: "writer #{n}"}) end)
        end)
        |> Task.await_many(5_000)

      assert Enum.all?(results, &match?({:ok, %ScrapedPage{}}, &1))
      assert Repo.aggregate(ScrapedPage, :count, :id) == 1
      assert Store.get_by_url(@url).title in ["writer 1", "writer 2"]
    end

    test "a later scrape replaces the fields an earlier one set" do
      {:ok, _} = Store.record_success(@url, %{title: "first", description: "old"})
      {:ok, page} = Store.record_success(@url, %{title: "second"})

      assert page.title == "second"
      assert page.description == nil
    end
  end

  describe "freshness" do
    test "a scrape stays fresh for 120 days" do
      now = DateTime.utc_now()
      {:ok, page} = Store.record_success(@url, %{title: "t"}, now: now)

      assert Store.fresh?(page, DateTime.add(now, 119 * 24 * 60 * 60, :second))
      refute Store.fresh?(page, DateTime.add(now, 121 * 24 * 60 * 60, :second))
    end

    test "a row written by an older extractor is stale inside its TTL" do
      now = DateTime.utc_now()
      {:ok, page} = Store.record_success(@url, %{title: "t"}, now: now)

      older = %{page | scraper_version: Store.scraper_version() - 1}

      assert Store.fresh?(page, now)
      refute Store.fresh?(older, now)
    end

    test "an expired but ready row is still worth showing while it refreshes" do
      {:ok, page} = Store.record_success(@url, %{title: "t"})

      assert Store.servable?(page)
      refute Store.servable?(%{page | status: "pending"})
    end
  end

  describe "record_not_modified/2" do
    test "extends the row without disturbing what was read" do
      now = DateTime.utc_now()
      {:ok, page} = Store.record_success(@url, %{title: "unchanged"}, now: now)

      later = DateTime.add(now, 121 * 24 * 60 * 60, :second)
      {:ok, renewed} = Store.record_not_modified(page, now: later)

      assert renewed.title == "unchanged"
      assert renewed.attempts == page.attempts
      assert DateTime.compare(renewed.fetched_at, page.fetched_at) == :eq
      assert Store.fresh?(renewed, later)
    end
  end

  describe "ensure_pending/2" do
    test "never blanks a page that is already answering" do
      {:ok, _} = Store.record_success(@url, %{title: "still here", image_url: "https://i/x.png"})
      {:ok, pending} = Store.ensure_pending(@url)

      assert pending.title == "still here"
      assert pending.image_url == "https://i/x.png"
      assert pending.status == "ready"
      assert pending.revalidating_since
    end

    test "creates a stub for a URL nobody has scraped" do
      {:ok, page} = Store.ensure_pending(@url)

      assert page.status == "pending"
      assert page.title == nil
    end
  end

  describe "record_failure/3" do
    test "a publisher's 404 is remembered for a week, a blip for minutes" do
      now = DateTime.utc_now()

      {:ok, gone} = Store.record_failure(@url, {:http_status, 404}, now: now)
      {:ok, blip} = Store.record_failure("https://example.com/b", :timeout, now: now)

      assert DateTime.diff(gone.expires_at, now, :second) == 7 * 24 * 60 * 60
      assert DateTime.diff(blip.expires_at, now, :second) == 15 * 60
      assert gone.error_reason == "http_404"
      assert gone.error_detail == %{"http_status" => 404}
    end
  end

  describe "provenance_stats/1" do
    test "reports which standard supplied each field" do
      {:ok, _} =
        Store.record_success("https://example.com/a", %{
          title: "A",
          raw_metadata: %{"sources" => %{"title" => "og", "description" => "og"}}
        })

      {:ok, _} =
        Store.record_success("https://example.com/b", %{
          title: "B",
          raw_metadata: %{"sources" => %{"title" => "og", "description" => "twitter"}}
        })

      {:ok, _} =
        Store.record_success("https://example.com/c", %{
          title: "C",
          raw_metadata: %{"sources" => %{"title" => "html"}}
        })

      by_field = Map.new(Store.provenance_stats(), &{&1.field, &1})

      assert by_field["title"].total == 3
      assert by_field["title"].top_source == "og"
      assert by_field["title"].breakdown == "og 2, html 1"
      assert by_field["description"].total == 2
    end

    test "says nothing about an archive nobody has filled" do
      assert Store.provenance_stats() == []
    end
  end

  describe "failure_stats/1" do
    test "separates a site that is down from one that will not answer a robot" do
      now = DateTime.utc_now()

      {:ok, _} = Store.record_failure("https://example.com/walled", :bot_challenge, now: now)
      {:ok, _} = Store.record_failure("https://example.com/walled2", :bot_challenge, now: now)
      {:ok, _} = Store.record_failure("https://example.com/down", :timeout, now: now)

      by_reason = Map.new(Store.failure_stats(), &{&1.reason, &1})

      assert by_reason["bot_challenge"].count == 2
      assert by_reason["timeout"].count == 1

      # The wall is re-checked weekly, the outage in minutes.
      assert DateTime.diff(by_reason["bot_challenge"].soonest_retry, now, :second) ==
               7 * 24 * 60 * 60

      assert DateTime.diff(by_reason["timeout"].soonest_retry, now, :second) == 15 * 60
    end
  end

  describe "prune/1" do
    test "deletes idle pages and spares expired ones that are still asked for" do
      now = DateTime.utc_now()
      long_ago = DateTime.add(now, -100 * 24 * 60 * 60, :second)

      {:ok, idle} = Store.record_success("https://example.com/idle", %{title: "idle"}, now: now)
      {:ok, hot} = Store.record_success("https://example.com/hot", %{title: "hot"}, now: long_ago)

      # The idle page has not been read in 100 days; the hot page expired but was
      # read a minute ago. Only the first is dead weight.
      Store.touch_access(idle, now: long_ago)
      Store.touch_access(hot, now: now)

      summary = Store.prune(now: now)

      assert summary.deleted == 1
      assert summary.candidates == 1
      assert Store.get_by_url("https://example.com/hot")
      refute Store.get_by_url("https://example.com/idle")
    end

    test "deletes failures once their grace period has passed" do
      now = DateTime.utc_now()
      long_ago = DateTime.add(now, -30 * 24 * 60 * 60, :second)

      {:ok, _} = Store.record_failure(@url, {:http_status, 404}, now: long_ago)

      assert Store.prune(now: now).deleted == 1
    end

    test "honours its batch limit" do
      now = DateTime.utc_now()
      long_ago = DateTime.add(now, -100 * 24 * 60 * 60, :second)

      for n <- 1..3 do
        {:ok, page} = Store.record_success("https://example.com/#{n}", %{title: "#{n}"}, now: now)
        Store.touch_access(page, now: long_ago)
      end

      summary = Store.prune(now: now, limit: 2)

      assert summary.candidates == 3
      assert summary.deleted == 2
    end
  end
end
