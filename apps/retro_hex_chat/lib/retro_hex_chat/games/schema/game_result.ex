defmodule RetroHexChat.Games.Schema.GameResult do
  @moduledoc """
  One finished Retro Games match: who played it, against whom, and how it ended.

  A match against the computer has no second player — `p2_id` and
  `p2_nickname` are empty and `difficulty` says how hard the computer played. A
  match between two people carries the lobby session it was played in, which
  is what keeps a finish reported twice from being written twice.

  The nicknames are copied rather than joined: a ranking and a line in a
  channel name the player as they were called when they played, and a nick
  that later expires leaves its matches behind with no account attached.

  `ranked` is false for a match that ended because somebody left — its score is
  real but it decided nothing, so it appears in history and nowhere it could
  win or lose a place. `personal_best` is decided once, when the match is
  written: a best beaten later stays the best it was on the day.

  `public` is false for a match two people played in a session one of them
  invited the other to: it counts, and its players' conversation keeps it, but
  no channel or public page says who played whom.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias RetroHexChat.Games.Result

  @type t :: %__MODULE__{}

  @origins ~w(ai p2p solo)
  @difficulties ~w(easy normal hard)
  @outcomes Enum.map(Result.outcomes(), &Atom.to_string/1)

  schema "game_results" do
    field :game_id, :string
    field :base_id, :string
    field :origin, :string
    field :difficulty, :string
    field :p1_id, :integer
    field :p1_nickname, :string
    field :p2_id, :integer
    field :p2_nickname, :string
    field :p1_score, :integer
    field :p2_score, :integer
    field :outcome, :string
    field :ranked, :boolean
    field :personal_best, :boolean, default: false
    field :public, :boolean, default: true
    field :duration_ms, :integer
    field :started_at, :utc_datetime_usec
    field :finished_at, :utc_datetime_usec
    field :lobby_token, :string
    field :channel_message_id, :integer
    field :feed_message_id, :integer
    field :pm_message_id, :integer

    timestamps(type: :utc_datetime_usec)
  end

  @fields ~w(game_id base_id origin difficulty p1_id p1_nickname p2_id p2_nickname p1_score
             p2_score outcome ranked personal_best public duration_ms started_at finished_at lobby_token)a

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(result, attrs) do
    result
    |> cast(attrs, @fields)
    |> validate_required(
      ~w(game_id base_id origin p1_nickname p1_score p2_score outcome ranked personal_best duration_ms
         started_at finished_at)a
    )
    |> validate_inclusion(:origin, @origins)
    |> validate_inclusion(:difficulty, @difficulties)
    |> validate_inclusion(:outcome, @outcomes)
    |> validate_number(:p1_score, greater_than_or_equal_to: 0)
    |> validate_number(:p2_score, greater_than_or_equal_to: 0)
    |> validate_number(:duration_ms, greater_than_or_equal_to: 0)
    |> validate_length(:p1_nickname, max: 16)
    |> validate_length(:p2_nickname, max: 16)
    |> validate_length(:lobby_token, max: 64)
    |> validate_origin_shape()
    |> unique_constraint([:lobby_token, :started_at],
      name: :game_results_lobby_token_started_at_index
    )
  end

  # The origins are shapes of the same row: the computer has a difficulty and
  # no nickname, a person has a nickname and no difficulty, and a player alone
  # has neither.
  defp validate_origin_shape(changeset) do
    case get_field(changeset, :origin) do
      "ai" -> validate_required(changeset, [:difficulty])
      "p2p" -> validate_required(changeset, [:p2_nickname, :lobby_token])
      "solo" -> refuse_present(changeset, [:difficulty, :p2_nickname])
      _other -> changeset
    end
  end

  defp refuse_present(changeset, fields) do
    Enum.reduce(fields, changeset, fn field, acc ->
      if get_field(acc, field) == nil,
        do: acc,
        else: add_error(acc, field, "must be empty for a match played alone")
    end)
  end

  @doc """
  Attach a line that announced this match: in the game's channel, in the
  channel every game's results go to, or in the players' conversation.
  """
  @spec message_changeset(t(), map()) :: Ecto.Changeset.t()
  def message_changeset(result, attrs),
    do: cast(result, attrs, [:channel_message_id, :feed_message_id, :pm_message_id])
end
