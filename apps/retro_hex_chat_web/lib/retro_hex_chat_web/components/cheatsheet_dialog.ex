defmodule RetroHexChatWeb.Components.CheatsheetDialog do
  @moduledoc """
  Windows 98-style keyboard shortcut cheatsheet dialog.

  Displays all shortcuts organized by category (Navigation, Chat, Formatting,
  System) with a table showing Action and Binding columns. Read-only.
  """
  use Phoenix.Component

  alias RetroHexChat.Chat.KeyBindings

  attr :visible, :boolean, default: false
  attr :bindings, :map, required: true

  @spec cheatsheet_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def cheatsheet_dialog(assigns) do
    assigns = assign(assigns, :categories, KeyBindings.categories(assigns.bindings))

    ~H"""
    <div
      :if={@visible}
      class="dialog-overlay"
      phx-click="close_dialog"
      phx-value-dialog="cheatsheet"
    >
      <div
        class="window cheatsheet-dialog"
        data-testid="cheatsheet-dialog"
        phx-click-away="close_dialog"
        phx-value-dialog="cheatsheet"
        style="width: 460px;"
      >
        <div class="title-bar">
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
        <div class="window-body" style="padding: 8px; max-height: 400px; overflow-y: auto;">
          <div :for={{category, entries} <- @categories} style="margin-bottom: 12px;">
            <h4
              style="margin: 0 0 4px 0; font-size: 12px; border-bottom: 1px solid #808080; padding-bottom: 2px;"
              data-testid={"cheatsheet-category-#{category}"}
            >
              {KeyBindings.category_label(category)}
            </h4>
            <table style="width: 100%; font-size: 11px; border-collapse: collapse;">
              <tbody>
                <tr :for={entry <- entries} style="border-bottom: 1px solid #dfdfdf;">
                  <td style="padding: 2px 4px;">{entry.label}</td>
                  <td style="padding: 2px 4px; text-align: right; color: #808080;">
                    {format_binding(entry.binding)}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
          <p style="font-size: 10px; color: #808080; margin: 8px 0 0 0;">
            Customize shortcuts in Options &gt; Key Bindings
          </p>
        </div>
      </div>
    </div>
    """
  end

  defp format_binding(nil), do: "—"
  defp format_binding(binding), do: KeyBindings.to_display_string(binding)
end
