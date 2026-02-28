defmodule RetroHexChatWeb.Components.UI.ContextMenu do
  @moduledoc """
  Win98-style right-click context menu for the showcase design system.

  Provides a fixed-position menu that appears at cursor coordinates,
  with items, separators, disabled states, icons, and shortcut hints.

  ## Usage

      <.context_menu id="my-menu" show={@show_menu} x={@menu_x} y={@menu_y}>
        <.context_menu_item icon_fn={:icon_tab_pm}>Query (PM)</.context_menu_item>
        <.context_menu_item icon_fn={:icon_btn_search}>Whois</.context_menu_item>
        <.context_menu_separator />
        <.context_menu_item disabled>Disabled item</.context_menu_item>
      </.context_menu>
  """
  use RetroHexChatWeb.Component

  # ── Menu Container ─────────────────────────────────────

  @doc """
  Renders a context menu at the given x/y coordinates.
  Uses shadow-retro-window for the Win98 3D frame.

  Set `position="absolute"` and wrap in a `relative` container
  for inline/showcase usage.
  """
  attr :id, :string, required: true
  attr :show, :boolean, default: true
  attr :x, :integer, default: 0
  attr :y, :integer, default: 0
  attr :position, :string, default: "fixed", values: ~w(fixed absolute)
  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  @spec context_menu(map()) :: Phoenix.LiveView.Rendered.t()
  def context_menu(assigns) do
    ~H"""
    <div
      :if={@show}
      id={@id}
      class={
        classes([
          @position,
          "z-context-menu",
          @class
        ])
      }
      style={"left: #{@x}px; top: #{@y}px;"}
      data-testid={"context-menu-#{@id}"}
      {@rest}
    >
      <div class="shadow-retro-window bg-surface p-[3px]">
        <ul class="list-none m-0 p-retro-2 min-w-[140px]">
          {render_slot(@inner_block)}
        </ul>
      </div>
    </div>
    """
  end

  # ── Menu Item ──────────────────────────────────────────

  @doc """
  Renders a context menu item with optional 14x14 icon and shortcut hint.
  Hover state: blue background (#000080) with white text.
  """
  attr :disabled, :boolean, default: false
  attr :action, :string, default: nil, doc: "Action identifier passed as phx-value-action"
  attr :on_click, :any, default: nil, doc: "JS command or event name for click"
  attr :class, :string, default: nil
  attr :rest, :global
  slot :icon, required: true, doc: "14×14 icon SVG — mandatory for visual consistency"
  slot :shortcut
  slot :inner_block, required: true

  @spec context_menu_item(map()) :: Phoenix.LiveView.Rendered.t()
  def context_menu_item(assigns) do
    ~H"""
    <li
      class={
        classes([
          "flex items-center gap-retro-6 px-retro-16 py-retro-4 whitespace-nowrap text-sm cursor-pointer select-none",
          if(@disabled,
            do: "text-disabled cursor-default",
            else: "hover:bg-selection-bg hover:text-selection-fg"
          ),
          @class
        ])
      }
      phx-click={unless(@disabled, do: @on_click)}
      phx-value-action={unless(@disabled, do: @action)}
      data-testid={if @action, do: "context-menu-item-#{@action}"}
      {@rest}
    >
      <span class="shrink-0 w-[14px] h-[14px] inline-flex items-center justify-center">
        {render_slot(@icon)}
      </span>
      <span class="flex-1">{render_slot(@inner_block)}</span>
      <span
        :if={@shortcut != []}
        class={[
          "ml-retro-24 text-xs",
          if(@disabled, do: "text-disabled", else: "text-muted-foreground")
        ]}
      >
        {render_slot(@shortcut)}
      </span>
    </li>
    """
  end

  # ── Separator ──────────────────────────────────────────

  @doc "Renders a horizontal separator line between menu items."
  attr :class, :string, default: nil

  @spec context_menu_separator(map()) :: Phoenix.LiveView.Rendered.t()
  def context_menu_separator(assigns) do
    ~H"""
    <li
      class={classes(["border-t border-separator my-retro-2 cursor-default", @class])}
      role="separator"
    />
    """
  end

  # ── Label / Group Header ──────────────────────────────

  @doc "Renders a non-interactive label/group header in the menu."
  attr :class, :string, default: nil
  slot :inner_block, required: true

  @spec context_menu_label(map()) :: Phoenix.LiveView.Rendered.t()
  def context_menu_label(assigns) do
    ~H"""
    <li class={
      classes([
        "px-retro-16 py-retro-2 text-xs font-bold text-muted-foreground select-none cursor-default",
        @class
      ])
    }>
      {render_slot(@inner_block)}
    </li>
    """
  end
end
