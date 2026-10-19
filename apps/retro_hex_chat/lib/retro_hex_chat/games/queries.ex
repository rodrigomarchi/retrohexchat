defmodule RetroHexChat.Games.Queries do
  @moduledoc """
  Database queries for Retro Games results.

  A match row has two sides and a ranking has one: whoever played. Every
  ranking therefore reads `participants/1` — each match once per registered
  player in it, with that player's own score and whether their side won — so
  a player's wins as host and as guest are one count, not two queries added
  together.
  """

  import Ecto.Query

  alias RetroHexChat.Games.Schema.GameResult
  alias RetroHexChat.Repo
  alias RetroHexChat.Services.RegisteredNick

  @type standing :: %{
          nickname: String.t(),
          wins: non_neg_integer(),
          best: non_neg_integer(),
          matches: pos_integer()
        }

  @typedoc """
  Which matches a ranking counts: one game or mode (`:game_id`) or a game and
  all its modes (`:base_id`), against one kind of opponent or any (`:origin`
  nil), within a window.
  """
  @type board_filter :: %{
          optional(:game_id) => String.t(),
          optional(:base_id) => String.t(),
          optional(:origin) => String.t() | nil,
          optional(:difficulty) => String.t() | nil,
          optional(:since) => DateTime.t() | nil,
          optional(:until) => DateTime.t() | nil
        }

  @spec insert(map()) :: {:ok, GameResult.t()} | {:error, Ecto.Changeset.t()}
  def insert(attrs) do
    %GameResult{}
    |> GameResult.changeset(attrs)
    |> Repo.insert()
  end

  @spec attach_message(GameResult.t(), map()) ::
          {:ok, GameResult.t()} | {:error, Ecto.Changeset.t()}
  def attach_message(result, attrs) do
    result
    |> GameResult.message_changeset(attrs)
    |> Repo.update()
  end

  @spec get(integer()) :: GameResult.t() | nil
  def get(id), do: Repo.get(GameResult, id)

  @doc "The results announced by these lines, found by the column that names them."
  @spec by_message_ids(atom(), [integer()]) :: [GameResult.t()]
  def by_message_ids(_column, []), do: []

  def by_message_ids(column, ids) do
    GameResult
    |> where([r], field(r, ^column) in ^ids)
    |> Repo.all()
  end

  @doc """
  Whether any player in a match about to be written scored more than they ever
  had in the same game, against the same kind of opponent.
  """
  @spec beats_personal_best?(map()) :: boolean()
  def beats_personal_best?(%{game_id: game_id, origin: origin} = attrs) do
    attrs
    |> sides()
    |> Enum.any?(fn {player_id, score} ->
      previous =
        GameResult
        |> where([r], r.game_id == ^game_id and r.origin == ^origin and r.ranked)
        |> same_difficulty(Map.get(attrs, :difficulty))
        |> participants()
        |> subquery()
        |> where([p], p.player_id == ^player_id)
        |> select([p], max(p.score))
        |> Repo.one()

      is_nil(previous) or score > previous
    end)
  end

  defp sides(attrs) do
    [{attrs[:p1_id], attrs[:p1_score]}, {attrs[:p2_id], attrs[:p2_score]}]
    |> Enum.filter(fn {player_id, _score} -> is_integer(player_id) end)
  end

  @doc """
  The standings of one game against one kind of opponent, best first.

  A versus game orders by wins; a score or co-op game by the best score a
  player ever took home. Only ranked matches count, and only players whose
  account still exists — their current nickname is the one shown.
  """
  @spec standings(board_filter(), :wins | :best, pos_integer()) :: [standing()]
  def standings(filter, order, limit) do
    ranked =
      GameResult
      |> where([r], r.ranked)
      |> of_game(filter)
      |> against(Map.get(filter, :origin))
      |> same_difficulty(Map.get(filter, :difficulty))
      |> finished_since(Map.get(filter, :since))
      |> finished_before(Map.get(filter, :until))

    ranked
    |> participants()
    |> subquery()
    |> join(:inner, [p], n in RegisteredNick, on: n.id == p.player_id)
    |> group_by([p, n], [p.player_id, n.nickname])
    |> select([p, n], %{
      nickname: n.nickname,
      wins: type(sum(fragment("CASE WHEN ? THEN 1 ELSE 0 END", p.won)), :integer),
      best: max(p.score),
      matches: count(p.result_id)
    })
    |> order_standings(order)
    |> limit(^limit)
    |> Repo.all()
  end

  defp order_standings(query, :wins) do
    order_by(query, [p, n],
      desc: sum(fragment("CASE WHEN ? THEN 1 ELSE 0 END", p.won)),
      asc: count(p.result_id),
      asc: n.nickname
    )
  end

  defp order_standings(query, :best) do
    order_by(query, [p, n], desc: max(p.score), asc: n.nickname)
  end

  @doc """
  Whether a channel line announced another match of `result`'s game, with
  either of its players in it, that finished at or after `since`.
  """
  @spec announced_since?(GameResult.t(), DateTime.t()) :: boolean()
  def announced_since?(%GameResult{} = result, since) do
    players = Enum.reject([result.p1_id, result.p2_id], &is_nil/1)

    GameResult
    |> where([r], r.base_id == ^result.base_id and r.id != ^result.id)
    |> where([r], not is_nil(r.channel_message_id) and r.finished_at >= ^since)
    |> where([r], r.p1_id in ^players or r.p2_id in ^players)
    |> Repo.exists?()
  end

  @type totals :: %{
          matches: non_neg_integer(),
          wins: non_neg_integer(),
          best: non_neg_integer() | nil
        }

  @doc """
  One player's ranked matches of a game and all its modes, by kind of
  opponent (`"p2p"`, `"ai"`): how many, how many won and their best score.
  A kind they never played against is absent.
  """
  @spec player_totals(String.t(), integer()) :: %{String.t() => totals()}
  def player_totals(base_id, player_id) do
    GameResult
    |> where([r], r.ranked and r.base_id == ^base_id)
    |> where([r], r.p1_id == ^player_id or r.p2_id == ^player_id)
    |> participants()
    |> subquery()
    |> join(:inner, [p], r in GameResult, on: r.id == p.result_id)
    |> where([p], p.player_id == ^player_id)
    |> group_by([p, r], r.origin)
    |> select(
      [p, r],
      {r.origin,
       %{
         matches: count(p.result_id),
         wins: type(sum(fragment("CASE WHEN ? THEN 1 ELSE 0 END", p.won)), :integer),
         best: max(p.score)
       }}
    )
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  One player's latest matches of a game and all its modes, newest first —
  private ones too: they are the player's own.
  """
  @spec recent_of(String.t(), integer(), pos_integer()) :: [GameResult.t()]
  def recent_of(base_id, player_id, limit) do
    GameResult
    |> where([r], r.base_id == ^base_id)
    |> where([r], r.p1_id == ^player_id or r.p2_id == ^player_id)
    |> order_by([r], desc: r.finished_at, desc: r.id)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc "The latest public matches of a game and all its modes, newest first."
  @spec recent(String.t(), pos_integer()) :: [GameResult.t()]
  def recent(base_id, limit) do
    GameResult
    |> where([r], r.base_id == ^base_id and r.public)
    |> order_by([r], desc: r.finished_at, desc: r.id)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc "How many matches of a game and its modes finished since `since`."
  @spec count_since(String.t(), DateTime.t()) :: non_neg_integer()
  def count_since(base_id, since) do
    GameResult
    |> where([r], r.base_id == ^base_id and r.finished_at >= ^since)
    |> Repo.aggregate(:count)
  end

  @doc """
  How many matches each game and its modes finished since `since` (and before
  `until`, when given), keyed by base game.
  """
  @spec counts_since(DateTime.t(), DateTime.t() | nil) :: %{String.t() => pos_integer()}
  def counts_since(since, until \\ nil) do
    GameResult
    |> where([r], r.finished_at >= ^since)
    |> finished_before(until)
    |> group_by([r], r.base_id)
    |> select([r], {r.base_id, count(r.id)})
    |> Repo.all()
    |> Map.new()
  end

  @doc "When the newest match of a game and its modes finished, or nil if none has."
  @spec last_finished_at(String.t()) :: DateTime.t() | nil
  def last_finished_at(base_id) do
    GameResult
    |> where([r], r.base_id == ^base_id)
    |> select([r], max(r.finished_at))
    |> Repo.one()
  end

  # Each match once per registered side, with that side's score and verdict.
  # Co-op wins belong to both sides; a computer opponent is no side at all.
  defp participants(query) do
    host =
      select(query, [r], %{
        result_id: r.id,
        player_id: r.p1_id,
        score: r.p1_score,
        won: r.outcome in ["p1", "coop_win"]
      })

    guest =
      query
      |> where([r], not is_nil(r.p2_id))
      |> select([r], %{
        result_id: r.id,
        player_id: r.p2_id,
        score: r.p2_score,
        won: r.outcome in ["p2", "coop_win"]
      })

    union_all(host, ^guest)
  end

  defp of_game(query, %{game_id: game_id}), do: where(query, [r], r.game_id == ^game_id)
  defp of_game(query, %{base_id: base_id}), do: where(query, [r], r.base_id == ^base_id)

  defp against(query, nil), do: query
  defp against(query, origin), do: where(query, [r], r.origin == ^origin)

  defp finished_before(query, nil), do: query
  defp finished_before(query, until), do: where(query, [r], r.finished_at < ^until)

  defp same_difficulty(query, nil), do: query
  defp same_difficulty(query, difficulty), do: where(query, [r], r.difficulty == ^difficulty)

  defp finished_since(query, nil), do: query
  defp finished_since(query, since), do: where(query, [r], r.finished_at >= ^since)
end
