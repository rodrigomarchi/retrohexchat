defmodule RetroHexChat.Games.Digest do
  @moduledoc """
  The day in each game's channel, said once, the morning after.

  Most matches never reach a channel — a loss to the computer on easy is
  nobody's news — so a room could look empty on a day it was busy. The digest
  is the one line that counts all of them: how many matches the game had, and
  who did best. A game nobody played says nothing.
  """

  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Games.Announcer
  alias RetroHexChat.Games.Catalog
  alias RetroHexChat.Games.Results

  @doc """
  Say `date`'s digest (UTC) in every game channel that had a match that day.
  Returns how many channels were spoken in.
  """
  @spec post(Date.t()) :: {:ok, %{posted: non_neg_integer()}}
  def post(%Date{} = date) do
    since = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    until = DateTime.add(since, 1, :day)

    posted =
      since
      |> Results.counts_since(until)
      |> Enum.count(fn {base_id, count} ->
        line = line(base_id, count, leader(base_id, since, until))
        Announcer.say(Catalog.channel_name(base_id), line) == :ok
      end)

    {:ok, %{posted: posted}}
  end

  defp leader(base_id, since, until) do
    base_id
    |> Results.standings(modes: true, origin: nil, since: since, until: until, limit: 1)
    |> List.first()
  end

  @doc "The digest's sentence for one game."
  @spec line(String.t(), pos_integer(), map() | nil) :: String.t()
  def line(base_id, count, leader) do
    {:ok, game} = Catalog.get_game(base_id)

    matches =
      dngettext(
        "games",
        "Yesterday in %{game}: %{count} match.",
        "Yesterday in %{game}: %{count} matches.",
        count,
        game: game.name,
        count: count
      )

    case {Catalog.ranking(base_id), leader} do
      {_ranking, nil} ->
        matches

      {:versus, %{wins: 0}} ->
        matches

      {:versus, %{nickname: nickname, wins: wins}} ->
        matches <>
          " " <>
          dngettext(
            "games",
            "Most wins: %{nickname} (%{count}).",
            "Most wins: %{nickname} (%{count}).",
            wins,
            nickname: nickname,
            count: wins
          )

      {_score_or_coop, %{nickname: nickname, best: best}} ->
        matches <>
          " " <>
          dgettext("games", "Best score: %{nickname} (%{best}).", nickname: nickname, best: best)
    end
  end
end
