defmodule RetroHexChat.Arcade.Plays do
  @moduledoc """
  Who started which arcade game, and when — read from the sessions themselves.

  An arcade game has no result: it runs in a tab of its own, on another
  address, and the app never hears from it. What the app does know is the
  moment somebody pressed Play on a game (`SoloSession.game_started_at`), and
  that is all a play is here. How long they played is not known and never
  claimed.

  Only players whose account still exists are named, by their current
  nickname, the way the Retro Games standings name them.
  """

  alias RetroHexChat.Arcade.Queries
  alias RetroHexChat.Arcade.Schema.SoloSession

  @type card :: %{
          play_id: integer(),
          game_id: String.t(),
          nickname: String.t(),
          started_at: DateTime.t(),
          place: :channel | :feed
        }

  @doc """
  Remember a line that said `session`'s game was started, so a card can be
  drawn under it: `:channel` for the game's own channel, `:feed` for `#arcade`.
  """
  @spec attach_message(SoloSession.t(), :channel | :feed, integer()) ::
          {:ok, SoloSession.t()} | {:error, Ecto.Changeset.t()}
  def attach_message(session, place, message_id),
    do: Queries.attach_message(session, %{message_column(place) => message_id})

  defp message_column(:channel), do: :channel_message_id
  defp message_column(:feed), do: :feed_message_id

  @doc """
  The cards for a screenful of channel lines, keyed by the line's id. Each says
  where its line was (`:place`): a card in the game's own channel has no reason
  to point at that channel.
  """
  @spec cards_for_messages([integer()]) :: %{integer() => card()}
  def cards_for_messages([]), do: %{}

  def cards_for_messages(ids) do
    asked = MapSet.new(ids)

    # One query for both places; each play may have been said in either or both.
    for play <- Queries.plays_by_message_ids(ids),
        place <- [:channel, :feed],
        id = Map.fetch!(play, message_column(place)),
        MapSet.member?(asked, id),
        into: %{},
        do: {id, card(play, place)}
  end

  defp card(play, place) do
    play
    |> Map.take([:game_id, :nickname, :started_at])
    |> Map.merge(%{play_id: play.id, place: place})
  end

  @doc "The latest plays of a game, newest first."
  @spec recent(String.t(), pos_integer()) :: [map()]
  defdelegate recent(game_id, limit), to: Queries, as: :recent_plays

  @doc "Who started a game most often since `since`."
  @spec most_played(String.t(), DateTime.t(), pos_integer()) :: [map()]
  defdelegate most_played(game_id, since, limit), to: Queries

  @doc "How many times a game was started since `since`."
  @spec count_since(String.t(), DateTime.t()) :: non_neg_integer()
  defdelegate count_since(game_id, since), to: Queries, as: :play_count

  @doc "Plays and players per game between `since` and `until`."
  @spec counts_between(DateTime.t(), DateTime.t()) :: %{String.t() => map()}
  defdelegate counts_between(since, until), to: Queries, as: :play_counts

  @doc "One player's plays of a game: how many, the first and the last."
  @spec player_record(String.t(), integer()) :: map()
  defdelegate player_record(game_id, player_id), to: Queries, as: :player_plays
end
