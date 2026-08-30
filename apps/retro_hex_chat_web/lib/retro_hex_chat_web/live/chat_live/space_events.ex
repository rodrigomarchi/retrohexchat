defmodule RetroHexChatWeb.ChatLive.SpaceEvents do
  @moduledoc """
  What the space surface reports to the chat that hosts it.

  Two things, and each is here because it belongs to the chat and not to the
  space:

    * **the character you picked.** The surface is mounted afresh every time the
      Space tab is opened, so a memory kept inside it would last exactly one
      visit. The chat outlives every visit, which is why the picker can promise
      to default to your last choice.
    * **a character you hovered or right-clicked on the map.** Both mean a hover
      card and a nick menu, and both of those read a chat session and draw over
      the conversation. The canvas reports to whichever LiveView owns its
      element, which is the space; what the report *means* is the chat's, so it
      is handed on.

  Attached as `attach_hook(:space_info, :handle_info, ...)` in `ChatLive.mount/3`.
  """

  import Phoenix.Component, only: [assign: 2]

  alias Phoenix.LiveView.Socket
  alias RetroHexChatWeb.ChatLive.ContextMenuEvents
  alias RetroHexChatWeb.ChatLive.HoverEvents

  @spec handle_info(term(), Socket.t()) :: {:cont | :halt, Socket.t()}
  def handle_info({:space_surface_avatar, avatar}, socket) when is_binary(avatar) do
    {:halt, assign(socket, space_last_avatar: avatar)}
  end

  # Named rather than forwarded blind: these three are the whole of what the
  # canvas can say to the chat, and a clause that passed anything through would
  # let the space reach every handler the chat has.
  def handle_info({:space_surface_event, event, params}, socket)
      when event in ~w(nick_hover nick_hover_dismiss nick_right_click) do
    {:halt, dispatch(event, params, socket)}
  end

  def handle_info(_message, socket), do: {:cont, socket}

  defp dispatch(event, params, socket) do
    case HoverEvents.handle_event(event, params, socket) do
      {:halt, socket} ->
        socket

      {:cont, socket} ->
        {_result, socket} = ContextMenuEvents.handle_event(event, params, socket)
        socket
    end
  end
end
