defmodule RetroHexChat.Scraper.CacheTest do
  @moduledoc """
  The cache has to forget on its own.

  Checking the age of an entry when somebody asks for it is enough to never
  serve a stale page, and not enough to keep the table small: a page nobody asks
  about again is never read, so its expiry is never noticed and it stays
  resident forever. With feeds scraped around the clock that is a table that
  only grows — which is how a machine with 3.8 GB of RAM ran out.
  """
  use ExUnit.Case, async: true

  alias RetroHexChat.Scraper.Cache
  alias RetroHexChat.Scraper.ScrapedPage

  @moduletag :unit

  setup do
    table = :"scraper_cache_test_#{System.unique_integer([:positive])}"
    start_supervised!({Cache, name: :"#{table}_server", table_name: table})
    %{table: table}
  end

  defp page(hash) do
    %ScrapedPage{url_hash: hash, url: "https://example.test/#{hash}", title: "t#{hash}"}
  end

  test "a page that was read recently is still there", ctx do
    Cache.put(page("fresh"), ctx.table)

    assert {:ok, %ScrapedPage{url_hash: "fresh"}} = Cache.get("fresh", ctx.table)
  end

  test "a page past its life is gone from the table, not merely ignored", ctx do
    Cache.put(page("old"), ctx.table)
    age_entry(ctx.table, {:page, "old"}, Cache.page_ttl_ms() + 1_000)

    assert Cache.sweep(ctx.table) == 1
    assert :ets.lookup(ctx.table, {:page, "old"}) == []
  end

  test "a sweep keeps what is still young", ctx do
    Cache.put(page("young"), ctx.table)
    Cache.put(page("old"), ctx.table)
    age_entry(ctx.table, {:page, "old"}, Cache.page_ttl_ms() + 1_000)

    assert Cache.sweep(ctx.table) == 1
    assert {:ok, _} = Cache.get("young", ctx.table)
    assert Cache.get("old", ctx.table) == :miss
  end

  test "an abandoned claim is swept too", ctx do
    assert Cache.claim("stuck", ctx.table) == :ok
    age_entry(ctx.table, {:inflight, "stuck"}, Cache.inflight_ttl_ms() + 1_000)

    assert Cache.sweep(ctx.table) == 1
    assert :ets.lookup(ctx.table, {:inflight, "stuck"}) == []
  end

  # Absence: a claim that is still within its budget must survive the sweep, or
  # two processes would fetch the same page at once.
  test "a live claim survives a sweep", ctx do
    assert Cache.claim("running", ctx.table) == :ok

    assert Cache.sweep(ctx.table) == 0
    assert Cache.claim("running", ctx.table) == :taken
  end

  test "the server sweeps itself without being asked", ctx do
    Cache.put(page("old"), ctx.table)
    age_entry(ctx.table, {:page, "old"}, Cache.page_ttl_ms() + 1_000)

    send(:"#{ctx.table}_server", :sweep)
    _synchronised = :sys.get_state(:"#{ctx.table}_server")

    assert :ets.lookup(ctx.table, {:page, "old"}) == []
  end

  # Moves an entry's timestamp back so it reads as `age_ms` old, which is the
  # only way to test an hour-long TTL without waiting an hour.
  defp age_entry(table, key, age_ms) do
    case :ets.lookup(table, key) do
      [{^key, value, stamp}] -> :ets.insert(table, {key, value, stamp - age_ms})
      [{^key, stamp}] -> :ets.insert(table, {key, stamp - age_ms})
    end
  end
end
