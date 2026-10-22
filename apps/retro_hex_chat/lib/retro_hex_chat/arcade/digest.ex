defmodule RetroHexChat.Arcade.Digest do
  @moduledoc """
  The day in each arcade game's channel, said once, the morning after: how
  many times the game was started, and by how many people. A play is said in
  the room as it starts only once every few minutes per player, so the digest
  is the one line that counts all of them. A game nobody played says nothing,
  and neither does one the catalogue no longer has.
  """

  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Arcade.{Catalog, Plays}
  alias RetroHexChat.Games.Announcer

  @doc """
  Say `date`'s digest (UTC) in every arcade game's channel that had a play
  that day. Returns how many channels were spoken in.
  """
  @spec post(Date.t()) :: {:ok, %{posted: non_neg_integer()}}
  def post(%Date{} = date) do
    since = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    until = DateTime.add(since, 1, :day)

    posted =
      since
      |> Plays.counts_between(until)
      |> Enum.filter(fn {game_id, _counts} -> Catalog.valid_game_id?(game_id) end)
      |> Enum.count(fn {game_id, counts} ->
        Announcer.say(Catalog.channel_name(game_id), line(game_id, counts)) == :ok
      end)

    {:ok, %{posted: posted}}
  end

  @doc "The digest's sentence for one game."
  @spec line(String.t(), %{plays: pos_integer(), people: pos_integer()}) :: String.t()
  def line(game_id, %{plays: plays, people: people}) do
    {:ok, game} = Catalog.get_game(game_id)

    dngettext(
      "arcade",
      "Yesterday, %{game} was started once by %{players}.",
      "Yesterday, %{game} was started %{count} times by %{players}.",
      plays,
      game: game.name,
      count: plays,
      players: dngettext("arcade", "%{count} player", "%{count} players", people, count: people)
    )
  end
end
