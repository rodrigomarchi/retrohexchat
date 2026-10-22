defmodule RetroHexChat.Games.RoomFacts do
  @moduledoc """
  What the bot of a Retro Games room says about the room's game, read from
  the catalogue and the ledger rather than written into a script, so each
  game's room talks about its own game. The ranking is of all time and every
  mode of the game: wins against people for a versus game, the best score
  against anybody for a score or co-op game. The challenge is the week's, as
  the game's page and the Monday announcement name it.

  An arcade game's room has one fact: the line that opens it while nothing
  has been said there yet. An arcade game has no ledger to ask about, and its
  room's greeting is the arcade bot's own.

  Every line is English, the language the game rooms are spoken in, whoever
  reads it. A channel that is none of these rooms has no facts.
  """

  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Arcade
  alias RetroHexChat.Games.Announcer
  alias RetroHexChat.Games.Catalog
  alias RetroHexChat.Games.Challenges
  alias RetroHexChat.Games.Queries
  alias RetroHexChat.Games.Results

  @locale "en"
  @ranking_size 5
  @recent_size 3
  @commands ~w(howto ranking challenge recent)

  @doc "The words that ask a game's room for its facts, without the prefix."
  @spec commands() :: [String.t()]
  def commands, do: @commands

  @doc "Whether `channel` is a game's room — a Retro Game's or an arcade game's — or the feed."
  @spec room?(String.t()) :: boolean()
  def room?(channel), do: room(channel) != :none

  @doc """
  The lines told privately to somebody arriving in `channel`: what the game
  is, and where its week stands. Empty for any other channel.
  """
  @spec welcome(String.t()) :: [String.t()]
  def welcome(channel) do
    in_english(fn ->
      case room(channel) do
        {:game, game} ->
          [
            about(game),
            Enum.join([Challenges.opening(challenge(game.id)), standing(game.id)], " ") <>
              " " <> commands_hint()
          ]

        :feed ->
          [feed_about(), latest_line()]

        _arcade_or_none ->
          []
      end
    end)
  end

  @doc """
  The one line said in `channel` when nothing has been said there yet, so
  whoever opens the room finds what it is for. Nil for any other channel.
  """
  @spec intro(String.t()) :: String.t() | nil
  def intro(channel) do
    in_english(fn ->
      case room(channel) do
        {:game, game} ->
          Enum.join([about(game), how_to_start(), commands_hint()], " ")

        :feed ->
          feed_about()

        {:arcade, game} ->
          Enum.join([about(game), how_to_start_arcade()], " ")

        :none ->
          nil
      end
    end)
  end

  @doc """
  The answer to `command` (one of `commands/0`) asked in `channel`, or
  `:unknown` for anything else.
  """
  @spec answer(String.t(), String.t()) :: {:ok, String.t()} | :unknown
  def answer(command, channel) do
    case room(channel) do
      {:game, _game} = room when command in @commands ->
        {:ok, in_english(fn -> answer_in(command, room) end)}

      :feed when command in @commands ->
        {:ok, in_english(fn -> answer_in(command, :feed) end)}

      _arcade_or_none ->
        :unknown
    end
  end

  defp answer_in("howto", {:game, game}) do
    "#{game.name}: #{game.controls}. #{how_to_start()}"
  end

  defp answer_in("ranking", {:game, game}), do: ranking(game)

  defp answer_in("challenge", {:game, game}) do
    Enum.join([Challenges.opening(challenge(game.id)), standing(game.id)], " ")
  end

  defp answer_in("recent", {:game, game}) do
    case Queries.recent(game.id, @recent_size) do
      [] -> dgettext("games", "No public match of %{game} yet.", game: game.name)
      matches -> Enum.map_join(matches, " · ", &Announcer.line/1)
    end
  end

  defp answer_in("recent", :feed), do: latest_line()

  defp answer_in(_command, :feed), do: feed_rooms()

  defp room(channel) do
    cond do
      channel == Catalog.feed_channel() ->
        :feed

      match?({:ok, _id}, Catalog.game_for_channel(channel)) ->
        {:ok, id} = Catalog.game_for_channel(channel)
        {:ok, game} = Catalog.get_game(id)
        {:game, game}

      match?({:ok, _id}, Arcade.game_for_channel(channel)) ->
        {:ok, id} = Arcade.game_for_channel(channel)
        {:ok, game} = Arcade.get_game(id)
        {:arcade, game}

      true ->
        :none
    end
  end

  defp about(game), do: "#{game.name}: #{game.description}"

  defp how_to_start,
    do:
      dgettext(
        "games",
        "Press Play under the topic to start, or Find a partner to play with someone here."
      )

  defp how_to_start_arcade,
    do: dgettext("games", "Press Play under the topic to start it in your browser.")

  defp commands_hint,
    do:
      dgettext("games", "Ask %{commands} for more.",
        commands: "!ranking !challenge !recent !howto"
      )

  defp feed_about do
    Enum.join(
      [
        dgettext("games", "Every notable Retro Games match is announced here when it ends."),
        feed_rooms()
      ],
      " "
    )
  end

  defp feed_rooms,
    do:
      dgettext("games", "Each game also has its own room.") <>
        " " <> Enum.join(Catalog.channel_names(), " ")

  defp latest_line do
    case Queries.recent_any(1) do
      [] -> dgettext("games", "No public match has been played yet.")
      [match] -> dgettext("games", "Latest: %{line}", line: Announcer.line(match))
    end
  end

  defp challenge(game_id), do: Challenges.for_week(game_id, Date.utc_today())

  defp standing(game_id) do
    challenge = challenge(game_id)

    case Challenges.leader(challenge) do
      nil ->
        dgettext("games", "Nobody leads it yet.")

      leader ->
        dgettext("games", "%{player} leads it.", player: player(challenge.game_id, leader))
    end
  end

  defp ranking(game) do
    versus? = Catalog.ranking(game.id) == :versus

    standings =
      Results.standings(game.id,
        modes: true,
        origin: if(versus?, do: "p2p", else: nil),
        limit: @ranking_size
      )
      |> Enum.reject(&(versus? and &1.wins == 0))

    case standings do
      [] ->
        dgettext("games", "%{game} has no ranking yet.", game: game.name) <>
          " " <> how_to_rank(versus?)

      standings ->
        places =
          standings
          |> Enum.with_index(1)
          |> Enum.map_join(" · ", fn {standing, place} ->
            "#{place}. #{player(game.id, standing)}"
          end)

        "#{game.name} — #{places}"
    end
  end

  defp how_to_rank(true), do: dgettext("games", "Win a match against another player to enter it.")
  defp how_to_rank(false), do: dgettext("games", "Finish a ranked match to enter it.")

  defp player(game_id, %{nickname: nickname} = standing) do
    if Catalog.ranking(game_id) == :versus,
      do:
        dngettext(
          "games",
          "%{nickname} (%{count} win)",
          "%{nickname} (%{count} wins)",
          standing.wins,
          nickname: nickname,
          count: standing.wins
        ),
      else: "#{nickname} (#{standing.best})"
  end

  defp in_english(fun), do: Gettext.with_locale(RetroHexChat.Gettext, @locale, fun)
end
