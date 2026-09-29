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

  attr :reposition, :boolean,
    default: false,
    doc: "Clamp within the viewport (flip left/up) via the MenuReposition hook"

  attr :sheet, :boolean,
    default: false,
    doc: "Below the stacking breakpoint, present as a bottom sheet instead of at the pointer"

  attr :sheet_title, :string,
    default: nil,
    doc: "What the sheet is about — only drawn in the sheet presentation"

  attr :on_close, :any,
    default: nil,
    doc: "JS command or event name used for click-away and Escape dismissal"

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
          @sheet && "context-menu--sheet",
          @class
        ])
      }
      style={"left: #{@x}px; top: #{@y}px;"}
      data-sheet={@sheet && "true"}
      phx-hook={@reposition && "MenuRepositionHook"}
      phx-click-away={@on_close}
      phx-window-keydown={@on_close}
      phx-key={@on_close && "escape"}
      data-testid={"context-menu-#{@id}"}
      data-escape-guard
      {@rest}
    >
      <%!-- A menu placed at the pointer covers the very row it is about once the
            drawer holding that row is 300px wide, and at the top of a phone it
            is out of thumb reach besides. Same items, same order, same
            definition — only the frame changes, and only below the breakpoint.
            The heading and the dismissal exist for the sheet: a menu that
            arrived from a held finger has to say what it is about, and has to
            be dismissable without a click-away target to aim at. --%>
      <div class="shadow-retro-window bg-surface p-[3px]">
        <div :if={@sheet && @sheet_title} class="context-menu__sheet-title">
          {@sheet_title}
        </div>
        <ul class="list-none m-0 p-retro-2 min-w-[140px]">
          {render_slot(@inner_block)}
          <li :if={@sheet && @on_close} class="context-menu__sheet-dismiss" phx-click={@on_close}>
            {dgettext("ui", "Cancel")}
          </li>
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
  attr :testid, :string, default: nil, doc: "Overrides the action-derived data-testid"
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
          "flex items-center gap-retro-6 px-retro-16 py-2.5 md:py-[2px] min-h-[44px] md:min-h-0 whitespace-nowrap text-sm md:text-xs cursor-pointer select-none",
          if(@disabled,
            do: "text-disabled cursor-default",
            else: "hover:bg-selection-bg hover:text-selection-fg"
          ),
          @class
        ])
      }
      phx-click={unless(@disabled, do: @on_click)}
      phx-value-action={unless(@disabled, do: @action)}
      aria-disabled={@disabled && "true"}
      data-testid={@testid || if(@action, do: "context-menu-item-#{@action}")}
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
