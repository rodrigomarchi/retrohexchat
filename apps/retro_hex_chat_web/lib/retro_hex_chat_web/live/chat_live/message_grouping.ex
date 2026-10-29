defmodule RetroHexChatWeb.ChatLive.MessageGrouping do
  @moduledoc """
  Where a conversation's lines group, the band each group is printed on, and
  where a new day starts — the continuous-paper layout of the chat.

  Three fields are written onto each row:

    * `group_start?` — the line opens a run and draws the speaker's header. A
      line continues the run above it when both are speech by the same nickname,
      on the same local day, at most five minutes apart, and neither carries a
      card. Narration (actions, system lines, notices, help, a deleted line)
      always stands alone.
    * `band` — `:a` or `:b` for speech, `nil` for narration. Each run takes the
      band opposite to the nearest run above it, so neighbouring speakers never
      share a colour, and narration between them does not count.
    * `day_break` — the reader's local date when it differs from the line above,
      and always on the first line, so the top of the screen says which day it is.

  A band is decided once. A line arriving below continues from the rows above
  it (`annotate_after/3`); an older page arriving above is derived upwards from
  the first row already on screen (`annotate_before/3`), so loading history never
  repaints a line the reader is looking at. What can change on a row already on
  screen is only its header and its day label, and the functions that can cause
  that hand the row back to be re-rendered.
  """

  alias RetroHexChat.Nickname
  alias RetroHexChatWeb.Timezone

  @fields [:group_start?, :band, :day_break]
  @run_gap_seconds 5 * 60
  @speech_types [:message, :normal, :arcade_link]
  @card_keys [:share_card, :event_card, :result_card, :play_card]

  @type band :: :a | :b | nil
  @type row :: map()

  @doc "Annotates a whole conversation from the top, the first run on band `:a`."
  @spec annotate_all([row()], String.t()) :: [row()]
  def annotate_all(rows, tz), do: annotate_after([], rows, tz)

  @doc """
  Annotates `rows` as they arrive below `context`, the rows already on screen in
  order. Each continues from the one above it.
  """
  @spec annotate_after([row()], [row()], String.t()) :: [row()]
  def annotate_after(context, rows, tz) do
    start = {List.last(context), last_band(context)}

    {annotated, _acc} =
      Enum.map_reduce(rows, start, fn row, {prev, band_above} ->
        row = annotate_below(prev, row, band_above, tz)
        {row, {row, row.band || band_above}}
      end)

    annotated
  end

  @doc """
  Annotates an older `page` (oldest first) arriving above `below`, the first row
  already on screen. Bands are derived from `below` upwards, so it keeps its own.

  Returns the page and `below` re-annotated when its header or day label changed
  because of what now sits above it, or `nil` when it did not.
  """
  @spec annotate_before([row()], row() | nil, String.t()) :: {[row()], row() | nil}
  def annotate_before(page, nil, tz), do: {annotate_all(page, tz), nil}
  def annotate_before([], _below, _tz), do: {[], nil}

  def annotate_before(page, below, tz) do
    banded = bands_upward(page, below, tz)

    annotated = place_all(banded, nil, tz)
    moved = place(below, List.last(annotated), tz)

    {annotated, if(Map.take(moved, @fields) == Map.take(below, @fields), do: nil, else: moved)}
  end

  @doc """
  The row that became the first on screen after the one above it was dropped:
  it opens a run and says its day, and keeps its band.
  """
  @spec restart(row(), String.t()) :: row()
  def restart(row, tz), do: place(row, nil, tz)

  @doc """
  Whether a row drawn again stopped (or started) being speech — a line deleted
  in place — so the rows from it down have to be placed again.
  """
  @spec regroup?(row(), row()) :: boolean()
  def regroup?(row, old), do: speech?(row) != speech?(old)

  @doc "Gives a re-rendered row (an edit, a reaction) the place in its run the old one had."
  @spec carry(row(), row()) :: row()
  def carry(row, old), do: Map.merge(row, Map.take(old, @fields))

  # ── Placement ──────────────────────────────────────────────

  defp annotate_below(prev, row, band_above, tz) do
    band =
      cond do
        not speech?(row) -> nil
        continues?(prev, row, tz) -> prev.band
        true -> flip(band_above)
      end

    row |> Map.put(:band, band) |> place(prev, tz)
  end

  # Header and day label depend only on the row above; the band is already set.
  defp place(row, prev, tz) do
    date = local_date(row, tz)

    row
    |> Map.put(:group_start?, not continues?(prev, row, tz))
    |> Map.put(:day_break, if(is_nil(prev) or date != local_date(prev, tz), do: date))
  end

  defp place_all(rows, prev, tz) do
    {placed, _prev} =
      Enum.map_reduce(rows, prev, fn row, prev ->
        row = place(row, prev, tz)
        {row, row}
      end)

    placed
  end

  # Walks the page from the bottom up: a row that runs into the one below shares
  # its band, and any other speech takes the band opposite to the nearest run below.
  defp bands_upward(page, below, tz) do
    {banded, _acc} =
      page
      |> Enum.reverse()
      |> Enum.map_reduce({below, below.band}, fn row, {next, band_below} ->
        band =
          cond do
            not speech?(row) -> nil
            continues?(row, next, tz) -> next.band
            true -> flip(band_below)
          end

        row = Map.put(row, :band, band)
        {row, {row, band || band_below}}
      end)

    Enum.reverse(banded)
  end

  defp last_band(rows) do
    rows |> Enum.reverse() |> Enum.find_value(&Map.get(&1, :band))
  end

  defp flip(:a), do: :b
  defp flip(_band), do: :a

  # ── The rule ───────────────────────────────────────────────

  defp continues?(nil, _row, _tz), do: false

  defp continues?(above, row, tz) do
    with true <- speech?(above) and speech?(row),
         false <- card?(above) or card?(row),
         true <- Nickname.equal?(above.author, row.author),
         %DateTime{} = t1 <- Map.get(above, :timestamp),
         %DateTime{} = t2 <- Map.get(row, :timestamp),
         true <- abs(DateTime.diff(t2, t1)) <= @run_gap_seconds do
      local_date(above, tz) == local_date(row, tz)
    else
      _no -> false
    end
  end

  defp speech?(row),
    do: Map.get(row, :type, :message) in @speech_types and is_nil(Map.get(row, :deleted_at))

  defp card?(row), do: Enum.any?(@card_keys, &Map.get(row, &1))

  defp local_date(row, tz) do
    case Map.get(row, :timestamp) do
      %DateTime{} = ts -> ts |> Timezone.shift(tz) |> DateTime.to_date()
      _none -> nil
    end
  end
end
