defmodule RetroHexChatWeb.Components.HighlightDialog do
  @moduledoc """
  Highlight Words configuration dialog (Alt+H).
  Shows the user's own nick (non-removable) and custom highlight words
  with optional per-word color from the 16-color IRC palette.
  """
  use Phoenix.Component

  alias RetroHexChat.Accounts.NickColors

  attr :visible, :boolean, default: false
  attr :highlight_entries, :list, default: []
  attr :highlight_selected, :string, default: nil
  attr :own_nick, :string, required: true
  attr :show_highlight_add_dialog, :boolean, default: false
  attr :show_highlight_edit_dialog, :boolean, default: false

  @spec highlight_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def highlight_dialog(assigns) do
    selected_color =
      case Enum.find(assigns.highlight_entries, &(&1.word == assigns.highlight_selected)) do
        nil -> nil
        entry -> entry.bg_color
      end

    assigns = assign(assigns, :selected_color, selected_color)

    ~H"""
    <div
      :if={@visible}
      class="dialog-overlay"
      data-testid="highlight-dialog"
      style="position: fixed; inset: 0; display: flex; align-items: center; justify-content: center; z-index: 200; background: rgba(0,0,0,0.3);"
    >
      <div class="window" style="width: 400px; min-height: 300px;">
        <div class="title-bar">
          <div class="title-bar-text">Highlight Words</div>
          <div class="title-bar-controls">
            <button
              aria-label="Close"
              data-testid="highlight-dialog-close"
              phx-click="close_highlight_dialog"
            >
            </button>
          </div>
        </div>
        <div class="window-body" style="padding: 8px;">
          <fieldset>
            <legend>Own Nickname (always highlighted)</legend>
            <div
              class="highlight-entry highlight-entry--own"
              data-testid="highlight-own-nick"
              style="padding: 4px; display: flex; align-items: center; gap: 8px;"
            >
              <span
                class="highlight-color-swatch"
                style={"background-color: #{default_color()}; width: 16px; height: 16px; display: inline-block; border: 1px solid #808080;"}
              >
              </span>
              <span>{@own_nick}</span>
              <span style="color: #808080; margin-left: auto;">(default)</span>
            </div>
          </fieldset>

          <fieldset style="margin-top: 8px;">
            <legend>Custom Words</legend>
            <div
              class="highlight-word-list"
              data-testid="highlight-word-list"
              style="min-height: 100px; max-height: 200px; overflow-y: auto; border: 1px inset; background: white; padding: 2px;"
            >
              <div
                :for={entry <- @highlight_entries}
                class={"highlight-entry" <> if(entry.word == @highlight_selected, do: " highlight-entry--selected", else: "")}
                data-testid={"highlight-word-#{entry.word}"}
                phx-click="highlight_select"
                phx-value-word={entry.word}
                style={"padding: 2px 4px; cursor: pointer; display: flex; align-items: center; gap: 8px;" <> if(entry.word == @highlight_selected, do: " background: #000080; color: white;", else: "")}
              >
                <span
                  class="highlight-color-swatch"
                  style={color_swatch_style(entry.bg_color)}
                >
                </span>
                <span>{entry.word}</span>
              </div>
              <div
                :if={@highlight_entries == []}
                style="color: #808080; padding: 8px; text-align: center;"
              >
                No custom highlight words configured.
              </div>
            </div>
            <div style="margin-top: 8px; display: flex; gap: 4px;">
              <button
                type="button"
                data-testid="highlight-add-btn"
                phx-click="open_highlight_add_dialog"
              >
                Add...
              </button>
              <button
                type="button"
                data-testid="highlight-edit-btn"
                phx-click="open_highlight_edit_dialog"
                disabled={@highlight_selected == nil}
              >
                Edit...
              </button>
              <button
                type="button"
                data-testid="highlight-remove-btn"
                phx-click="highlight_remove"
                phx-value-word={@highlight_selected || ""}
                disabled={@highlight_selected == nil}
              >
                Remove
              </button>
            </div>
          </fieldset>
        </div>
      </div>

      <%= if @show_highlight_add_dialog do %>
        <div
          class="dialog-overlay"
          data-testid="highlight-add-dialog"
          style="position: fixed; inset: 0; display: flex; align-items: center; justify-content: center; z-index: 210; background: rgba(0,0,0,0.2);"
        >
          <div class="window" style="width: 300px;">
            <div class="title-bar">
              <div class="title-bar-text">Add Highlight Word</div>
            </div>
            <div class="window-body" style="padding: 8px;">
              <form phx-submit="highlight_add">
                <div class="field-row-stacked">
                  <label for="highlight-word-input">Word:</label>
                  <input
                    type="text"
                    id="highlight-word-input"
                    name="word"
                    data-testid="highlight-word-input"
                    maxlength="50"
                    required
                    autofocus
                  />
                </div>
                <div class="field-row-stacked" style="margin-top: 8px;">
                  <label>Background Color (optional):</label>
                  {color_picker_grid(assigns)}
                </div>
                <div class="field-row" style="margin-top: 12px; justify-content: flex-end; gap: 4px;">
                  <button type="submit" data-testid="highlight-add-submit">Add</button>
                  <button
                    type="button"
                    data-testid="highlight-add-cancel"
                    phx-click="close_highlight_add_dialog"
                  >
                    Cancel
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      <% end %>

      <%= if @show_highlight_edit_dialog do %>
        <div
          class="dialog-overlay"
          data-testid="highlight-edit-dialog"
          style="position: fixed; inset: 0; display: flex; align-items: center; justify-content: center; z-index: 210; background: rgba(0,0,0,0.2);"
        >
          <div class="window" style="width: 300px;">
            <div class="title-bar">
              <div class="title-bar-text">Edit Highlight: {@highlight_selected}</div>
            </div>
            <div class="window-body" style="padding: 8px;">
              <form phx-submit="highlight_edit">
                <input type="hidden" name="word" value={@highlight_selected} />
                <div class="field-row-stacked">
                  <label>Background Color:</label>
                  {color_picker_grid(assigns)}
                </div>
                <div class="field-row" style="margin-top: 12px; justify-content: flex-end; gap: 4px;">
                  <button type="submit" data-testid="highlight-edit-submit">OK</button>
                  <button
                    type="button"
                    data-testid="highlight-edit-cancel"
                    phx-click="close_highlight_edit_dialog"
                  >
                    Cancel
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp color_picker_grid(assigns) do
    colors =
      for i <- 0..15 do
        {i, NickColors.hex_for_index(i)}
      end

    assigns = assign(assigns, :colors, colors)

    ~H"""
    <div
      style="display: grid; grid-template-columns: repeat(8, 24px); gap: 2px; margin-top: 4px;"
      data-testid="highlight-color-grid"
    >
      <button
        :for={{idx, hex} <- @colors}
        type="button"
        class="color-swatch-btn"
        style={"width: 24px; height: 24px; background-color: #{hex}; border: 2px solid #808080; cursor: pointer; padding: 0;"}
        phx-click="highlight_color_pick"
        phx-value-color={to_string(idx)}
        data-testid={"highlight-color-#{idx}"}
      >
      </button>
      <button
        type="button"
        class="color-swatch-btn"
        style="width: 24px; height: 24px; background: repeating-conic-gradient(#ccc 0% 25%, #fff 0% 50%) 50% / 12px 12px; border: 2px solid #808080; cursor: pointer; padding: 0;"
        phx-click="highlight_color_pick"
        phx-value-color=""
        data-testid="highlight-color-none"
        title="No color (use default)"
      >
      </button>
    </div>
    <input type="hidden" name="bg_color" value={@selected_color || ""} />
    """
  end

  defp default_color, do: "#3a3500"

  defp color_swatch_style(nil) do
    "background-color: #{default_color()}; width: 16px; height: 16px; display: inline-block; border: 1px solid #808080;"
  end

  defp color_swatch_style(color_index) do
    hex = NickColors.hex_for_index(color_index) || default_color()

    "background-color: #{hex}; width: 16px; height: 16px; display: inline-block; border: 1px solid #808080;"
  end
end
