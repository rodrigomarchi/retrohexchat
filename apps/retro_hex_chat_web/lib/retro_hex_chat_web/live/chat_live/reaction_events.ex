defmodule RetroHexChatWeb.ChatLive.ReactionEvents do
  @moduledoc """
  Putting an emoji on somebody else's line, and taking it off again.

  One click, one round trip, no optimism. A reaction that appeared and then
  vanished because the server refused it is worse than half a second of
  waiting, and the stream already knows how to replace a row with the server's
  version — which is what arrives, for this reader and everyone else, as
  `reaction_changed`.

  The picker is the same one the composer uses. What decides where an emoji
  goes is `reaction_target_id`: set while the picker was opened from a
  message's context menu, cleared the moment it is used or the picker closes,
  so the next emoji typed into a message does not land on an old line.

  Attached as an `attach_hook(:reaction_events, :handle_event, ...)` in
  ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [send_update: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.ChatLive.Helpers, only: [system_message: 1]

  alias RetroHexChat.Chat.Service
  alias RetroHexChatWeb.ChatLive.Components.EmojiPickerDialog
  alias RetroHexChatWeb.ChatLive.Components.MessageViewport

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:halt, Phoenix.LiveView.Socket.t()} | {:cont, Phoenix.LiveView.Socket.t()}

  def handle_event("toggle_reaction", %{"message_id" => message_id, "emoji" => emoji}, socket) do
    {:halt, react(socket, message_id, emoji)}
  end

  # The long-press road: on a phone there is no hover, so the entry into the
  # picker is the menu that long-press already opens.
  def handle_event("ctx_chat_react", %{"message_id" => message_id}, socket) do
    send_update(EmojiPickerDialog, id: EmojiPickerDialog.id(), action: :open)

    {:halt, assign(socket, reaction_target_id: message_id, show_emoji_picker: true)}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}

  @doc """
  React with the emoji just picked, if the picker was opened from a message.

  Lives here rather than in `EmojiEvents` because it is about reactions; what
  `EmojiEvents` keeps is the one question it can answer on its own — whether
  anything is waiting for this emoji.
  """
  @spec from_picker(Phoenix.LiveView.Socket.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  def from_picker(socket, emoji) do
    socket
    |> react(socket.assigns.reaction_target_id, emoji)
    |> assign(reaction_target_id: nil)
  end

  @spec react(Phoenix.LiveView.Socket.t(), term(), String.t()) :: Phoenix.LiveView.Socket.t()
  defp react(socket, nil, _emoji), do: socket

  defp react(socket, message_id, emoji) do
    session = socket.assigns.session

    result =
      if session.active_pm do
        Service.toggle_private_reaction(message_id, session.nickname, emoji)
      else
        Service.toggle_reaction(message_id, session.nickname, emoji)
      end

    case result do
      {:ok, _state} ->
        socket

      {:error, reason} ->
        MessageViewport.insert(socket, system_message(reason))
    end
  end
end
