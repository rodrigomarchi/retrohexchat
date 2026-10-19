defmodule RetroHexChat.Games.Results do
  @moduledoc """
  The ledger of finished Retro Games matches, and what is read back from it.

  A match against the computer and a match between two people are the same
  record with a different second side, so both are written by `record/1`: the
  engine's payload is read by `Games.Result`, the clock is the server's, the
  match is announced by `Games.Announcer` in the process that wrote it, and
  the row is then published on `Topics.game_results/0` for whatever counts
  matches live.

  Only a registered player is written down. A ranking is a list of names a
  reader can look up, and a guest's name belongs to whoever takes it next.
  """

  alias RetroHexChat.Games.Announcer
  alias RetroHexChat.Games.Catalog
  alias RetroHexChat.Games.Queries
  alias RetroHexChat.Games.Ratings
  alias RetroHexChat.Games.Result
  alias RetroHexChat.Games.Schema.GameResult
  alias RetroHexChat.Observability
  alias RetroHexChat.Repo
  alias RetroHexChat.Topics

  @type player :: %{id: integer(), nickname: String.t()}

  @type match :: %{
          required(:game_id) => String.t(),
          required(:origin) => String.t(),
          required(:p1) => player(),
          required(:payload) => map(),
          required(:started_at) => DateTime.t(),
          optional(:p2) => player() | nil,
          optional(:difficulty) => String.t() | nil,
          optional(:finished_at) => DateTime.t(),
          optional(:lobby_token) => String.t() | nil,
          optional(:public?) => boolean()
        }

  @typedoc "What a card about one match draws, with no web concern in it."
  @type card :: %{
          result_id: integer(),
          game_id: String.t(),
          base_id: String.t(),
          origin: String.t(),
          difficulty: String.t() | nil,
          p1_nickname: String.t(),
          p2_nickname: String.t() | nil,
          p1_score: non_neg_integer(),
          p2_score: non_neg_integer(),
          outcome: Result.outcome(),
          ranked: boolean(),
          personal_best: boolean(),
          duration_ms: non_neg_integer(),
          finished_at: DateTime.t()
        }

  # Shorter than any real match of any game in the catalogue: a "finish"
  # reported this soon after the start is a page that sent a result without
  # playing, not a game. `:game_result_min_duration_ms` overrides it.
  @min_duration_ms 3_000

  @doc """
  Write a finished match and announce it.

  Refuses a game outside the catalogue, a payload no engine sends, a score the
  game cannot reach, a match shorter than any real one, and a finish already
  written for the same game of the same lobby session.
  """
  @spec record(match()) ::
          {:ok, GameResult.t()}
          | {:error,
             :unknown_game
             | :malformed
             | :implausible
             | :too_short
             | :already_recorded
             | Ecto.Changeset.t()}
  def record(%{game_id: game_id, origin: origin} = match) do
    Observability.span(
      [:retro_hex_chat, :games, :result, :record],
      %{game_id: game_id, origin: origin},
      fn -> do_record(match) end,
      &classify/1
    )
  end

  defp do_record(match) do
    finished_at = Map.get(match, :finished_at) || DateTime.utc_now()

    with {:ok, result} <- Result.normalize(match.game_id, match.payload),
         {:ok, duration_ms} <- duration(match.started_at, finished_at),
         attrs = attrs(match, result, duration_ms, finished_at),
         {:ok, row} <- insert_rated(Map.put(attrs, :personal_best, personal_best?(attrs))) do
      Announcer.announce(row)

      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        Topics.game_results(),
        {:game_result_recorded, row}
      )

      {:ok, row}
    end
  end

  defp duration(started_at, finished_at) do
    minimum = Application.get_env(:retro_hex_chat, :game_result_min_duration_ms, @min_duration_ms)

    case DateTime.diff(finished_at, started_at, :millisecond) do
      ms when ms >= minimum -> {:ok, ms}
      _too_short -> {:error, :too_short}
    end
  end

  defp attrs(match, %Result{} = result, duration_ms, finished_at) do
    p2 = Map.get(match, :p2)

    %{
      game_id: result.game_id,
      base_id: Catalog.base_id(result.game_id),
      origin: match.origin,
      difficulty: Map.get(match, :difficulty),
      p1_id: match.p1.id,
      p1_nickname: match.p1.nickname,
      p2_id: p2 && p2.id,
      p2_nickname: p2 && p2.nickname,
      p1_score: result.p1_score,
      p2_score: result.p2_score,
      outcome: Atom.to_string(result.outcome),
      ranked: not result.disconnected?,
      duration_ms: duration_ms,
      started_at: match.started_at,
      finished_at: finished_at,
      lobby_token: Map.get(match, :lobby_token),
      public: Map.get(match, :public?, true)
    }
  end

  # A best only means something where a score is the point of the game; in a
  # versus game the score is how a win was counted, not what was achieved.
  defp personal_best?(%{ranked: true, game_id: game_id} = attrs) do
    Catalog.ranking(game_id) != :versus and Queries.beats_personal_best?(attrs)
  end

  defp personal_best?(_unranked), do: false

  # The row and the ratings it moves are one write: a match is never on the
  # ledger without having counted, nor counted without being on it.
  defp insert_rated(attrs) do
    Repo.transaction(fn ->
      case Queries.insert(attrs) do
        {:ok, row} ->
          :ok = Ratings.apply_result(row)
          row

        {:error, changeset} ->
          Repo.rollback(refusal(changeset))
      end
    end)
  end

  defp refusal(%Ecto.Changeset{errors: errors} = changeset) do
    if Keyword.has_key?(errors, :lobby_token), do: :already_recorded, else: changeset
  end

  defp classify({:ok, %GameResult{outcome: outcome, ranked: ranked}}),
    do: %{result: "ok", outcome: outcome, ranked: ranked}

  defp classify({:error, reason}) when is_atom(reason), do: %{result: "rejected", reason: reason}
  defp classify({:error, _changeset}), do: %{result: "error", reason: :invalid}

  @doc """
  Remember a line that announced `result`, so a card can be drawn under it.

  `:channel` for the line in the game's channel, `:feed` for the one in the
  channel every game's results go to, `:private` for the one in the two
  players' conversation.
  """
  @spec attach_message(GameResult.t(), :channel | :feed | :private, integer()) ::
          {:ok, GameResult.t()} | {:error, Ecto.Changeset.t()}
  def attach_message(result, place, message_id),
    do: Queries.attach_message(result, %{message_column(place) => message_id})

  defp message_column(:channel), do: :channel_message_id
  defp message_column(:feed), do: :feed_message_id
  defp message_column(:private), do: :pm_message_id

  @doc """
  The cards for a screenful of lines, keyed by the line's id.

  Channel lines and private lines are numbered apart, so the caller says which
  kind it holds; a line of the other kind with the same id is not this card.
  Each card says where its line was (`:place`): a card in the game's own
  channel has no reason to point at that channel.
  """
  @spec cards_for_messages(:channel | :private, [integer()]) :: %{integer() => card()}
  def cards_for_messages(_kind, []), do: %{}

  def cards_for_messages(kind, ids) do
    places = if kind == :channel, do: [:channel, :feed], else: [:private]

    for place <- places,
        column = message_column(place),
        result <- Queries.by_message_ids(column, ids),
        into: %{},
        do: {Map.fetch!(result, column), Map.put(card(result), :place, place)}
  end

  @doc "What a card about `result` draws."
  @spec card(GameResult.t()) :: card()
  def card(%GameResult{} = result) do
    result
    |> Map.take([
      :game_id,
      :base_id,
      :origin,
      :difficulty,
      :p1_nickname,
      :p2_nickname,
      :p1_score,
      :p2_score,
      :ranked,
      :personal_best,
      :duration_ms,
      :finished_at
    ])
    |> Map.merge(%{result_id: result.id, outcome: String.to_existing_atom(result.outcome)})
  end

  @doc "A recorded match by id, or nil."
  @spec get(integer()) :: GameResult.t() | nil
  defdelegate get(id), to: Queries

  @doc """
  The standings of one game, best first: wins for a versus game, the best
  score for a score or co-op game.

  Options: `:origin` (`"p2p"`, the default, `"ai"`, or nil for both),
  `:difficulty` (for `"ai"`), `:since` and `:until` (a window, for "this
  week"), `:modes` (true to count every mode of `game_id`'s game together) and
  `:limit` (10).
  """
  @spec standings(String.t(), keyword()) :: [Queries.standing()]
  def standings(game_id, opts \\ []) do
    game =
      if Keyword.get(opts, :modes, false),
        do: %{base_id: Catalog.base_id(game_id)},
        else: %{game_id: game_id}

    filter =
      Map.merge(game, %{
        origin: Keyword.get(opts, :origin, "p2p"),
        difficulty: Keyword.get(opts, :difficulty),
        since: Keyword.get(opts, :since),
        until: Keyword.get(opts, :until)
      })

    order = if Catalog.ranking(game_id) == :versus, do: :wins, else: :best
    Queries.standings(filter, order, Keyword.get(opts, :limit, 10))
  end

  @type player_record :: %{
          rating: Ratings.record() | nil,
          people: Queries.totals() | nil,
          computer: Queries.totals() | nil,
          recent: [card()]
        }

  @doc """
  One player's record in a game and all its modes: their rating (a versus
  game between people), their ranked matches against people and against the
  computer, and their latest matches as cards.
  """
  @spec player_record(String.t(), integer(), pos_integer()) :: player_record()
  def player_record(game_id, player_id, limit \\ 5) do
    base_id = Catalog.base_id(game_id)
    totals = Queries.player_totals(base_id, player_id)

    %{
      rating: if(Catalog.ranking(base_id) == :versus, do: Ratings.of(base_id, player_id)),
      people: Map.get(totals, "p2p"),
      computer: Map.get(totals, "ai"),
      recent: base_id |> Queries.recent_of(player_id, limit) |> Enum.map(&card/1)
    }
  end

  @doc "The latest public matches of a game and all its modes, as cards, newest first."
  @spec recent(String.t(), pos_integer()) :: [card()]
  def recent(base_id, limit \\ 10), do: base_id |> Queries.recent(limit) |> Enum.map(&card/1)

  @doc "How many matches of a game and its modes finished since `since`."
  @spec count_since(String.t(), DateTime.t()) :: non_neg_integer()
  defdelegate count_since(base_id, since), to: Queries

  @doc "How many matches of every game finished in a window, keyed by base game."
  @spec counts_since(DateTime.t(), DateTime.t() | nil) :: %{String.t() => pos_integer()}
  defdelegate counts_since(since, until \\ nil), to: Queries

  @doc "When the newest match of a game and its modes finished, or nil."
  @spec last_finished_at(String.t()) :: DateTime.t() | nil
  defdelegate last_finished_at(base_id), to: Queries
end
