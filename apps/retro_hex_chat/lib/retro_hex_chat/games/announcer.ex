defmodule RetroHexChat.Games.Announcer do
  @moduledoc """
  Says that a match was played, wherever it should be heard.

  A match between two people is written into their private conversation, as
  the line the P2P session has always left behind, now carrying the match's
  card. The matches worth telling a room about — every ranked match between
  two people in a session played in the open, and against the computer a personal best or a win on hard — are
  also said by GameServ in the game's channel and in `#retro-games`. A loss to
  the computer on easy is nobody's news, and a channel that printed every one
  would be a log nobody reads. For the same reason a player is news in a
  game's channel at most once every few minutes: rematch after rematch, or a
  best climbing a point at a time, stays in the conversation and the ledger.

  Every line about a match is written by `line/1`, so the sentence a
  conversation keeps and the one a channel archives are the same sentence.

  The line is plain text in the server's language: it is what search, the
  public archive and a reader who turned formatting off see. Everyone else
  sees the card drawn under it, in their own language.
  """

  use Gettext, backend: RetroHexChat.Gettext

  require Logger

  alias RetroHexChat.Channels.Server, as: ChannelServer
  alias RetroHexChat.Chat.Service, as: ChatService
  alias RetroHexChat.Games.Catalog
  alias RetroHexChat.Games.Channels
  alias RetroHexChat.Games.Queries
  alias RetroHexChat.Games.Results
  alias RetroHexChat.Games.Schema.GameResult

  # `:game_announce_interval_ms` overrides it.
  @interval_ms :timer.minutes(5)

  @doc "Announce a match just written. Never fails the write it follows."
  @spec announce(GameResult.t()) :: :ok
  def announce(%GameResult{} = result) do
    in_conversation(result)

    if newsworthy?(result) and not just_announced?(result) do
      in_channel(result, Catalog.channel_name(result.game_id), :channel)
      in_channel(result, Channels.feed(), :feed)
    end

    :ok
  end

  @doc "Whether a match is worth a line in its game's channel."
  @spec newsworthy?(GameResult.t()) :: boolean()
  def newsworthy?(%GameResult{ranked: false}), do: false
  def newsworthy?(%GameResult{public: false}), do: false
  def newsworthy?(%GameResult{origin: "p2p"}), do: true
  def newsworthy?(%GameResult{personal_best: true}), do: true

  def newsworthy?(%GameResult{difficulty: "hard", outcome: outcome}),
    do: outcome in ~w(p1 coop_win)

  def newsworthy?(_routine_match), do: false

  defp just_announced?(result) do
    interval = Application.get_env(:retro_hex_chat, :game_announce_interval_ms, @interval_ms)
    Queries.announced_since?(result, DateTime.add(result.finished_at, -interval, :millisecond))
  end

  defp in_channel(result, channel, place) do
    say(channel, line(result), before_broadcast: &Results.attach_message(result, place, &1))
  end

  @doc """
  Say `text` in a games channel as GameServ. `opts` are the channel's send
  options (`:before_broadcast` to attach a card).

  GameServ's membership lives in the channel's process, which forgets it on a
  restart; one refused send puts the service back and says it again.
  """
  @spec say(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def say(channel, text, opts \\ []) do
    send = fn -> ChannelServer.send_message(channel, Channels.service(), text, :message, opts) end

    with {:error, _not_inside} <- safe(send),
         :ok <- Channels.ensure_present(channel),
         {:error, reason} = refused <- safe(send) do
      Logger.warning("GameServ could not speak in #{channel}: #{inspect(reason)}")
      refused
    else
      {:ok, _message_id} -> :ok
      {:error, _not_started} = refused -> refused
    end
  end

  # A channel whose process is not running answers a call with an exit.
  defp safe(send) do
    send.()
  catch
    :exit, reason -> {:error, reason}
  end

  defp in_conversation(%GameResult{origin: "p2p"} = result) do
    case ChatService.send_private_message(
           result.p1_nickname,
           result.p2_nickname,
           line(result),
           "p2p_system",
           before_broadcast: &Results.attach_message(result, :private, &1)
         ) do
      {:ok, _message} ->
        :ok

      {:error, reason} ->
        Logger.warning(
          "Match #{result.id} was not written to its conversation: #{inspect(reason)}"
        )
    end
  end

  defp in_conversation(_match_against_the_computer), do: :ok

  @doc "The sentence a match is announced with."
  @spec line(GameResult.t()) :: String.t()
  def line(%GameResult{} = result) do
    bindings = %{
      game: game_name(result.game_id),
      p1: result.p1_nickname,
      p2: result.p2_nickname || computer(result.difficulty),
      p1_score: result.p1_score,
      p2_score: result.p2_score
    }

    sentence(result, bindings)
  end

  defp sentence(%GameResult{ranked: false}, bindings),
    do:
      dgettext(
        "games",
        "%{p1} vs %{p2} in %{game} ended early, %{p1_score} × %{p2_score}",
        bindings
      )

  # Against the computer, a best is the news; who won is the score beside it.
  defp sentence(%GameResult{origin: "ai", personal_best: true}, bindings),
    do: dgettext("games", "%{p1} set a personal best of %{p1_score} in %{game}", bindings)

  defp sentence(%GameResult{outcome: "p1"}, bindings),
    do: dgettext("games", "%{p1} beat %{p2} %{p1_score} × %{p2_score} in %{game}", bindings)

  defp sentence(%GameResult{outcome: "p2"}, bindings),
    do: dgettext("games", "%{p2} beat %{p1} %{p2_score} × %{p1_score} in %{game}", bindings)

  defp sentence(%GameResult{outcome: "draw"}, bindings),
    do:
      dgettext(
        "games",
        "It is a draw between %{p1} and %{p2}, %{p1_score} × %{p2_score}, in %{game}",
        bindings
      )

  defp sentence(%GameResult{outcome: "coop_win"}, bindings),
    do: dgettext("games", "%{p1} and %{p2} cleared %{game} with %{p1_score} points", bindings)

  defp sentence(_no_verdict, bindings),
    do:
      dgettext(
        "games",
        "%{p1} and %{p2} finished %{game} with %{p1_score} and %{p2_score} points",
        bindings
      )

  defp game_name(game_id) do
    case Catalog.get_game(game_id) do
      {:ok, game} -> game.name
      {:error, :not_found} -> game_id
    end
  end

  defp computer("easy"), do: dgettext("games", "the computer (easy)")
  defp computer("hard"), do: dgettext("games", "the computer (hard)")
  defp computer(_normal), do: dgettext("games", "the computer")
end
