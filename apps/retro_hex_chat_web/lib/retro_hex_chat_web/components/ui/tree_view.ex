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
  slot :inner_block, required: true

  @spec tree_view_group(map()) :: Phoenix.LiveView.Rendered.t()
  def tree_view_group(assigns) do
    ~H"""
    <details open={@open} class={classes(["mb-1", @class])} {@rest}>
      <summary class="cursor-pointer select-none text-xs font-bold text-gray-600 uppercase tracking-wide px-1 py-0.5 hover:bg-hover-bg list-none flex items-center gap-1">
        <span class="inline-flex items-center justify-center w-[9px] h-[9px] border border-gray-500 bg-white text-[8px] leading-none flex-shrink-0 font-mono">
          <span class="tree-view-marker-open hidden">-</span>
          <span class="tree-view-marker-closed">+</span>
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
      class={
        classes([
          "flex items-center gap-1.5 px-1 py-[1px] text-sm cursor-pointer select-none",
          if(@active,
            do: "bg-primary text-white",
            else: "hover:bg-primary hover:text-white"
          ),
          @class
        ])
      }
      {@rest}
    >
      <span :if={@icon != []} class="w-4 h-4 flex-shrink-0 inline-flex items-center justify-center">
        {render_slot(@icon)}
      </span>
      {render_slot(@inner_block)}
    </div>
    """
  end
end
