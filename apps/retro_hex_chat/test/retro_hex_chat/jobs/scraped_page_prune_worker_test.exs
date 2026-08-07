defmodule RetroHexChat.Jobs.ScrapedPagePruneWorkerTest do
  @moduledoc """
  Keeping a sixty-day archive from becoming an unbounded one.
  """
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.Jobs.ScrapedPagePruneWorker
  alias RetroHexChat.Scraper.{ScrapedPage, Store}

  @moduletag :integration

  test "removes idle pages and reports what it did" do
    now = DateTime.utc_now()
    long_ago = DateTime.add(now, -120 * 86_400, :second)

    {:ok, idle} = Store.record_success("https://example.com/idle", %{title: "Idle"}, now: now)
    Store.touch_access(idle, now: long_ago)

    {:ok, hot} = Store.record_success("https://example.com/hot", %{title: "Hot"}, now: now)
    Store.touch_access(hot, now: now)

    assert {:ok, summary} = perform_job(ScrapedPagePruneWorker, %{})

    assert summary.deleted == 1
    assert summary.candidates == 1
    assert summary.oldest_expired_age_ms > 0

    assert Repo.aggregate(ScrapedPage, :count, :id) == 1
    assert Store.get_by_url("https://example.com/hot")
  end

  test "leaves a healthy archive alone" do
    {:ok, _} = Store.record_success("https://example.com/recent", %{title: "Recent"})

    assert {:ok, %{deleted: 0, candidates: 0, oldest_expired_age_ms: 0}} =
             perform_job(ScrapedPagePruneWorker, %{})
  end
end
