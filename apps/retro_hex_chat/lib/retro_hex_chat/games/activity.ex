defmodule RetroHexChat.Games.Activity do
  @moduledoc """
  Who is playing a Retro Game right now, and which.

  The page a match is played on says so itself — `playing/3` when a match
  starts, `stopped/1` when it ends — and presence does the rest: a page that
  closes, crashes or loses its connection is off the list without anybody
  telling it, so the list never claims a match that is no longer happening.

  A match between two people whose session may be watched
  (`Lobby.watchable?/1`) carries that session, which is what makes it a live
  match others can find (`live_matches/1`). A private one never does.
  """

  alias RetroHexChat.Games.Catalog
  alias RetroHexChat.Games.Watchers
  alias RetroHexChat.Lobby
  alias RetroHexChat.Nickname
  alias RetroHexChat.Presence.Tracker
  alias RetroHexChat.Topics

  @type entry :: %{nickname: String.t(), game_id: String.t()}

  @type live_match :: %{
          token: String.t(),
          game_id: String.t(),
          players: [String.t()],
          watchers: non_neg_integer()
        }

  @doc """
  The calling process's player started a match of `game_id` — alone, or over
  the P2P session `session_token`.
  """
  @spec playing(String.t(), String.t(), String.t() | nil) :: :ok
  def playing(nickname, game_id, session_token \\ nil) do
    key = Nickname.key(nickname)
    meta = %{nickname: nickname, game_id: game_id, watch: Lobby.watch_token(session_token)}

    case Tracker.track(self(), Topics.games_playing(), key, meta) do
      {:ok, _ref} ->
        :ok

      {:error, {:already_tracked, _pid, _topic, _key}} ->
        {:ok, _ref} = Tracker.update(self(), Topics.games_playing(), key, meta)
        :ok
    end
  end

  @doc "The calling process's player is no longer in a match."
  @spec stopped(String.t()) :: :ok
  def stopped(nickname),
    do: Tracker.untrack(self(), Topics.games_playing(), Nickname.key(nickname))

  @doc "Everybody in a match now, keyed by `Nickname.key/1`."
  @spec now() :: %{String.t() => entry()}
  def now do
    Topics.games_playing()
    |> Tracker.list()
    |> Map.new(fn {key, %{metas: [meta | _rest]}} ->
      {key, Map.take(meta, [:nickname, :game_id])}
    end)
  end

  @doc """
  The matches being played now that anybody may watch — all of them, or those
  of `base_id` and its modes — the most watched first.
  """
  @spec live_matches(:all | String.t()) :: [live_match()]
  def live_matches(base_id \\ :all) do
    Topics.games_playing()
    |> Tracker.list()
    |> Enum.flat_map(fn {_key, %{metas: [meta | _rest]}} ->
      if is_binary(meta[:watch]), do: [meta], else: []
    end)
    |> Enum.filter(&(base_id == :all or Catalog.base_id(&1.game_id) == base_id))
    |> Enum.group_by(& &1.watch)
    |> Enum.map(fn {token, metas} ->
      %{
        token: token,
        game_id: hd(metas).game_id,
        players: metas |> Enum.map(& &1.nickname) |> Enum.sort(),
        watchers: Watchers.count(token)
      }
    end)
    |> Enum.sort_by(&{-&1.watchers, &1.token})
  end

  @doc "The nicknames playing `base_id` or one of its modes now, in order."
  @spec playing_in(String.t()) :: [String.t()]
  def playing_in(base_id) do
    for(
      %{nickname: nickname, game_id: game_id} <- Map.values(now()),
      Catalog.base_id(game_id) == base_id,
      do: nickname
    )
    |> Enum.sort()
  end
end
