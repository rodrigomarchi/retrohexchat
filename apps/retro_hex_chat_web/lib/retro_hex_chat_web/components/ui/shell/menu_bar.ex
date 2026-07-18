defmodule RetroHexChatWeb.Components.UI.MenuBar do
  @moduledoc """
  Screen-agnostic building blocks for a macOS-style textual menu bar.

  These primitives carry the DOM contract expected by `MenuBarHook`
  (`assets/js/hooks/ui/menu_bar_hook.js`) so it lives in exactly one place:

    * `menu_bar/1` — the `<nav role="menubar">` the hook mounts on.
    * `menu/1` — one top-level menu: a `[data-menubar-trigger]` and its
      `[data-menubar-dropdown]` panel as siblings under a single wrapper, the
      structure the hook relies on (`trigger.parentElement` → `querySelector`).

  A disabled menu grays its trigger and omits its dropdown entirely (the hook
  bails on `data-disabled="true"`). Dropdown items are supplied by the caller as
  `<li>` elements — compose `RetroHexChatWeb.Components.UI.ContextMenu`
  (`context_menu_item`/`context_menu_label`/`context_menu_separator`), which the
  hook closes on click.

  Content lives in the concrete bars that compose these primitives
  (`MenuBarApp` for chat); nothing here is screen-specific.
  """
  use RetroHexChatWeb.Component

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
  slot :icon, doc: "optional icon rendered before the trigger label"

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
        <:icon :if={@icon != []}>{render_slot(@icon)}</:icon>
      </.menu_trigger>
      <.menu_dropdown :if={!@disabled}>
        {render_slot(@inner_block)}
      </.menu_dropdown>
    </div>
    """
  end

  # ── Private helpers ─────────────────────────────────

  attr :label, :string, required: true
  attr :disabled, :boolean, default: false
  attr :testid, :string, default: nil
  attr :class, :any, default: nil
  attr :label_class, :any, default: nil
  slot :icon

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
      <span :if={@icon != []} class="inline-flex h-4 w-4 shrink-0 items-center justify-center">
        {render_slot(@icon)}
      </span>
      <span class={@label_class}>{@label}</span>
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
