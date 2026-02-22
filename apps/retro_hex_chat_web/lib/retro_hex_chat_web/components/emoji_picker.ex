defmodule RetroHexChatWeb.Components.EmojiPicker do
  @moduledoc """
  Emoji picker popup with category tabs, search, and scrollable grid.
  Retro-styled, positioned above the chat input area.
  """
  use Phoenix.Component

  attr :visible, :boolean, default: false
  attr :categories, :list, required: true
  attr :active_category, :string, required: true
  attr :emojis, :list, required: true
  attr :search_query, :string, default: ""

  @spec emoji_picker(map()) :: Phoenix.LiveView.Rendered.t()
  def emoji_picker(assigns) do
    ~H"""
    <div
      :if={@visible}
      class="emoji-picker window"
      data-testid="emoji-picker"
      id="emoji-picker"
      phx-hook="EmojiPickerHook"
    >
      <div class="title-bar">
        <div class="title-bar-text">Emoji</div>
        <div class="title-bar-controls">
          <button aria-label="Close" phx-click="toggle_emoji_picker"></button>
        </div>
      </div>
      <div class="window-body emoji-picker-body">
        <div class="emoji-search-row">
          <input
            type="text"
            class="emoji-search"
            data-testid="emoji-search"
            placeholder="Search emoji..."
            value={@search_query}
            phx-keyup="emoji_search"
            phx-key=""
          />
        </div>
        <div :if={@search_query == ""} class="emoji-category-tabs">
          <button
            :for={cat <- @categories}
            type="button"
            class={"emoji-category-tab #{if cat == @active_category, do: "active"}"}
            phx-click="emoji_category"
            phx-value-category={cat}
            title={cat}
          >
            {category_icon(cat)}
          </button>
        </div>
        <div class="emoji-grid" data-testid="emoji-grid">
          <button
            :for={emoji <- @emojis}
            type="button"
            class="emoji-btn"
            data-emoji={emoji.char}
            phx-click="emoji_select"
            phx-value-emoji={emoji.char}
            title={emoji.name}
          >
            {emoji.char}
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp category_icon("Smileys & Emotion"), do: "\u{1F600}"
  defp category_icon("People & Body"), do: "\u{1F44D}"
  defp category_icon("Animals & Nature"), do: "\u{1F436}"
  defp category_icon("Food & Drink"), do: "\u{1F354}"
  defp category_icon("Travel & Places"), do: "\u{2708}\u{FE0F}"
  defp category_icon("Activities"), do: "\u{26BD}"
  defp category_icon("Objects"), do: "\u{1F4BB}"
  defp category_icon("Symbols"), do: "\u{2705}"
  defp category_icon(_), do: "\u{2753}"
end
