defmodule RetroHexChatWeb.Components.CheatsheetDialog do
  @moduledoc """
  Retro-style keyboard shortcut cheatsheet dialog.

  Displays all shortcuts organized by category (Navigation, Chat, Formatting,
  System) with a table showing Action and Binding columns. Read-only.
  """
  use Phoenix.Component

  alias RetroHexChat.Chat.KeyBindings
  alias RetroHexChatWeb.Icons

  attr :visible, :boolean, default: false

  @spec cheatsheet_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def cheatsheet_dialog(assigns) do
    assigns = assign(assigns, :categories, KeyBindings.categories(KeyBindings.defaults()))

    ~H"""
    <div
      :if={@visible}
      class="dialog-overlay"
      phx-click="close_dialog"
      phx-value-dialog="cheatsheet"
    >
      <div
        class="window cheatsheet-dialog dialog-window--cheatsheet"
        data-testid="cheatsheet-dialog"
        phx-click-away="close_dialog"
        phx-value-dialog="cheatsheet"
      >
        <div class="title-bar">
          <Icons.icon_dialog_cheatsheet class="title-bar-icon" />
          <div class="title-bar-text">Keyboard Shortcuts</div>
          <div class="title-bar-controls">
            <button
              aria-label="Close"
              phx-click="close_dialog"
              phx-value-dialog="cheatsheet"
            >
            </button>
          </div>
        </div>
        <div class="window-body dialog-body--p8 u-overflow-y-auto cheatsheet-body">
          <div :for={{category, entries} <- @categories} class="u-mb-12">
            <h4
              class="cheatsheet-category-heading"
              data-testid={"cheatsheet-category-#{category}"}
            >
              {KeyBindings.category_label(category)}
            </h4>
            <table class="cheatsheet-table">
              <tbody>
                <tr :for={entry <- entries}>
                  <td>{entry.label}</td>
                  <td class="u-text-muted u-text-right">
                    {format_binding(entry.binding)}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
          <p class="u-text-xs u-text-muted u-mt-8">
            All shortcuts use Ctrl+Shift combinations
          </p>
        </div>
      </div>
    </div>
    """
  end

  defp format_binding(nil), do: "—"
  defp format_binding(binding), do: KeyBindings.to_display_string(binding)
end
