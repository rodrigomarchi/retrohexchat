defmodule RetroHexChat.Games.Result do
  @moduledoc """
  How a Retro Games match ended, read out of whatever its engine reported.

  Every game reports the end of a match as a nested `score: %{p1, p2}` with a
  numeric `winner` — in the co-op games a shared score where `winner: 0` means
  the pair won and `-1` that it lost. Browsers holding an older chunk may
  still send the spellings the games used before: flat `score1`/`score2`, and
  hockey's `score_p1`/`score_p2` with `"p1"`/`"p2"`/`"draw"`. This module is
  the one place that reads them all, so every reader — the result panel, the
  ledger, a card in a channel — sees one shape.

  A one-player game names nobody: its points are the whole of its result.

  A match ended early (End pressed mid-match, `ended_early: true`) is read as
  it stood: a versus match goes to whoever leads, a level score is a draw, and
  a score or co-op game keeps its points and names nobody. The score decides,
  never a `winner` the browser sends with it.

  The payload comes from a browser and is never trusted: an unknown game, a
  missing or negative score, and a score past what the game can produce are
  all refused here, before anything is stored or shown as a record.
  """

  alias RetroHexChat.Games.Catalog

  @enforce_keys [:game_id, :p1_score, :p2_score, :outcome]
  defstruct [:game_id, :p1_score, :p2_score, :outcome, disconnected?: false, ended_early?: false]

  @typedoc """
  Who won, by side. `:none` is a match that names nobody — a disconnect, or a
  co-op mode whose engine cannot tell a win from a loss.
  """
  @type outcome :: :p1 | :p2 | :draw | :coop_win | :coop_loss | :none

  @type t :: %__MODULE__{
          game_id: String.t(),
          p1_score: non_neg_integer(),
          p2_score: non_neg_integer(),
          outcome: outcome(),
          disconnected?: boolean(),
          ended_early?: boolean()
        }

  @outcomes ~w(p1 p2 draw coop_win coop_loss none)a

  # Of the co-op games, only these report whether the pair won: Block Breakers
  # sends 0 for a cleared board and -1 for lost lives. Co-op Invaders sends 0
  # either way, so its matches rank on score alone.
  @coop_verdict_game_ids ~w(block_breakers)

  # Ceilings bound what a hostile client can claim, they do not describe a
  # good game: a versus match counts rounds, points or goals and never runs
  # into three digits; the score games count points.
  @ceilings %{versus: 99, score: 9_999_999, coop: 9_999_999}

  # A game whose best is known: the jungle holds 2000 points and 32 treasures;
  # a table of solitaire every move's points and the bonus of a 30-second win.
  @game_ceilings %{
    "hex_jungle" => 114_000,
    "hex_solitaire" => 24_078,
    "hex_solitaire_draw3" => 24_078
  }

  @doc "Every outcome, in the order a column of them is validated against."
  @spec outcomes() :: [outcome()]
  def outcomes, do: @outcomes

  @doc """
  Read an engine's end-of-match payload for `game_id`.
  """
  @spec normalize(String.t(), map()) ::
          {:ok, t()} | {:error, :unknown_game | :malformed | :implausible}
  def normalize(game_id, payload) when is_binary(game_id) and is_map(payload) do
    with true <- Catalog.valid_game_id?(game_id) || {:error, :unknown_game},
         {:ok, p1, p2} <- scores(payload),
         {p2, payload} = alone(game_id, p2, payload),
         :ok <- within_ceiling(game_id, p1, p2),
         outcome = read_outcome(game_id, payload, p1, p2),
         :ok <- agrees(Catalog.ranking(game_id), outcome, p1, p2) do
      {:ok,
       %__MODULE__{
         game_id: game_id,
         p1_score: p1,
         p2_score: p2,
         outcome: outcome,
         disconnected?: disconnected?(payload),
         ended_early?: ended_early?(payload)
       }}
    end
  end

  def normalize(_game_id, _payload), do: {:error, :malformed}

  @doc "Whether the match names somebody as its winner, or its pair as winners."
  @spec decided?(t()) :: boolean()
  def decided?(%__MODULE__{outcome: outcome}),
    do: outcome in [:p1, :p2, :draw, :coop_win, :coop_loss]

  defp scores(payload) do
    nested = field(payload, "score")

    case {score(nested, "p1", payload, ["score_p1", "score1"]),
          score(nested, "p2", payload, ["score_p2", "score2"])} do
      {{:ok, p1}, {:ok, p2}} -> {:ok, p1, p2}
      _missing -> {:error, :malformed}
    end
  end

  defp score(nested, side, payload, flat_keys) when is_map(nested) do
    case field(nested, side) do
      nil -> score(nil, side, payload, flat_keys)
      value -> count(value)
    end
  end

  defp score(_nested, _side, payload, flat_keys) do
    flat_keys
    |> Enum.find_value(&field(payload, &1))
    |> count()
  end

  defp count(value) when is_integer(value) and value >= 0, do: {:ok, value}
  defp count(value) when is_float(value) and value >= 0, do: {:ok, trunc(value)}
  defp count(_value), do: :error

  defp within_ceiling(game_id, p1, p2) do
    ceiling =
      Map.get_lazy(@game_ceilings, game_id, fn ->
        Map.fetch!(@ceilings, Catalog.ranking(game_id))
      end)

    if p1 <= ceiling and p2 <= ceiling, do: :ok, else: {:error, :implausible}
  end

  # A one-player game's result is its points: nobody else scored, and a run
  # played alone has nobody to lose by a disconnect.
  defp alone(game_id, p2, payload) do
    if Catalog.solo_only?(game_id),
      do: {0, Map.drop(payload, ["disconnected", :disconnected])},
      else: {p2, payload}
  end

  defp read_outcome(game_id, payload, p1, p2) do
    cond do
      Catalog.solo_only?(game_id) ->
        :none

      ended_early?(payload) and not disconnected?(payload) ->
        standing(Catalog.ranking(game_id), p1, p2)

      true ->
        outcome(verdict(game_id), field(payload, "winner"), disconnected?(payload))
    end
  end

  defp standing(:versus, p1, p2) when p1 > p2, do: :p1
  defp standing(:versus, p1, p2) when p2 > p1, do: :p2
  defp standing(:versus, _p1, _p2), do: :draw
  defp standing(_score_or_coop, _p1, _p2), do: :none

  # Which reading the `winner` field gets: a side, the pair, or none at all.
  defp verdict(game_id) do
    case Catalog.ranking(game_id) do
      :coop -> if game_id in @coop_verdict_game_ids, do: :coop, else: :silent
      _versus_or_score -> :sides
    end
  end

  defp outcome(_verdict, _winner, true), do: :none
  defp outcome(:silent, _winner, false), do: :none
  defp outcome(:coop, 0, false), do: :coop_win
  defp outcome(:coop, -1, false), do: :coop_loss
  defp outcome(:coop, _winner, false), do: :none
  defp outcome(:sides, winner, false) when winner in [1, "p1"], do: :p1
  defp outcome(:sides, winner, false) when winner in [2, "p2"], do: :p2
  defp outcome(:sides, winner, false) when winner in [0, "draw"], do: :draw
  defp outcome(:sides, _winner, false), do: :none

  # In a versus game the score counts what decided the match — rounds, goals,
  # lives — so a winner holding fewer of them, or a draw on an uneven score, is
  # a report no engine sends. A level score may still name a winner: Hex Frost
  # settles a tie on rounds by points the score does not carry.
  defp agrees(:versus, :p1, p1, p2) when p1 < p2, do: {:error, :implausible}
  defp agrees(:versus, :p2, p1, p2) when p2 < p1, do: {:error, :implausible}
  defp agrees(:versus, :draw, p1, p2) when p1 != p2, do: {:error, :implausible}
  defp agrees(_ranking, _outcome, _p1, _p2), do: :ok

  defp disconnected?(payload), do: field(payload, "disconnected") == true
  defp ended_early?(payload), do: field(payload, "ended_early") == true

  # A payload pushed from a hook arrives with string keys; one built in a test
  # or relayed through a process may carry atoms.
  @atom_keys Map.new(
               ~w(score p1 p2 score_p1 score_p2 score1 score2 winner disconnected ended_early),
               &{&1, String.to_atom(&1)}
             )

  defp field(map, key) when is_map(map) do
    case Map.fetch(map, key) do
      {:ok, value} -> value
      :error -> Map.get(map, Map.fetch!(@atom_keys, key))
    end
  end
end
