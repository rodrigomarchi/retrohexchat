defmodule RetroHexChatWeb.ChatLive.Components.EmojiPickerDialog do
  @moduledoc """
  The emoji picker popover: category tabs, a search box, and a grid of emoji.

  Owns the picker's content state — the `search` term and the active `category` —
  and builds the full category set once in `mount/1`, so the grid is not recomputed
  on unrelated chat renders. While a search term is present it shows matching emoji
  instead of the active category.

  `visible` is supplied by the parent, which holds the open/close flag because the
  picker is toggled from outside the component: the formatting-toolbar button and
  the `EmojiPickerHook` (click-outside and Escape) both push `toggle_emoji_picker`
  to the root LiveView, and selecting an emoji closes the picker there while
  pushing `insert_emoji` to the composer. `emoji_category` and `emoji_search` are
  received by `EmojiEvents` and forwarded here via `send_update`.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.EmojiPicker

  alias RetroHexChat.Chat.EmojiData

  @id "emoji-picker"
  @default_category "Smileys & Emotion"

  @doc "Stable DOM/component id."
  @spec id() :: String.t()
  def id, do: @id

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    categories_all =
      Enum.map(EmojiData.categories(), fn cat -> {cat, EmojiData.by_category(cat)} end)

    {:ok,
     assign(socket,
       id: @id,
       visible: false,
       search: "",
       category: @default_category,
       categories_all: categories_all
     )}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{action: :open}, socket) do
    {:ok, assign(socket, search: "")}
  end

  def update(%{action: {:category, category}}, socket) do
    {:ok, assign(socket, category: category, search: "")}
  end

  def update(%{action: {:search, query}}, socket) do
    {:ok, assign(socket, search: query)}
  end

  def update(assigns, socket) do
    {:ok,
     assign(socket,
       id: Map.get(assigns, :id, socket.assigns.id),
       visible: Map.get(assigns, :visible, socket.assigns.visible)
     )}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    {categories, active_category} =
      if assigns.search == "" do
        {assigns.categories_all, assigns.category}
      else
        {[{"search_results", EmojiData.search(assigns.search)}], "search_results"}
      end

    assigns = assign(assigns, categories: categories, active_category: active_category)

    ~H"""
    <div id={"#{@id}-mount"}>
      <.emoji_picker
        :if={@visible}
        id={@id}
        visible={@visible}
        search={@search}
        active_category={@active_category}
        categories={@categories}
        on_select="emoji_select"
        on_category="emoji_category"
        on_search="emoji_search"
        on_close="toggle_emoji_picker"
      />
    </div>
    """
  end
end
