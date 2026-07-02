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

  import RetroHexChatWeb.Components.UI.Table

  @doc "Renders the keyboard shortcuts cheatsheet dialog."
  attr :id, :string, required: true

  attr :bindings, :list,
    default: [],
    doc: "List of binding groups, each a map with :category and :items"

  @spec cheatsheet_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def cheatsheet_panel(assigns) do
    ~H"""
    <div
      id={"#{@id}-content"}
      data-testid="cheatsheet-dialog"
      class="flex-1 min-h-0 overflow-y-auto retro-scrollbar"
    >
      <div :if={@bindings == []} class="text-xs text-muted-foreground italic">
        {dgettext("dialogs", "No shortcuts defined.")}
      </div>

      <div :for={group <- @bindings} class="mb-retro-8 last:mb-0">
        <h3 class="text-xs font-bold mb-retro-4 px-1 bg-title-bar text-white">
          {group.category}
        </h3>
        <.table>
          <.table_header>
            <.table_row>
              <.table_head class="text-xs w-1/3">{dgettext("dialogs", "Action")}</.table_head>
              <.table_head class="text-xs w-1/4">{dgettext("dialogs", "Keys")}</.table_head>
              <.table_head class="text-xs">{dgettext("dialogs", "Description")}</.table_head>
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
    """
  end
end
