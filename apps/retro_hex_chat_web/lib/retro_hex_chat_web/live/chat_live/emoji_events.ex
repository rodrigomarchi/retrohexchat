defmodule RetroHexChatWeb.ChatLive.EmojiEvents do
  @moduledoc """
  Handle events for the emoji picker.

  Covers: toggle_emoji_picker, emoji_category, emoji_search, emoji_select.

  Attached as `attach_hook(:emoji_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3]

  alias RetroHexChat.Chat.EmojiData

  def handle_event("toggle_emoji_picker", _params, socket) do
    visible = !socket.assigns.show_emoji_picker

    socket =
      if visible do
        assign(socket,
          show_emoji_picker: true,
          emoji_search: "",
          emoji_emojis: EmojiData.by_category(socket.assigns.emoji_category)
        )
      else
        assign(socket, show_emoji_picker: false)
      end

    {:halt, socket}
  end

  def handle_event("emoji_category", %{"category" => category}, socket) do
    {:halt,
     assign(socket,
       emoji_category: category,
       emoji_emojis: EmojiData.by_category(category),
       emoji_search: ""
     )}
  end

  def handle_event("emoji_search", %{"value" => query}, socket) do
    emojis =
      if query == "" do
        EmojiData.by_category(socket.assigns.emoji_category)
      else
        EmojiData.search(query)
      end

    {:halt, assign(socket, emoji_search: query, emoji_emojis: emojis)}
  end

  def handle_event("emoji_select", %{"emoji" => char}, socket) do
    socket =
      socket
      |> push_event("insert_emoji", %{char: char})
      |> assign(show_emoji_picker: false)

    {:halt, socket}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}
end
