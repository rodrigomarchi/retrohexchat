defmodule RetroHexChatWeb.ChatLive.GameEvents do
  @moduledoc """
  A game's channel strip and a game's home, pressed.

  "Find a partner" is `/lfg` and "Invite" is `/challenge`, run through the same
  command pipeline as when they are typed — the buttons are shortcuts to the
  commands, not a second way of opening a seat. Both commands belong to the
  game's channel, so the home's buttons take the reader there first, run the
  command in it and leave them looking at what it did: their seat's card in the
  channel, or the private conversation the invitation went to.

  Attached as `attach_hook(:game_events, :handle_event, ...)` in DesktopLive.
  """

  import Phoenix.LiveView, only: [push_patch: 2]

  alias RetroHexChat.Games.Catalog
  alias RetroHexChatWeb.ChatLive.CommandDispatch
  alias RetroHexChatWeb.ChatLive.Helpers.Channel, as: ChannelHelpers
  alias RetroHexChatWeb.Site.Address

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:halt | :cont, Phoenix.LiveView.Socket.t()}
  def handle_event("game_lfg", _params, socket),
    do: {:halt, CommandDispatch.dispatch_command(socket, socket.assigns.session, "lfg", [])}

  def handle_event("game_home_lfg", %{"game" => game_id}, socket),
    do: {:halt, in_game_channel(socket, game_id, "lfg", mode_args(game_id))}

  def handle_event("game_home_challenge", %{"game" => game_id, "nickname" => nickname}, socket) do
    case String.trim(nickname) do
      "" ->
        {:halt, socket}

      target ->
        {:halt, in_game_channel(socket, game_id, "challenge", [target | mode_args(game_id)])}
    end
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}

  # Joined, or switched to when already in it — the join is what makes it the
  # conversation the command runs in. A channel that refused the reader has
  # said why, and nothing is run.
  defp in_game_channel(socket, game_id, command, args) do
    case Catalog.get_game(game_id) do
      {:ok, _game} ->
        channel = Catalog.channel_name(game_id)
        socket = ChannelHelpers.join_channel(socket, channel, socket.assigns.session)
        run_in(socket, channel, command, args)

      {:error, :not_found} ->
        socket
    end
  end

  # Then to wherever the command left the chat — the channel with the seat's
  # card, or the conversation the invitation went to — out from under the
  # game's home.
  defp run_in(%{assigns: %{session: %{active_channel: channel}}} = socket, channel, command, args) do
    socket = CommandDispatch.dispatch_command(socket, socket.assigns.session, command, args)
    push_patch(socket, to: Address.chat_address(socket.assigns))
  end

  defp run_in(socket, _channel, _command, _args), do: socket

  # A mode is named to the commands by its last word: `hex_raid_blitz` is
  # `/lfg blitz` in #hex-raid.
  defp mode_args(game_id) do
    case String.replace_prefix(game_id, Catalog.base_id(game_id) <> "_", "") do
      ^game_id -> []
      mode -> [mode]
    end
  end
end
