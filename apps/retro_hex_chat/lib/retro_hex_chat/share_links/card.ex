defmodule RetroHexChat.ShareLinks.Card do
  @moduledoc """
  What a shared link looks like sitting in a conversation.

  A link resolves to a room; a card is that room *right now*, phrased for
  somebody scrolling past it who may never follow it. That is a different
  question from the one `Liveness` answers — "is it still there" — because the
  card has to say something useful when the answer is no. A closed link is not
  a blank space in the history: it is the record that a call happened, with the
  next plausible thing to do about it.

  Everything here is derived on read. Storing a participant count would be a
  second source of truth about a room, out of date the moment somebody joins,
  and the whole point of the live card is that it is not.

  **The channel's name is not part of the room's state.** A card appears in a
  conversation whose readers may not be in that channel — may not be in the
  product — so the name is carried only when `Channels.Visibility.nameable?/1`
  says a stranger could have listed the channel anyway. Everything else about
  the card is the same for everyone, which is what keeps it from becoming an
  oracle about which private channels exist.
  """

  alias RetroHexChat.Channels.Visibility
  alias RetroHexChat.Games.Catalog
  alias RetroHexChat.GroupCall
  alias RetroHexChat.GroupCall.Schema.Room
  alias RetroHexChat.Lobby
  alias RetroHexChat.Lobby.Schema.Session
  alias RetroHexChat.ShareLinks.Schema.Link
  alias RetroHexChat.VirtualSpace

  @typedoc """
  Why a card is no longer live. `:revoked` and `:expired` are things done to
  the link; `:over` and `:full` are things that happened in the room.
  """
  @type reason :: :revoked | :expired | :over | :full | nil

  @type t :: %{
          slug: String.t(),
          kind: String.t(),
          target: map(),
          creator_nick: String.t() | nil,
          state: :live | :ended,
          reason: reason(),
          count: non_neg_integer() | nil,
          participants: [String.t()],
          channel_name: String.t() | nil,
          game_id: String.t() | nil
        }

  @doc "The card for one link, as of now."
  @spec of(Link.t()) :: t()
  def of(%Link{} = link) do
    closed = closed_reason(link)

    base = %{
      slug: link.slug,
      kind: link.kind,
      target: link.target || %{},
      creator_nick: link.creator_nick,
      state: :live,
      reason: nil,
      count: nil,
      participants: [],
      channel_name: nil,
      game_id: nil
    }

    base
    |> Map.merge(room_state(link.kind, link.target || %{}))
    |> close_when(closed)
  end

  @doc """
  The card for a P2P session that has no share link of its own.

  The invite in a private message carries the session's own address: the token
  *is* the invitation, so there is nothing to mint and nothing to revoke apart
  from the session. It draws the same card as every other kind, which is what
  makes it a variant rather than a second component — with no slug, because
  there is no address here that belongs to anybody but the two of them.
  """
  @spec for_session(String.t() | nil) :: t() | nil
  def for_session(token) when is_binary(token) and token != "" do
    %{
      slug: nil,
      kind: "p2p",
      target: %{"session_token" => token},
      creator_nick: nil,
      state: :live,
      reason: nil,
      count: nil,
      participants: [],
      channel_name: nil,
      game_id: nil
    }
    |> Map.merge(room_state("p2p", %{"session_token" => token}))
  end

  def for_session(_token), do: nil

  # A link closed by hand outranks whatever the room is doing: the person who
  # revoked it said this address is finished, and a room that happens to still
  # be running does not un-say it.
  defp close_when(card, nil), do: card
  defp close_when(card, reason), do: %{card | state: :ended, reason: reason}

  defp closed_reason(%Link{revoked_at: %DateTime{}}), do: :revoked

  defp closed_reason(%Link{expires_at: %DateTime{} = expires_at}) do
    if DateTime.after?(DateTime.utc_now(), expires_at), do: :expired
  end

  defp closed_reason(%Link{}), do: nil

  defp room_state("call", target) do
    token = target["room_token"] || ""

    case GroupCall.get_summary(token) do
      {:ok, summary} ->
        participants = participant_nicks(summary)
        room = Map.get(summary, :room) || %{}
        channel = Map.get(room, :channel_name)

        %{
          state: if(terminal_room?(room), do: :ended, else: :live),
          reason: if(terminal_room?(room), do: :over),
          count: length(participants),
          participants: Enum.take(participants, 3),
          channel_name: nameable(channel)
        }

      _other ->
        %{state: :ended, reason: :over}
    end
  end

  defp room_state("space", target) do
    space_id = target["space_id"] || ""
    roster = VirtualSpace.roster(space_id)

    %{
      count: length(roster),
      participants: Enum.take(roster, 3),
      channel_name: space_channel_name(space_id)
    }
  end

  # A match link dies by success: the seat it offered is taken, and "already
  # full" is a different sentence from "expired" because it names something
  # that worked.
  defp room_state("play", %{"session_token" => token} = target) when is_binary(token) do
    game_id = target["game_id"]

    case Lobby.get_session(token) do
      {:ok, %Session{status: "open", peer_id: nil}} ->
        %{count: 1, game_id: game_id}

      {:ok, %Session{}} ->
        %{state: :ended, reason: :full, game_id: game_id}

      _other ->
        %{state: :ended, reason: :over, game_id: game_id}
    end
  end

  # A solo game link names a thing to play rather than a room, so it is alive
  # exactly as long as the game is in the catalogue.
  defp room_state("play", target) do
    game_id = target["game_id"] || ""

    if Catalog.valid_game_id?(game_id) do
      %{game_id: game_id}
    else
      %{state: :ended, reason: :over, game_id: game_id}
    end
  end

  defp room_state("p2p", target) do
    case Lobby.get_session(target["session_token"] || "") do
      {:ok, %Session{status: status}} when status not in ["closed", "expired", "failed"] ->
        %{count: seats(status)}

      _other ->
        %{state: :ended, reason: :over}
    end
  end

  defp room_state(_kind, _target), do: %{state: :ended, reason: :over}

  defp seats("open"), do: 1
  defp seats(_status), do: 2

  defp terminal_room?(%{status: status}) when is_binary(status), do: Room.terminal?(status)
  defp terminal_room?(_room), do: false

  defp participant_nicks(summary) do
    summary
    |> Map.get(:participants, [])
    |> Enum.map(&participant_nick/1)
    |> Enum.reject(&is_nil/1)
  end

  defp participant_nick(%{nickname: nickname}) when is_binary(nickname), do: nickname
  defp participant_nick(%{"nickname" => nickname}) when is_binary(nickname), do: nickname
  defp participant_nick(_participant), do: nil

  # A private space is a pair of nicknames rather than a channel, and neither
  # half of it is a channel name to withhold.
  defp space_channel_name(space_id) do
    case VirtualSpace.space_kind(space_id) do
      :channel -> nameable(space_id)
      _other -> nil
    end
  end

  defp nameable(channel_name) when is_binary(channel_name) do
    if Visibility.nameable?(channel_name), do: channel_name
  end

  defp nameable(_channel_name), do: nil
end
