defmodule RetroHexChat.Games.Seats do
  @moduledoc """
  An open seat at a game, offered to a channel.

  `/lfg` in a game's channel opens a match with one empty seat — the same open
  lobby a match link has always been — and mints the link its card is drawn
  from. The lobby remembers the channel it was offered in, and tells that
  channel when the seat is taken or expires, so the card everybody there is
  looking at changes with it.
  """

  alias RetroHexChat.Lobby
  alias RetroHexChat.ShareLinks
  alias RetroHexChat.ShareLinks.Schema.Link

  @doc """
  Open a seat at `game_id` for whoever in `channel` takes it first.

  A seat this person already has open for the same game in the same channel
  is the answer to a second offer: the room gets one card per seat, and two
  open seats would be a race between two matches nobody asked for.
  """
  @spec open(%{id: integer(), nickname: String.t()}, String.t(), String.t()) ::
          {:ok, Link.t()} | {:error, term()}
  def open(%{id: user_id} = player, game_id, channel) do
    metadata = %{"game_id" => game_id, "channel" => channel}

    case Lobby.find_open_session(user_id, metadata) do
      nil ->
        with {:ok, %{token: token}} <- Lobby.create_open_session(user_id, metadata: metadata) do
          mint(player, game_id, token)
        end

      %{token: token} ->
        case ShareLinks.find_open_for_target("play", target(game_id, token)) do
          nil -> mint(player, game_id, token)
          link -> {:ok, link}
        end
    end
  end

  defp mint(%{id: user_id, nickname: nickname}, game_id, token) do
    ShareLinks.create(%{
      kind: "play",
      target: target(game_id, token),
      creator_id: user_id,
      creator_nick: nickname
    })
  end

  defp target(game_id, token), do: %{"game_id" => game_id, "session_token" => token}
end
