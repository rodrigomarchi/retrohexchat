defmodule RetroHexChatWeb.ChatLive.MessageGroupingTest do
  @moduledoc """
  Which lines share a header, which band each run of one speaker is printed on,
  and where a new day starts.

  The rule that costs the most to get wrong is the colour: a band is decided
  once, when the line first reaches the screen, and nothing loaded later —
  an older page above, a line arriving below — may repaint a line the reader is
  already looking at.
  """
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChatWeb.ChatLive.MessageGrouping

  @tz "America/Sao_Paulo"

  # 2026-10-21 12:00 in São Paulo is 15:00 UTC.
  defp at(hh, mm, day \\ 21), do: DateTime.new!(Date.new!(2026, 10, day), Time.new!(hh, mm, 0))

  defp say(id, author, ts, extra \\ %{}),
    do: Map.merge(%{id: id, author: author, timestamp: ts, type: :message}, extra)

  defp narrate(id, ts, type \\ :system),
    do: %{id: id, author: "System", timestamp: ts, type: type}

  defp shape(rows), do: Enum.map(rows, &{&1.id, &1.group_start?, &1.band})

  describe "annotate_all/2" do
    test "a run of one speaker shares one header and one band" do
      rows =
        MessageGrouping.annotate_all(
          [say(1, "ana", at(15, 0)), say(2, "ana", at(15, 1)), say(3, "bob", at(15, 2))],
          @tz
        )

      assert shape(rows) == [{1, true, :a}, {2, false, :a}, {3, true, :b}]
    end

    test "the nickname is compared the way nicknames are, not byte for byte" do
      rows =
        MessageGrouping.annotate_all([say(1, "Ana", at(15, 0)), say(2, "ana", at(15, 1))], @tz)

      assert shape(rows) == [{1, true, :a}, {2, false, :a}]
    end

    test "more than five minutes of silence starts a new header on the next band" do
      rows =
        MessageGrouping.annotate_all([say(1, "ana", at(15, 0)), say(2, "ana", at(15, 6))], @tz)

      assert shape(rows) == [{1, true, :a}, {2, true, :b}]
    end

    test "exactly five minutes still continues the run" do
      rows =
        MessageGrouping.annotate_all([say(1, "ana", at(15, 0)), say(2, "ana", at(15, 5))], @tz)

      assert shape(rows) == [{1, true, :a}, {2, false, :a}]
    end

    test "narration has no band, breaks the run, and the next speaker flips the band" do
      rows =
        MessageGrouping.annotate_all(
          [
            say(1, "ana", at(15, 0)),
            narrate(2, at(15, 0)),
            say(3, "ana", at(15, 1)),
            narrate(4, at(15, 2), :action),
            say(5, "bob", at(15, 2))
          ],
          @tz
        )

      assert shape(rows) == [
               {1, true, :a},
               {2, true, nil},
               {3, true, :b},
               {4, true, nil},
               {5, true, :a}
             ]
    end

    test "a line carrying a card stands alone on both sides" do
      card = %{share_card: %{slug: "x"}}

      rows =
        MessageGrouping.annotate_all(
          [say(1, "ana", at(15, 0)), say(2, "ana", at(15, 0), card), say(3, "ana", at(15, 0))],
          @tz
        )

      assert shape(rows) == [{1, true, :a}, {2, true, :b}, {3, true, :a}]
    end

    # A deleted line has no author on screen ("message deleted"), so a run it
    # opened would leave the lines under it without a name.
    test "a deleted line is narration: no band, and it breaks the run" do
      rows =
        MessageGrouping.annotate_all(
          [
            say(1, "ana", at(15, 0)),
            say(2, "ana", at(15, 1), %{deleted_at: at(15, 2)}),
            say(3, "ana", at(15, 1))
          ],
          @tz
        )

      assert shape(rows) == [{1, true, :a}, {2, true, nil}, {3, true, :b}]
    end

    test "the day is the reader's local day: 01:30 UTC is still the evening before in São Paulo" do
      rows =
        MessageGrouping.annotate_all(
          [say(1, "ana", at(23, 0)), say(2, "ana", at(1, 30, 22)), say(3, "ana", at(3, 30, 22))],
          @tz
        )

      assert Enum.map(rows, & &1.day_break) == [~D[2026-10-21], nil, ~D[2026-10-22]]
      # 20:00, 22:30, then 00:30 local: silence breaks the first run, midnight the second.
      assert shape(rows) == [{1, true, :a}, {2, true, :b}, {3, true, :a}]
    end

    test "the first line on screen always says which day it is" do
      [row] = MessageGrouping.annotate_all([narrate(1, at(15, 0))], @tz)

      assert row.day_break == ~D[2026-10-21]
    end

    test "a line with no usable time neither groups nor breaks a day" do
      rows =
        MessageGrouping.annotate_all(
          [say(1, "ana", at(15, 0)), say(2, "ana", nil), say(3, "bob", at(15, 1))],
          @tz
        )

      assert shape(rows) == [{1, true, :a}, {2, true, :b}, {3, true, :a}]
      assert Enum.map(rows, & &1.day_break) == [~D[2026-10-21], nil, nil]
    end
  end

  describe "annotate_after/3 (a line arriving below)" do
    test "continues the run on screen" do
      context = MessageGrouping.annotate_all([say(1, "ana", at(15, 0))], @tz)

      assert [%{group_start?: false, band: :a, day_break: nil}] =
               MessageGrouping.annotate_after(context, [say(2, "ana", at(15, 1))], @tz)
    end

    test "a new speaker takes the other band from the last speaker, past any narration" do
      context =
        MessageGrouping.annotate_all([say(1, "ana", at(15, 0)), narrate(2, at(15, 1))], @tz)

      assert [%{group_start?: true, band: :b}] =
               MessageGrouping.annotate_after(context, [say(3, "bob", at(15, 2))], @tz)
    end

    test "on an empty screen it is the first line" do
      assert [%{group_start?: true, band: :a, day_break: ~D[2026-10-21]}] =
               MessageGrouping.annotate_after([], [say(1, "ana", at(15, 0))], @tz)
    end
  end

  describe "annotate_before/3 (an older page above)" do
    test "never repaints a line already on screen" do
      screen =
        MessageGrouping.annotate_all(
          [say(10, "bob", at(15, 30)), say(11, "cid", at(15, 31))],
          @tz
        )

      for page <- [
            [say(1, "ana", at(15, 0))],
            [say(1, "ana", at(15, 0)), say(2, "dan", at(15, 1))],
            [say(1, "bob", at(15, 29))],
            [say(1, "bob", at(15, 28)), narrate(2, at(15, 29))]
          ] do
        {annotated, changed} = MessageGrouping.annotate_before(page, screen, @tz)
        below = changed || hd(screen)
        assert below.band == hd(screen).band
        whole = annotated ++ [below]

        # Every run alternates with its neighbour, whatever arrived above.
        speech = Enum.filter(whole, & &1.band)

        speech
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.each(fn [up, down] ->
          if down.group_start?,
            do: assert(up.band != down.band),
            else: assert(up.band == down.band)
        end)
      end
    end

    test "a page by the same speaker joins the run below and hands it back without its header" do
      [first | _] = MessageGrouping.annotate_all([say(10, "bob", at(15, 30))], @tz)

      {page, changed} = MessageGrouping.annotate_before([say(1, "bob", at(15, 29))], [first], @tz)

      assert shape(page) == [{1, true, :a}]
      assert %{id: 10, group_start?: false, band: :a, day_break: nil} = changed
    end

    test "nothing to hand back when the line below keeps its header and its day" do
      [first | _] = MessageGrouping.annotate_all([say(10, "bob", at(15, 30))], @tz)

      {page, changed} =
        MessageGrouping.annotate_before([say(1, "ana", at(15, 29, 20))], [first], @tz)

      assert shape(page) == [{1, true, :b}]
      assert changed == nil
    end

    test "the line below drops its day label when the page above is the same day" do
      [first | _] = MessageGrouping.annotate_all([say(10, "bob", at(15, 30))], @tz)

      {[top], changed} = MessageGrouping.annotate_before([narrate(1, at(15, 0))], [first], @tz)

      assert top.day_break == ~D[2026-10-21]
      assert %{group_start?: true, day_break: nil} = changed
    end

    # Narration has no band, so the run below it is the one the page must
    # alternate with.
    test "a narration line at the top of the screen does not hide the run below it" do
      screen =
        MessageGrouping.annotate_all(
          [narrate(10, at(15, 30)), say(11, "ana", at(15, 31)), say(12, "bob", at(15, 32))],
          @tz
        )

      {[carol], _changed} =
        MessageGrouping.annotate_before([say(1, "carol", at(15, 29))], screen, @tz)

      assert Enum.at(screen, 1).band == :a
      assert carol.band == :b
    end

    test "with nothing on screen it is the same as annotating everything" do
      rows = [say(1, "ana", at(15, 0)), say(2, "bob", at(15, 1))]

      assert MessageGrouping.annotate_before(rows, [], @tz) ==
               {MessageGrouping.annotate_all(rows, @tz), nil}
    end
  end

  describe "restart/2 and carry/2" do
    test "the new top line after the oldest is dropped gets a header and a day, and keeps its band" do
      [_, second] =
        MessageGrouping.annotate_all([say(1, "ana", at(15, 0)), say(2, "ana", at(15, 1))], @tz)

      assert %{group_start?: true, band: :a, day_break: ~D[2026-10-21]} =
               MessageGrouping.restart(second, @tz)
    end

    test "a line deleted in place, or gaining a card, is a regroup; an edit is not" do
      old = say(2, "ana", at(15, 1))

      assert MessageGrouping.regroup?(Map.put(old, :deleted_at, at(15, 2)), old)
      assert MessageGrouping.regroup?(Map.put(old, :share_card, %{slug: "x"}), old)
      refute MessageGrouping.regroup?(Map.put(old, :edited_at, at(15, 2)), old)
    end

    test "placing rows again keeps every band and redraws headers and days" do
      rows =
        MessageGrouping.annotate_all([say(1, "ana", at(23, 0)), say(2, "ana", at(23, 2))], @tz)

      painted = Enum.map(rows, &Map.put(&1, :band, :b))

      # In UTC the two lines are still one run on one day.
      assert [
               %{band: :b, group_start?: true, day_break: ~D[2026-10-21]},
               %{band: :b, group_start?: false}
             ] =
               MessageGrouping.place_again(painted, "Etc/UTC")
    end

    test "an edited line keeps the place in its run that it had" do
      [_, old] =
        MessageGrouping.annotate_all([say(1, "ana", at(15, 0)), say(2, "ana", at(15, 1))], @tz)

      edited = say(2, "ana", at(15, 1), %{edited_at: at(15, 3)})

      assert %{group_start?: false, band: :a, day_break: nil, edited_at: _} =
               MessageGrouping.carry(edited, old)
    end
  end
end
