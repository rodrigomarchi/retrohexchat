defmodule RetroHexChat.Games.Ratings do
  @moduledoc """
  Elo ratings for the versus games, between people.

  A win counts for more against somebody better than you, which is what makes
  a rating the answer to "who is good at this" where a count of wins only says
  who played most. Only ranked matches between two registered people move it:
  the computer has no rating, and a match somebody left decided nothing.

  Every mode of a game shares the game's rating — Hex Tennis: Quick Match is
  still tennis. A player who has never played starts at 1200.
  """

  import Ecto.Query

  alias RetroHexChat.Games.Catalog
  alias RetroHexChat.Games.Schema.GameRating
  alias RetroHexChat.Games.Schema.GameResult
  alias RetroHexChat.Repo
  alias RetroHexChat.Services.RegisteredNick

  @start 1200
  # How far one match can move a rating. 32 is the classic value for players
  # without long histories, which is every player of a chat's games.
  @k 32

  @type standing :: %{nickname: String.t(), rating: integer(), matches: pos_integer()}

  @doc """
  Move both players' ratings by the outcome of `result`, when it is a ranked
  match between two people in a versus game; anything else changes nothing.
  """
  @spec apply_result(GameResult.t()) :: :ok
  def apply_result(
        %GameResult{origin: "p2p", ranked: true, p1_id: p1, p2_id: p2, outcome: outcome} =
          result
      )
      when is_integer(p1) and is_integer(p2) and outcome in ~w(p1 p2 draw) do
    if Catalog.ranking(result.game_id) == :versus do
      {:ok, :ok} = Repo.transaction(fn -> rate(result.base_id, p1, p2, score(outcome)) end)
    end

    :ok
  end

  def apply_result(_unrated), do: :ok

  defp rate(base_id, p1_id, p2_id, p1_score) do
    ratings = locked(base_id, [p1_id, p2_id])
    host = Map.fetch!(ratings, p1_id)
    guest = Map.fetch!(ratings, p2_id)
    expected = 1 / (1 + :math.pow(10, (guest.rating - host.rating) / 400))
    change = round(@k * (p1_score - expected))

    save(host, host.rating + change, p1_score)
    save(guest, guest.rating - change, 1 - p1_score)
    :ok
  end

  defp score("p1"), do: 1.0
  defp score("p2"), do: 0.0
  defp score("draw"), do: 0.5

  # Both rows exist before either is locked, so two first matches of the same
  # player finishing together meet on a row instead of racing to insert it;
  # and both are written and locked lowest id first, so matches between
  # overlapping pairs wait for each other instead of deadlocking.
  defp locked(base_id, player_ids) do
    now = DateTime.utc_now()

    Repo.insert_all(
      GameRating,
      player_ids
      |> Enum.sort()
      |> Enum.map(fn player_id ->
        %{
          base_id: base_id,
          player_id: player_id,
          rating: @start,
          inserted_at: now,
          updated_at: now
        }
      end),
      on_conflict: :nothing,
      conflict_target: [:base_id, :player_id]
    )

    GameRating
    |> where([r], r.base_id == ^base_id and r.player_id in ^player_ids)
    |> order_by([r], asc: r.player_id)
    |> lock("FOR UPDATE")
    |> Repo.all()
    |> Map.new(&{&1.player_id, &1})
  end

  defp save(rating, new_rating, points) do
    rating
    |> GameRating.changeset(%{
      rating: new_rating,
      matches: rating.matches + 1,
      wins: rating.wins + if(points == 1.0, do: 1, else: 0),
      losses: rating.losses + if(points == 0.0, do: 1, else: 0),
      draws: rating.draws + if(points == 0.5, do: 1, else: 0)
    })
    |> Repo.update!()
  end

  @type rating :: %{
          rating: integer(),
          rank: pos_integer(),
          players: pos_integer(),
          matches: non_neg_integer(),
          wins: non_neg_integer(),
          losses: non_neg_integer(),
          draws: non_neg_integer()
        }

  @doc """
  One player's rating in a game: the rating, their place among everybody
  rated in it (players with the same rating share a place) and their wins,
  losses and draws. Nil until their first rated match.
  """
  @spec of(String.t(), integer()) :: rating() | nil
  def of(base_id, player_id) do
    case Repo.get_by(GameRating, base_id: base_id, player_id: player_id) do
      nil ->
        nil

      rating ->
        rated = where(GameRating, [r], r.base_id == ^base_id)

        rating
        |> Map.take([:rating, :matches, :wins, :losses, :draws])
        |> Map.merge(%{
          rank: Repo.aggregate(where(rated, [r], r.rating > ^rating.rating), :count) + 1,
          players: Repo.aggregate(rated, :count)
        })
    end
  end

  @doc "The best-rated players of a game, with their current nickname."
  @spec top(String.t(), pos_integer()) :: [standing()]
  def top(base_id, limit \\ 5) do
    GameRating
    |> where([r], r.base_id == ^base_id)
    |> join(:inner, [r], n in RegisteredNick, on: n.id == r.player_id)
    |> order_by([r, n], desc: r.rating, asc: n.nickname)
    |> limit(^limit)
    |> select([r, n], %{nickname: n.nickname, rating: r.rating, matches: r.matches})
    |> Repo.all()
  end
end
