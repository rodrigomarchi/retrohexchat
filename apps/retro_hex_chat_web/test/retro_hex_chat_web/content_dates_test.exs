defmodule RetroHexChatWeb.ContentDatesTest do
  @moduledoc """
  The sitemap's `lastmod`: the day a page's own sources last changed, or
  nothing at all — never a guess.
  """
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChatWeb.ContentDates

  @iso_day ~r/^\d{4}-\d{2}-\d{2}$/

  describe "game_page/1" do
    # A game's page is drawn from its template and from the domain catalogues,
    # which have long been committed: with history to read, there is a date.
    test "has a date whenever the history is there to give one" do
      date = ContentDates.game_page("doom-shareware")

      if ContentDates.known?() do
        assert date =~ @iso_day
      else
        assert date == nil
      end
    end
  end

  describe "a guide" do
    # The mIRC commands page is drawn from the parity rows in the domain as much
    # as from its template, so a new row is a new date for the page.
    test "is dated by the newest of its template, the shared guide pieces and its rows" do
      sources = [
        "apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/landing_live/mirc_commands.html.heex",
        "apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/landing_live/mirc_commands.ex",
        "apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/landing_live/guides.ex",
        "apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/landing/irc_guides.ex",
        "apps/retro_hex_chat/lib/retro_hex_chat/commands/mirc_parity.ex"
      ]

      if ContentDates.known?() do
        assert ContentDates.landing("/mirc-commands") == newest(sources)
      end
    end
  end

  describe "the newest of a page's sources" do
    # A game's page changes when its catalogue does, even when its template
    # has not moved: the date is the newest of all its sources, which git
    # answers directly.
    test "is the day the most recently changed source changed" do
      sources = [
        "apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/landing_live/game.html.heex",
        "apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/landing_live/game.ex",
        "apps/retro_hex_chat_web/priv/static/images/games/hex-tennis.webp",
        "apps/retro_hex_chat/lib/retro_hex_chat/arcade/catalog.ex",
        "apps/retro_hex_chat/lib/retro_hex_chat/games/catalog.ex",
        "apps/retro_hex_chat_web/lib/retro_hex_chat_web/game_catalog.ex",
        "apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/landing/game_cards.ex"
      ]

      if ContentDates.known?() do
        assert ContentDates.game_page("hex-tennis") == newest(sources)
      end
    end
  end

  describe "landing/1" do
    test "a path that is not a landing page has no date" do
      assert ContentDates.landing("not-a-path") == nil
    end
  end

  # The day the most recently changed of `sources` was committed, asked of git
  # directly rather than of the module under test.
  defp newest(sources) do
    sources
    |> Enum.map(fn path ->
      {out, 0} =
        System.cmd("git", ["log", "-1", "--format=%cI", "--", ":(top)" <> path],
          cd: Path.expand("../../..", __DIR__)
        )

      out |> String.trim() |> String.slice(0, 10)
    end)
    |> Enum.reject(&(&1 == ""))
    |> Enum.max(fn -> nil end)
  end
end
