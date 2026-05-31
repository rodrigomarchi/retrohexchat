defmodule RetroHexChatWeb.Components.UI.CheatsheetDialog do
  @moduledoc """
  Keyboard shortcuts cheatsheet dialog for the showcase design system.

  Composed from dialog + button + table primitives.
  Displays grouped keyboard shortcut bindings in a table format.

  ## Usage

      <.cheatsheet_dialog
        id="cheatsheet"
        show={true}
        bindings={[
          %{
            category: "Navigation",
            items: [
              %{action: "Focus input", keys: "Alt+I", description: "Jump to chat input"},
              %{action: "Next tab", keys: "Ctrl+Tab", description: "Switch to next tab"}
            ]
          }
        ]}
        on_close="close_cheatsheet"
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Table

  alias RetroHexChatWeb.Icons

  @doc "Renders the keyboard shortcuts cheatsheet dialog."
  attr :id, :string, required: true
  attr :show, :boolean, default: false

  attr :bindings, :list,
    default: [],
    doc: "List of binding groups, each a map with :category and :items"

  attr :on_close, :any, default: nil, doc: "JS command or event name for close"

  @spec cheatsheet_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def cheatsheet_dialog(assigns) do
    ~H"""
    <.dialog id={@id} show={@show} class="max-w-xl">
      <.dialog_header id={@id} title={gettext("Keyboard Shortcuts")}>
        <:icon><Icons.icon_dialog_cheatsheet class="w-4 h-4" /></:icon>
      </.dialog_header>

      <.dialog_body class="max-h-96 overflow-y-auto">
        <div data-testid="cheatsheet-dialog">
          <div :if={@bindings == []} class="text-xs text-muted-foreground italic">
            {gettext("No shortcuts defined.")}
          </div>

          <div :for={group <- @bindings} class="mb-retro-8 last:mb-0">
            <h3 class="text-xs font-bold mb-retro-4 px-1 bg-title-bar text-white">
              {group.category}
            </h3>
            <.table>
              <.table_header>
                <.table_row>
                  <.table_head class="text-xs w-1/3">{gettext("Action")}</.table_head>
                  <.table_head class="text-xs w-1/4">{gettext("Keys")}</.table_head>
                  <.table_head class="text-xs">{gettext("Description")}</.table_head>
                </.table_row>
              </.table_header>
              <.table_body>
                <.table_row :for={item <- group.items}>
                  <.table_cell class="text-xs font-medium py-1 px-2">
                    {item.action}
                  </.table_cell>
                  <.table_cell class="text-xs py-1 px-2">
                    <kbd class="shadow-retro-raised bg-surface px-1 font-mono text-xs">
                      {item.keys}
                    </kbd>
                  </.table_cell>
                  <.table_cell class="text-xs py-1 px-2 text-muted-foreground">
                    {item.description}
                  </.table_cell>
                </.table_row>
              </.table_body>
            </.table>
          </div>
        </div>
      </.dialog_body>

      <.dialog_footer>
        <.button
          variant="default"
          phx-click={@on_close || hide_modal(@id)}
          data-testid="cheatsheet-dialog-close"
        >
          <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
          {gettext("Close")}
        </.button>
      </.dialog_footer>
    </.dialog>
    """
  end
end
