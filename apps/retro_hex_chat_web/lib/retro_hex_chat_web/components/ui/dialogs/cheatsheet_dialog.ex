defmodule RetroHexChatWeb.Components.UI.CheatsheetDialog do
  @moduledoc """
  Keyboard shortcuts cheatsheet dialog for the showcase design system.

  Displays grouped keyboard shortcut bindings as a compact responsive list.

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
      class="cs-panel retro-scrollbar"
    >
      <div :if={@bindings == []} class="cs-empty-state">
        {dgettext("dialogs", "No shortcuts defined.")}
      </div>

      <section
        :for={{group, group_index} <- Enum.with_index(@bindings)}
        class="cs-group"
        data-testid={"cheatsheet-group-#{group_index}"}
      >
        <h3 class="cs-group-title">
          {group.category}
        </h3>
        <div class="cs-shortcut-list" role="list">
          <article
            :for={{item, item_index} <- Enum.with_index(group.items)}
            class="cs-shortcut-entry"
            data-testid={"cheatsheet-shortcut-#{group_index}-#{item_index}"}
            role="listitem"
          >
            <div class="cs-shortcut-main">
              <span class="cs-shortcut-action">
                {item.action}
              </span>
              <kbd class="cs-shortcut-key">
                {item.keys}
              </kbd>
            </div>
            <p class="cs-shortcut-description">
              {item.description}
            </p>
          </article>
        </div>
      </section>
    </div>
    """
  end
end
