defmodule RetroHexChatWeb.Components.UI.Menu do
  @moduledoc false
  use RetroHexChatWeb.Component

  @doc "Renders a Win98-style context menu container."
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  @spec menu(map()) :: Phoenix.LiveView.Rendered.t()
  def menu(assigns) do
    ~H"""
    <div class={classes(["shadow-retro-window bg-surface p-[3px] min-w-[140px]", @class])} {@rest}>
      <div class="shadow-retro-field bg-white p-[2px]">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  @doc "Renders a menu item with optional icon and shortcut."
  attr :disabled, :boolean, default: false
  attr :class, :any, default: nil
  attr :rest, :global
  slot :icon, required: true, doc: "16×16 icon SVG — mandatory for visual consistency"
  slot :inner_block, required: true
  slot :shortcut

  @spec menu_item(map()) :: Phoenix.LiveView.Rendered.t()
  def menu_item(assigns) do
    ~H"""
    <div
      role="menuitem"
      class={
        classes([
          "flex items-center gap-1.5 px-4 py-1 text-sm whitespace-nowrap cursor-pointer select-none",
          if(@disabled,
            do: "text-disabled cursor-default",
            else: "hover:bg-primary hover:text-white"
          ),
          @class
        ])
      }
      {@rest}
    >
      <span class="w-[16px] h-[16px] flex-shrink-0 inline-flex items-center justify-center">
        {render_slot(@icon)}
      </span>
      <span class="flex-1">{render_slot(@inner_block)}</span>
      <span :if={@shortcut != []} class="ml-4 text-xs text-gray-500">
        {render_slot(@shortcut)}
      </span>
    </div>
    """
  end

  @doc "Renders a horizontal separator line in a menu."
  attr :class, :any, default: nil

  @spec menu_separator(map()) :: Phoenix.LiveView.Rendered.t()
  def menu_separator(assigns) do
    ~H"""
    <div role="separator" class={classes(["border-t border-separator my-[2px]", @class])} />
    """
  end
end
