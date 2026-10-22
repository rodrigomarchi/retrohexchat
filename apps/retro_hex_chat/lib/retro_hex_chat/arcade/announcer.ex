defmodule RetroHexChat.Arcade.Announcer do
  @moduledoc """
  Says that somebody started an arcade game, in the game's channel and in
  `#arcade`, as whichever bot of that room carries the `game` capability —
  the same voice and the same rule as `Games.Announcer`: a room with no such
  bot hears nothing.

  Starting is all there is to say. The game runs in a tab of its own and the
  app never learns how it went or when it stopped.

  Somebody who goes back to the catalogue and presses Play again is news once:
  a player is said in a game's channel at most once every few minutes, the
  same interval the Retro Games keep.

  The line is plain text in the server's language — what search, the public
  archive and a reader who turned formatting off see. Everyone else sees the
  card drawn under it, in their own language.
  """

  use Gettext, backend: RetroHexChat.Gettext

  require Logger

  alias RetroHexChat.Arcade.{Catalog, Plays, Queries}
  alias RetroHexChat.Arcade.Schema.SoloSession
  alias RetroHexChat.Games.Announcer, as: GamesAnnouncer
  alias RetroHexChat.Repo
  alias RetroHexChat.Services.RegisteredNick
  alias RetroHexChat.Topics

  # `:game_announce_interval_ms` overrides it, as it does for the Retro Games.
  @interval_ms :timer.minutes(5)

  @doc """
  Announce that `session`'s game was just started. Never raises: the game is
  already open in the player's tab, whatever happens to the line about it.
  """
  @spec started(SoloSession.t()) :: :ok
  def started(%SoloSession{game_id: game_id, game_started_at: %DateTime{}} = session)
      when is_binary(game_id) do
    with %RegisteredNick{nickname: nickname} <- Repo.get(RegisteredNick, session.creator_id) do
      unless just_announced?(session) do
        line = line(nickname, game_id)
        in_channel(session, line, Catalog.channel_name(game_id), :channel)
        in_channel(session, line, Catalog.feed_channel(), :feed)
      end

      Phoenix.PubSub.broadcast(
        RetroHexChat.PubSub,
        Topics.arcade_plays(),
        {:arcade_play_started, %{game_id: game_id}}
      )
    end

    :ok
  rescue
    exception ->
      Logger.warning(
        "Arcade play #{session.id} was not announced: #{Exception.message(exception)}"
      )

      :ok
  end

  def started(_session_without_a_game), do: :ok

  defp just_announced?(session) do
    interval = Application.get_env(:retro_hex_chat, :game_announce_interval_ms, @interval_ms)

    Queries.announced_since?(
      session,
      DateTime.add(session.game_started_at, -interval, :millisecond)
    )
  end

  defp in_channel(session, line, channel, place) do
    GamesAnnouncer.say(channel, line, before_broadcast: &Plays.attach_message(session, place, &1))
  end

  @doc "The sentence a play is announced with."
  @spec line(String.t(), String.t()) :: String.t()
  def line(nickname, game_id) do
    dgettext("arcade", "%{nickname} started the game %{game}",
      nickname: nickname,
      game: game_name(game_id)
    )
  end

  defp game_name(game_id) do
    case Catalog.get_game(game_id) do
      {:ok, game} -> game.name
      {:error, :not_found} -> game_id
    end
  end
end
