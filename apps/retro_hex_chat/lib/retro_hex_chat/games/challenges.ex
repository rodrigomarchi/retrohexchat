defmodule RetroHexChat.Games.Challenges do
  @moduledoc """
  The weekly challenge of each Retro Game.

  Every ISO week each game puts one of its variants up — the game itself or
  one of its modes, in turn — and the week's ranking of that variant decides
  who takes it: most wins against other people for a versus game, the best
  score against anybody for a score or co-op game. Nothing is stored: the
  week names the variant, and the ledger already holds the matches, so the
  challenge cannot disagree with the results it is made of.

  The bot that announces in the game's channel opens each week's challenge
  there on Monday and names last week's winner (`Jobs.GameChallengeWorker`);
  the game's page shows the current one.
  """

  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Games.Announcer
  alias RetroHexChat.Games.Catalog
  alias RetroHexChat.Games.Results

  @type t :: %{
          base_id: String.t(),
          game_id: String.t(),
          starts_at: DateTime.t(),
          ends_at: DateTime.t()
        }

  @doc "The challenge of `base_id` in the week that contains `date`."
  @spec for_week(String.t(), Date.t()) :: t()
  def for_week(base_id, %Date{} = date) do
    monday = Date.beginning_of_week(date, :monday)
    {_year, week} = :calendar.iso_week_number(Date.to_erl(monday))
    variants = [base_id | Enum.map(Catalog.modes_of(base_id), & &1.id)]
    starts_at = DateTime.new!(monday, ~T[00:00:00], "Etc/UTC")

    %{
      base_id: base_id,
      game_id: Enum.at(variants, rem(week, length(variants))),
      starts_at: starts_at,
      ends_at: DateTime.add(starts_at, 7, :day)
    }
  end

  @doc "Who leads `challenge` — or took it, once its week is over — or nil."
  @spec leader(t()) :: map() | nil
  def leader(challenge) do
    versus? = Catalog.ranking(challenge.game_id) == :versus

    standings =
      Results.standings(challenge.game_id,
        origin: if(versus?, do: "p2p", else: nil),
        since: challenge.starts_at,
        until: challenge.ends_at,
        limit: 1
      )

    case standings do
      [%{wins: 0} | _rest] when versus? -> nil
      [leader | _rest] -> leader
      [] -> nil
    end
  end

  @doc """
  Close last week's challenge and open this week's, in every game's channel.
  Returns how many channels were spoken in.
  """
  @spec turn_week(Date.t()) :: {:ok, %{posted: non_neg_integer()}}
  def turn_week(%Date{} = today) do
    posted =
      Enum.count(Catalog.base_games(), fn %{id: base_id} ->
        previous = for_week(base_id, Date.add(today, -7))
        current = for_week(base_id, today)
        text = Enum.join(Enum.reject([closing(previous), opening(current)], &is_nil/1), " ")
        Announcer.say(Catalog.channel_name(base_id), text) == :ok
      end)

    {:ok, %{posted: posted}}
  end

  defp closing(challenge) do
    case leader(challenge) do
      nil ->
        nil

      %{nickname: nickname} ->
        dgettext("games", "%{nickname} won last week's challenge in %{game}.",
          game: game_name(challenge.game_id),
          nickname: nickname
        )
    end
  end

  defp opening(challenge) do
    game = game_name(challenge.game_id)

    if Catalog.ranking(challenge.game_id) == :versus,
      do:
        dgettext(
          "games",
          "This week's challenge is %{game}. Win the most matches against other players.",
          game: game
        ),
      else: dgettext("games", "This week's challenge is %{game}. Get the best score.", game: game)
  end

  defp game_name(game_id) do
    {:ok, game} = Catalog.get_game(game_id)
    game.name
  end
end
