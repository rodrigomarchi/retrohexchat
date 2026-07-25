defmodule RetroHexChatWeb.Components.UI.MenuBar do
  @moduledoc """
  Screen-agnostic building blocks for a macOS-style textual menu bar.

  These primitives carry the DOM contract expected by `MenuBarHook`
  (`assets/js/hooks/ui/menu_bar_hook.js`) so it lives in exactly one place:

    * `menu_bar/1` — the `<nav role="menubar">` the hook mounts on.
    * `menu/1` — one top-level menu: a `[data-menubar-trigger]` and its
      `[data-menubar-dropdown]` panel as siblings under a single wrapper, the
      structure the hook relies on (`trigger.parentElement` → `querySelector`).
    * `submenu/1` — a nested panel inside a dropdown, on its own
      `[data-menubar-submenu]` / `[data-menubar-submenu-panel]` contract so the
      hook can open it without the parent dropdown's sweep closing it.

  A disabled menu grays its trigger and omits its dropdown entirely (the hook
  bails on `data-disabled="true"`). Dropdown items are supplied by the caller as
  `<li>` elements — compose `RetroHexChatWeb.Components.UI.ContextMenu`
  (`context_menu_item`/`context_menu_label`/`context_menu_separator`), which the
  hook closes on click.

  Content lives in the concrete bars that compose these primitives
  (`MenuBarApp` for chat); nothing here is screen-specific.
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

  @doc """
  Renders the menu bar `<nav>` — the mount point for `MenuBarHook`.

  Pass `phx-hook="MenuBarHook"` (and any `id`) through the global attrs; the
  `menu/1` children go in the default slot.
  """
  attr :id, :string, default: "menubar"
  attr :testid, :string, default: "menu-bar"
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  @spec menu_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def menu_bar(assigns) do
    ~H"""
    <nav
      id={@id}
      class={classes(["flex items-center shrink-0 select-none", @class])}
      role="menubar"
      data-testid={@testid}
      {@rest}
    >
      {render_slot(@inner_block)}
    </nav>
    """
  end

  @doc """
  Renders one top-level menu: a trigger button plus its dropdown panel.

  Every menu carries a mandatory semantic icon (16×16, from
  `RetroHexChatWeb.Icons`) rendered before its label, so all menu bars read
  consistently across screens.

  When `disabled` is true the trigger is grayed and the dropdown is not
  rendered at all — matching the hook, which ignores disabled triggers.
  """
  attr :label, :string, required: true
  attr :disabled, :boolean, default: false
  attr :testid, :string, default: nil
  attr :class, :any, default: nil
  attr :trigger_class, :any, default: nil
  attr :label_class, :any, default: nil
  slot :inner_block, required: true, doc: "dropdown items (context_menu_* <li> elements)"
  slot :icon, required: true, doc: "semantic 16×16 icon rendered before the trigger label"

  @spec menu(map()) :: Phoenix.LiveView.Rendered.t()
  def menu(assigns) do
    ~H"""
    <div class={classes(["relative inline-flex", @class])}>
      <.menu_trigger
        label={@label}
        disabled={@disabled}
        testid={@testid}
        class={@trigger_class}
        label_class={@label_class}
      >
        <:icon>{render_slot(@icon)}</:icon>
      </.menu_trigger>
      <.menu_dropdown :if={!@disabled}>
        {render_slot(@inner_block)}
      </.menu_dropdown>
    </div>
    """
  end

  @doc """
  Renders a nested submenu as one row inside a dropdown.

  The row looks and reads like a `context_menu_item`, plus a right-pointing
  chevron, and reveals its own panel of `<li>` items. Use it to group a family
  of related commands that would otherwise bloat the parent dropdown.

  The panel deliberately does NOT carry `data-menubar-dropdown`: the hook's
  `_closeAll`/`_openMenu` sweep every element with that attribute, so reusing it
  here would make a submenu open and close with its parent. It carries
  `data-menubar-submenu-panel` instead, and the hook drives it separately.

  On desktop the panel flies out to the right of the parent row. In the stacked
  (mobile) shell it expands inline instead — a flyout would be clipped by the
  mobile menu's `overflow: hidden` — which is CSS-only (`app-menu.css`); the
  open/close contract is identical on both.
  """
  attr :label, :string, required: true
  attr :testid, :string, default: nil
  attr :class, :any, default: nil
  slot :icon, required: true, doc: "14×14 icon SVG, matching context_menu_item"
  slot :inner_block, required: true, doc: "submenu items (context_menu_* <li> elements)"

  @spec submenu(map()) :: Phoenix.LiveView.Rendered.t()
  def submenu(assigns) do
    ~H"""
    <li
      class={classes(["menubar-submenu group/submenu relative list-none", @class])}
      data-menubar-submenu
      data-submenu-open="false"
      role="none"
    >
      <div
        class={
          classes([
            "flex items-center gap-retro-6 px-retro-16 py-2.5 md:py-[2px] min-h-[44px] md:min-h-0",
            "whitespace-nowrap text-sm md:text-xs cursor-pointer select-none",
            "hover:bg-selection-bg hover:text-selection-fg",
            "group-data-[submenu-open=true]/submenu:bg-selection-bg",
            "group-data-[submenu-open=true]/submenu:text-selection-fg"
          ])
        }
        data-menubar-submenu-trigger
        data-testid={@testid}
        aria-haspopup="true"
      >
        <span class="shrink-0 w-[14px] h-[14px] inline-flex items-center justify-center">
          {render_slot(@icon)}
        </span>
        <span class="flex-1">{@label}</span>
        <Icons.icon_chevron_right class="ml-retro-24 h-[14px] w-[14px] shrink-0" />
      </div>

      <div
        class="menubar-submenu__panel u-hidden absolute left-full top-0 min-w-[180px] p-[3px] bg-surface text-foreground shadow-retro-window z-dropdown"
        data-menubar-submenu-panel
      >
        <ul class="list-none m-0 p-retro-2">
          {render_slot(@inner_block)}
        </ul>
      </div>
    </li>
    """
  end

  # ── Private helpers ─────────────────────────────────

  attr :label, :string, required: true
  attr :disabled, :boolean, default: false
  attr :testid, :string, default: nil
  attr :class, :any, default: nil
  attr :label_class, :any, default: nil
  slot :icon, required: true

  defp menu_trigger(assigns) do
    ~H"""
    <button
      type="button"
      class={
        classes([
          "inline-flex items-center gap-1 px-2 py-px text-sm border border-transparent whitespace-nowrap",
          if(@disabled,
            do: "text-muted-foreground cursor-default",
            else: "bg-transparent cursor-pointer hover:bg-accent"
          ),
          @class
        ])
      }
      data-menubar-trigger
      data-disabled={if(@disabled, do: "true", else: "false")}
      data-testid={@testid}
      aria-haspopup="true"
      aria-label={@label}
    >
      <span class={
        classes([
          "inline-flex h-4 w-4 shrink-0 items-center justify-center",
          @disabled && "opacity-50"
        ])
      }>
        {render_slot(@icon)}
      </span>
      <span class={@label_class} data-menubar-label>{@label}</span>
    </button>
    """
  end

  slot :inner_block, required: true

  defp menu_dropdown(assigns) do
    ~H"""
    <div
      class="u-hidden absolute top-full left-0 min-w-[180px] p-[3px] bg-surface shadow-retro-window z-dropdown"
      data-menubar-dropdown
      data-escape-guard
    >
      <ul class="list-none m-0 p-retro-2">
        {render_slot(@inner_block)}
      </ul>
    </div>
    """
  end
end
