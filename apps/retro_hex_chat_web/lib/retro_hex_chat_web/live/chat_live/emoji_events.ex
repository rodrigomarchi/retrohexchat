defmodule RetroHexChatWeb.ChatLive.EmojiEvents do
  @moduledoc """
  Handles the emoji-picker events on the chat LiveView: `toggle_emoji_picker`,
  `emoji_category`, `emoji_search` and `emoji_select`.

  The parent holds `show_emoji_picker` because the picker is toggled by triggers
  outside the component — the formatting toolbar and the `EmojiPickerHook`
  (click-outside/Escape), both pushing `toggle_emoji_picker` — and selecting an
  emoji closes it while pushing `insert_emoji` to the composer. The picker's
  content (search/category and the category grid) is owned by
  `Components.EmojiPickerDialog`; `emoji_category` and `emoji_search` forward to
  it via `send_update`.

  Attached as `attach_hook(:emoji_events, :handle_event, ...)` in ChatLive.mount/3.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3, send_update: 2]

  alias RetroHexChatWeb.ChatLive.Components.EmojiPickerDialog

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:halt, Phoenix.LiveView.Socket.t()} | {:cont, Phoenix.LiveView.Socket.t()}

  def handle_event("toggle_emoji_picker", _params, socket) do
    visible = !socket.assigns.show_emoji_picker
    if visible, do: send_update(EmojiPickerDialog, id: EmojiPickerDialog.id(), action: :open)
    {:halt, assign(socket, show_emoji_picker: visible)}
  end

  def handle_event("emoji_category", %{"category" => category}, socket) do
    send_update(EmojiPickerDialog, id: EmojiPickerDialog.id(), action: {:category, category})
    {:halt, socket}
  end

  def handle_event("emoji_search", %{"emoji_search" => query}, socket), do: search(query, socket)
  def handle_event("emoji_search", %{"value" => query}, socket), do: search(query, socket)

  def handle_event("emoji_select", %{"emoji" => char}, socket) do
    {:halt,
     socket
     |> push_event("insert_emoji", %{char: char})
     |> assign(show_emoji_picker: false)}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}

  defp search(query, socket) do
    send_update(EmojiPickerDialog, id: EmojiPickerDialog.id(), action: {:search, query})
    {:halt, socket}
  end
end
