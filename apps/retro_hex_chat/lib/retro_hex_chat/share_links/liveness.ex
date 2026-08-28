defmodule RetroHexChat.ShareLinks.Liveness do
  @moduledoc """
  Whether the thing a link names is still there.

  Derived from the runtime on every resolution, never stored. A stored flag
  would be a second source of truth about a room's state, which is the same
  reason the P2P context checks for a duplicate session with a query instead of
  a Registry lookup: a crashed-but-not-restarted process makes the cheap answer
  a wrong one.

  A space is always live because a space does not end — it is a place, and the
  link to it is an address rather than an invitation to an event.
  """

  alias RetroHexChat.Games.Catalog
  alias RetroHexChat.GroupCall
  alias RetroHexChat.GroupCall.Schema.Room
  alias RetroHexChat.Lobby
  alias RetroHexChat.Lobby.Schema.Session

  @spec live?(String.t(), map()) :: boolean()
  def live?("play", target), do: Catalog.valid_game_id?(target["game_id"] || "")

  def live?("space", _target), do: true

  def live?("call", target) do
    case GroupCall.get_room(target["room_token"] || "") do
      {:ok, room} -> not Room.terminal?(room.status)
      _other -> false
    end
  end

  def live?("p2p", target) do
    case Lobby.get_session(target["session_token"] || "") do
      {:ok, session} -> not Session.terminal?(session.status)
      _other -> false
    end
  end

  def live?(_kind, _target), do: false
end
