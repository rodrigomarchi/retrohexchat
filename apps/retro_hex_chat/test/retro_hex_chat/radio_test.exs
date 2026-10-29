defmodule RetroHexChat.RadioTest do
  use ExUnit.Case, async: false

  alias RetroHexChat.Radio
  alias RetroHexChat.Radio.Cache

  @moduletag :unit

  setup do
    Cache.clear()
    on_exit(&Cache.clear/0)
    :ok
  end

  test "lists the most played, a genre and a search" do
    assert {:ok, top} = Radio.list(:top)
    assert length(top) > 3

    assert {:ok, [%{name: "Pixel Wave FM"}]} = Radio.list({:tag, "chiptune"})
    assert {:ok, [%{name: "Neon Highway"}]} = Radio.list({:name, "  neon "})
  end

  test "favourites come back in the order they were starred" do
    assert {:ok, stations} = Radio.list({:ids, ["e2e-star", "gone", "e2e-pixel"]})
    assert Enum.map(stations, & &1.id) == ["e2e-star", "e2e-pixel"]
    assert {:ok, []} = Radio.list({:ids, []})
  end

  test "refuses a question it would not ask the catalog" do
    assert {:error, :invalid} = Radio.list({:tag, "not-a-genre"})
    assert {:error, :invalid} = Radio.list({:name, "a"})
    assert {:error, :invalid} = Radio.list({:name, String.duplicate("a", 61)})
    assert {:error, :invalid} = Radio.list({:ids, Enum.map(1..51, &"id#{&1}")})
    assert {:error, :invalid} = Radio.list({:ids, [42]})
    assert {:error, :invalid} = Radio.list(:anything)
  end

  test "every genre the window lists is a question the catalog accepts" do
    for genre <- Radio.genres(), do: assert({:ok, _} = Radio.list({:tag, genre}))
  end

  test "keeps a list it was given" do
    assert {:ok, stations} = Radio.list({:tag, "jazz"})
    assert {:ok, ^stations} = Cache.get({:tag, "jazz"})
  end

  test "a play is counted without failing the caller" do
    assert :ok = Radio.played("e2e-pixel")
    assert :ok = Radio.played(nil)
  end
end
