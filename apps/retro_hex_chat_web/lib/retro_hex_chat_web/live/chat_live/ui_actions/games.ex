defmodule RetroHexChatWeb.ChatLive.UiActions.Games do
  @moduledoc """
  What the game commands ask the chat to do.

  `/lfg` opens a seat at the channel's game and puts its card in the channel,
  through the same door every room's card goes through: a second `/lfg` while
  your card is still the newest line brings nothing new, it points at the one
  that is there.
  """

  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.ChatLive.Helpers, only: [error_event: 2, system_event: 2]

  alias RetroHexChat.Games.Catalog
  alias RetroHexChat.Games.Seats
  alias RetroHexChatWeb.App.SessionHelpers
  alias RetroHexChatWeb.ChatLive.Helpers.CardDoor
  alias RetroHexChatWeb.ShareLinkRef

  @spec handle_ui_action(Phoenix.LiveView.Socket.t(), atom(), map()) ::
          Phoenix.LiveView.Socket.t()
  def handle_ui_action(socket, :game_lfg, %{channel: channel, game_id: game_id}) do
    nickname = socket.assigns.session.nickname

    with {:ok, user_id} <- SessionHelpers.resolve_user_id(nickname),
         {:ok, link} <- Seats.open(%{id: user_id, nickname: nickname}, game_id, channel) do
      line =
        dgettext("games", "%{nickname} is looking for a partner in %{game} — %{url}",
          nickname: nickname,
          game: Catalog.game_name(game_id),
          url: ShareLinkRef.url(link.slug)
        )

      case CardDoor.deliver({:channel, channel}, "/join/" <> link.slug, line) do
        :posted -> socket
        :already_there -> system_event(socket, dgettext("games", "Your seat is the line below."))
      end
    else
      {:error, message} when is_binary(message) -> error_event(socket, message)
      _refused -> error_event(socket, dgettext("games", "You cannot open a seat right now."))
    end
  end
end
