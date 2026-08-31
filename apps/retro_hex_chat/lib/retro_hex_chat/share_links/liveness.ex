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

  A match link is the one kind that dies by **success**: a 1v1 game is full the
  moment somebody takes the seat, so the answer here is "is the seat still
  empty", and the card says "already full" rather than "expired". Every other
  kind only ever stops working by failing.
  """

  alias RetroHexChat.Games.Catalog
  alias RetroHexChat.GroupCall
  alias RetroHexChat.GroupCall.Schema.Room
  alias RetroHexChat.Lobby
  alias RetroHexChat.Lobby.Schema.Session

  @spec live?(String.t(), map()) :: boolean()
  # A solo game link is alive as long as the game exists — it names a thing to
  # play, not a room. A match link names a room too, and a match dies by
  # **success**: the second player takes the only seat there was.
  def live?("play", %{"session_token" => session_token} = target) do
    Catalog.valid_game_id?(target["game_id"] || "") and open_seat?(session_token)
  end

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

  defp open_seat?(session_token) when is_binary(session_token) do
    match?({:ok, %Session{status: "open", peer_id: nil}}, Lobby.get_session(session_token))
  end

  defp open_seat?(_session_token), do: false
end
