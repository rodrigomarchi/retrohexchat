defmodule RetroHexChatWeb.Components.HighlightDialog do
  @moduledoc """
  Highlight Words configuration dialog (Ctrl+Shift+H).
  Shows the user's own nick (non-removable) and custom highlight words
  with optional per-word color from the 16-color IRC palette.
  """
  use Phoenix.Component

  alias RetroHexChatWeb.Icons

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
    >
      <div class="window dialog-window--md">
        <div class="title-bar">
          <Icons.icon_dialog_highlight class="title-bar-icon" />
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
        <div class="window-body dialog-body--p8">
          <fieldset>
            <legend>Own Nickname (always highlighted)</legend>
            <div
              class="highlight-entry highlight-entry--own form-row--gap-8 u-p-4"
              data-testid="highlight-own-nick"
            >
              <span class="highlight-color-swatch highlight-bg-default"></span>
              <span>{@own_nick}</span>
              <span class="u-text-muted u-ml-auto">(default)</span>
            </div>
          </fieldset>

          <fieldset class="u-mt-8">
            <legend>Custom Words</legend>
            <div
              class="highlight-word-list"
              data-testid="highlight-word-list"
            >
              <div
                :for={entry <- @highlight_entries}
                class={"highlight-entry" <> if(entry.word == @highlight_selected, do: " highlight-entry--selected", else: "")}
                data-testid={"highlight-word-#{entry.word}"}
                phx-click="highlight_select"
                phx-value-word={entry.word}
              >
                <span class={["highlight-color-swatch", swatch_bg_class(entry.bg_color)]}></span>
                <span>{entry.word}</span>
              </div>
              <div
                :if={@highlight_entries == []}
                class="table-empty"
              >
                No custom highlight words configured.
              </div>
            </div>
            <div class="dialog-buttons dialog-buttons--start u-mt-8">
              <button
                type="button"
                class="btn-icon"
                data-testid="highlight-add-btn"
                phx-click="open_highlight_add_dialog"
              >
                <Icons.icon_btn_add class="btn-icon__svg" /> Add...
              </button>
              <button
                type="button"
                class="btn-icon"
                data-testid="highlight-edit-btn"
                phx-click="open_highlight_edit_dialog"
                disabled={@highlight_selected == nil}
              >
                <Icons.icon_btn_edit class="btn-icon__svg" /> Edit...
              </button>
              <button
                type="button"
                class="btn-icon"
                data-testid="highlight-remove-btn"
                phx-click="highlight_remove"
                phx-value-word={@highlight_selected || ""}
                disabled={@highlight_selected == nil}
              >
                <Icons.icon_btn_remove class="btn-icon__svg" /> Remove
              </button>
            </div>
          </fieldset>
        </div>
      </div>

      <%= if @show_highlight_add_dialog do %>
        <div
          class="dialog-overlay dialog-overlay--light dialog-overlay--above"
          data-testid="highlight-add-dialog"
        >
          <div class="window dialog-window--sm">
            <div class="title-bar">
              <Icons.icon_dialog_highlight class="title-bar-icon" />
              <div class="title-bar-text">Add Highlight Word</div>
            </div>
            <div class="window-body dialog-body--p8">
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
                <div class="field-row-stacked u-mt-8">
                  <label>Background Color (optional):</label>
                  {color_picker_grid(assigns)}
                </div>
                <div class="field-row dialog-buttons u-mt-12">
                  <button type="submit" class="btn-icon" data-testid="highlight-add-submit">
                    <Icons.icon_btn_add class="btn-icon__svg" /> Add
                  </button>
                  <button
                    type="button"
                    class="btn-icon"
                    data-testid="highlight-add-cancel"
                    phx-click="close_highlight_add_dialog"
                  >
                    <Icons.icon_btn_cancel class="btn-icon__svg" /> Cancel
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      <% end %>

      <%= if @show_highlight_edit_dialog do %>
        <div
          class="dialog-overlay dialog-overlay--light dialog-overlay--above"
          data-testid="highlight-edit-dialog"
        >
          <div class="window dialog-window--sm">
            <div class="title-bar">
              <Icons.icon_dialog_highlight class="title-bar-icon" />
              <div class="title-bar-text">Edit Highlight: {@highlight_selected}</div>
            </div>
            <div class="window-body dialog-body--p8">
              <form phx-submit="highlight_edit">
                <input type="hidden" name="word" value={@highlight_selected} />
                <div class="field-row-stacked">
                  <label>Background Color:</label>
                  {color_picker_grid(assigns)}
                </div>
                <div class="field-row dialog-buttons u-mt-12">
                  <button type="submit" class="btn-icon" data-testid="highlight-edit-submit">
                    <Icons.icon_btn_ok class="btn-icon__svg" /> OK
                  </button>
                  <button
                    type="button"
                    class="btn-icon"
                    data-testid="highlight-edit-cancel"
                    phx-click="close_highlight_edit_dialog"
                  >
                    <Icons.icon_btn_cancel class="btn-icon__svg" /> Cancel
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
    ~H"""
    <div
      class="highlight-color-grid"
      data-testid="highlight-color-grid"
    >
      <button
        :for={idx <- 0..15}
        type="button"
        class={"highlight-color-btn irc-bg-#{idx}"}
        phx-click="highlight_color_pick"
        phx-value-color={to_string(idx)}
        data-testid={"highlight-color-#{idx}"}
      >
      </button>
      <button
        type="button"
        class="highlight-color-btn highlight-no-color"
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

  defp swatch_bg_class(nil), do: "highlight-bg-default"
  defp swatch_bg_class(color_index), do: "irc-bg-#{color_index}"
end
