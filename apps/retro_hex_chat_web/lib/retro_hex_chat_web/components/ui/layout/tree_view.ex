defmodule RetroHexChatWeb.Components.UI.TreeView do
  @moduledoc false
  use RetroHexChatWeb.Component

  @doc "Renders a Win98-style tree view container."
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  @spec tree_view(map()) :: Phoenix.LiveView.Rendered.t()
  def tree_view(assigns) do
    ~H"""
    <div class={classes(["bg-white shadow-retro-field p-1.5 overflow-y-auto", @class])} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc "Renders a collapsible tree view group with a label."
  attr :label, :string, required: true
  attr :open, :boolean, default: true
  attr :class, :any, default: nil
  attr :rest, :global
  slot :icon
  slot :inner_block, required: true

  @spec tree_view_group(map()) :: Phoenix.LiveView.Rendered.t()
  def tree_view_group(assigns) do
    ~H"""
    <details open={@open} class={classes(["mb-1", @class])} {@rest}>
      <summary class="tree-view-summary">
        <span class="tree-view-marker">
          <span class="tree-view-marker-open hidden">-</span>
          <span class="tree-view-marker-closed">+</span>
        </span>
        <span :if={@icon != []} class="icon-slot-16">
          {render_slot(@icon)}
        </span>
        {@label}
      </summary>
      <div class="ml-3 pl-2 border-l border-dotted border-gray-400">
        {render_slot(@inner_block)}
      </div>
    </details>
    """
  end

  @doc "Renders a leaf item in the tree view."
  attr :active, :boolean, default: false
  attr :class, :any, default: nil
  attr :rest, :global
  slot :icon
  slot :inner_block, required: true

  @spec tree_view_item(map()) :: Phoenix.LiveView.Rendered.t()
  def tree_view_item(assigns) do
    ~H"""
    <div
      class={classes(["tree-view-item menu-row", @active && "menu-row--selected", @class])}
      {@rest}
    >
      <span :if={@icon != []} class="icon-slot-16">
        {render_slot(@icon)}
      </span>
      {render_slot(@inner_block)}
    </div>
    """
  end
end
