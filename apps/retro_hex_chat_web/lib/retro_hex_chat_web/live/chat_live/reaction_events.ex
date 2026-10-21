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

  # A pick names the kind of conversation its line came from. A line in the
  # thread window can be from another conversation than the active one, and a
  # channel line and a private line can share a number.
  def handle_event(
        "toggle_reaction",
        %{"message_id" => message_id, "emoji" => emoji} = params,
        socket
      ) do
    {:halt, react(socket, message_id, emoji, source(params["source"], socket))}
  end

  # The road to every emoji beyond the quick picks: the message's context menu,
  # which a right-click opens on a computer and a long press on a phone.
  def handle_event("ctx_chat_react", %{"message_id" => message_id}, socket) do
    send_update(EmojiPickerDialog, id: EmojiPickerDialog.id(), action: :open)

    # The menu opens on the conversation on screen; its kind is taken now, so a
    # switch while the picker is open does not file the pick under another one.
    {:halt,
     assign(socket,
       reaction_target_id: message_id,
       reaction_target_source: source(nil, socket),
       show_emoji_picker: true
     )}
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
    |> react(
      socket.assigns.reaction_target_id,
      emoji,
      socket.assigns[:reaction_target_source] || source(nil, socket)
    )
    |> assign(reaction_target_id: nil)
  end

  @spec react(Phoenix.LiveView.Socket.t(), term(), String.t(), :channel | :private) ::
          Phoenix.LiveView.Socket.t()
  defp react(socket, nil, _emoji, _source), do: socket

  defp react(socket, message_id, emoji, source) do
    nickname = socket.assigns.session.nickname

    result =
      case parse_id(message_id) do
        nil -> {:error, dgettext("chat", "Message not found.")}
        id -> toggle(source, id, nickname, emoji)
      end

    case result do
      {:ok, _state} ->
        socket

      {:error, reason} ->
        MessageViewport.insert(socket, system_message(reason))
    end
  end

  defp toggle(:private, id, nickname, emoji),
    do: Service.toggle_private_reaction(id, nickname, emoji)

  defp toggle(:channel, id, nickname, emoji), do: Service.toggle_reaction(id, nickname, emoji)

  # A line that did not say where it came from is in the conversation on screen.
  @spec source(String.t() | nil, Phoenix.LiveView.Socket.t()) :: :channel | :private
  defp source("private", _socket), do: :private
  defp source("channel", _socket), do: :channel

  defp source(_given, socket),
    do: if(socket.assigns.session.active_pm, do: :private, else: :channel)

  # The id arrives from the page, where a row still being sent carries a
  # placeholder ("pending_3") the database cannot cast.
  @spec parse_id(term()) :: integer() | nil
  defp parse_id(id) when is_integer(id), do: id

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp parse_id(_id), do: nil
end
