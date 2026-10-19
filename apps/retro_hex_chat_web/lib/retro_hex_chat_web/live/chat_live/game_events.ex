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
  alias RetroHexChatWeb.ChatLive.Helpers.Conversation
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

  # Switched to when the reader is already in it, joined otherwise — the way
  # a click on a channel does it — so the command runs in it. Then out from
  # under the game's home to wherever that left the chat: the channel with the
  # seat's card, the conversation the invitation went to, or the line saying
  # why the channel turned the reader away.
  defp in_game_channel(socket, game_id, command, args) do
    case Catalog.get_game(game_id) do
      {:ok, _game} ->
        channel = Catalog.channel_name(game_id)

        socket
        |> enter(channel)
        |> run_in(channel, command, args)
        |> then(&push_patch(&1, to: Address.chat_address(&1.assigns)))

      {:error, :not_found} ->
        socket
    end
  end

  defp enter(socket, channel) do
    session = socket.assigns.session

    if channel in session.channels,
      do: Conversation.activate_channel(socket, channel),
      else: ChannelHelpers.join_channel(socket, channel, session)
  end

  defp run_in(
         %{assigns: %{session: %{active_channel: channel}}} = socket,
         channel,
         command,
         args
       ),
       do: CommandDispatch.dispatch_command(socket, socket.assigns.session, command, args)

  defp run_in(socket, _channel, _command, _args), do: socket

  defp mode_args(game_id) do
    case Catalog.mode_word(game_id) do
      nil -> []
      word -> [word]
    end
  end
end
