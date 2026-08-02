defmodule RetroHexChatWeb.Components.UI.Desktop do
  @moduledoc """
  Win98-style desktop: a workspace that hosts draggable, resizable windows plus a
  taskbar with a Start menu, system tray and one button per open window.

  Generic and reusable — pairs with the `WindowManagerHook`, which owns every bit
  of window chrome state on the client (position, size, z-order, minimize/maximize,
  open/closed) and persists it to localStorage. Nothing here is lobby-specific:
  compose `desktop_window/1` children and a `taskbar/1` inside `desktop/1`; the
  window bodies are arbitrary feature components.

  Each `desktop_window/1` composes the lower-level `window/1` primitives (frame,
  title bar, body) so the retro chrome stays in one place. Windows are addressed by
  a stable string `id` shared between the window, its `taskbar_button/1` and any
  `start_menu_item/1` that opens it; the hook wires them together via `data-window-*`
  attributes.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.ContextMenu
  import RetroHexChatWeb.Components.UI.Window

  alias RetroHexChatWeb.Icons

  @doc """
  Renders the desktop workspace that hosts windows and a taskbar.

  Mount point for the `WindowManagerHook`. The `inner_block` slot holds
  `desktop_window/1` children (absolutely positioned within the workspace); the
  `taskbar` slot holds a `taskbar/1`.
  """
  attr :id, :string, required: true
  attr :persist_key, :string, default: nil, doc: "localStorage suffix for layout persistence"

  attr :persist, :boolean,
    default: true,
    doc:
      "when false, the hook starts from the default layout every time and clears any " <>
        "previously saved state for persist_key — a clean slate each open, no cross-visit memory"

  attr :cascade_on_mount, :boolean,
    default: false,
    doc:
      "lay the windows out in a cascade on a first visit, first window in front. " <>
        "For desktops that open with everything on screen; a saved layout always wins"

  attr :escape_closes_windows, :boolean,
    default: false,
    doc:
      "when true, Escape closes the topmost unpinned window (dialog-window desktops). " <>
        "Open WM menus, modal dialogs and visible [data-escape-guard] overlays take priority"

  attr :class, :any, default: nil
  attr :rest, :global

  slot :header,
    doc:
      "optional top bar (e.g. a menu/status bar) rendered above the workspace; lives inside " <>
        "the hook element so its data-window-* controls are wired like the taskbar's"

  slot :shortcuts, doc: "desktop_shortcut/1 icons pinned to the workspace (behind windows)"
  slot :inner_block, required: true, doc: "desktop_window/1 children"
  slot :taskbar, doc: "a taskbar/1"

  @spec desktop(map()) :: Phoenix.LiveView.Rendered.t()
  def desktop(assigns) do
    ~H"""
    <div
      id={@id}
      phx-hook="WindowManagerHook"
      data-window-manager
      data-persist-key={@persist_key}
      data-persist={to_string(@persist)}
      data-cascade-on-mount={to_string(@cascade_on_mount)}
      data-escape-closes-windows={to_string(@escape_closes_windows)}
      data-window-loading-text={dgettext("ui", "Opening...")}
      class={classes(["flex flex-1 flex-col overflow-hidden", @class])}
      {@rest}
    >
      {render_slot(@header)}
      <div class="desktop__workspace relative isolate flex-1 overflow-hidden">
        <div
          :if={@shortcuts != []}
          class="desktop__shortcuts absolute left-0 top-0 z-0 flex flex-col flex-wrap content-start gap-1 p-2"
        >
          {render_slot(@shortcuts)}
        </div>
        {render_slot(@inner_block)}
      </div>
      {render_slot(@taskbar)}
    </div>
    """
  end

  @doc """
  Renders a Win98-style desktop shortcut: an icon above a label, pinned to the
  workspace. Double-click opens (and focuses) the target window; a single click
  just selects it (classic desktop behaviour). Wired to the `WindowManagerHook`
  via `data-window-shortcut`.

  Pass `href` or `navigate` when the target lives at its own URL — the shortcut
  becomes a real link and a single click follows it.
  """
  attr :window, :string, required: true, doc: "target window id to open on double-click"
  attr :label, :string, required: true
  attr :href, :string, default: nil, doc: "render as a link to this URL instead of a button"
  attr :navigate, :string, default: nil, doc: "same, via LiveView navigation"
  attr :class, :any, default: nil
  attr :rest, :global

  slot :icon, required: true, doc: "32×32 icon"

  @spec desktop_shortcut(map()) :: Phoenix.LiveView.Rendered.t()
  def desktop_shortcut(assigns) do
    ~H"""
    <.chrome_control
      href={@href}
      navigate={@navigate}
      class={classes(["desktop-shortcut", @class])}
      data-window-shortcut={@window}
      {@rest}
    >
      <span class="desktop-shortcut__icon inline-flex h-8 w-8 items-center justify-center">
        {render_slot(@icon)}
      </span>
      <span class="desktop-shortcut__label">{@label}</span>
    </.chrome_control>
    """
  end

  # Desktop chrome that can also be a link.
  #
  # The window manager reads the `data-window-*` attribute either way. What an
  # `href` buys is a desktop that works — and can be crawled — before any
  # JavaScript runs: the Start menu and taskbar become ordinary navigation, and
  # the manager upgrades them in place once it mounts. Classes and data
  # attributes are identical in both shapes, so the two are indistinguishable
  # on screen.
  attr :href, :string, default: nil
  attr :navigate, :string, default: nil
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  defp chrome_control(%{href: nil, navigate: nil} = assigns) do
    ~H"""
    <button type="button" class={@class} {@rest}>{render_slot(@inner_block)}</button>
    """
  end

  defp chrome_control(assigns) do
    ~H"""
    <.link href={@href} navigate={@navigate} class={@class} {@rest}>
      {render_slot(@inner_block)}
    </.link>
    """
  end

  @doc """
  Renders a single draggable, resizable window.

  Composes `window/1` + `window_title_bar/1` + `window_body/1`. The initial
  geometry and open state are hints — the `WindowManagerHook` restores any saved
  layout from localStorage on mount and takes over thereafter. A `pinned` window
  drops its close control and cannot be closed (only minimized/maximized).
  """
  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :pinned, :boolean, default: false, doc: "no close control; window cannot be closed"
  attr :open, :boolean, default: true, doc: "initial open state (storage may override)"

  attr :managed, :boolean,
    default: false,
    doc:
      "server-owned lifecycle: render the window only while it is open (presence in the DOM " <>
        "means open). The hook pushes \"window_open\" when something opens it while unmounted " <>
        "and \"window_closed\" on a client-side close — the host must handle both events"

  attr :default_maximized, :boolean,
    default: false,
    doc:
      "start maximized when no saved layout exists for this window; restoring falls back " <>
        "to the default_x/default_y/width/height geometry"

  attr :default_centered, :boolean,
    default: false,
    doc:
      "center in the workspace when no saved layout exists (recomputed on workspace resize); " <>
        "touching the window, cascade/tile or a saved position takes over"

  attr :default_x, :integer, default: 24
  attr :default_y, :integer, default: 24
  attr :width, :integer, default: 360
  attr :height, :integer, default: nil, doc: "nil = auto height from content"
  attr :min_width, :integer, default: 220
  attr :min_height, :integer, default: 120
  attr :resizable, :boolean, default: true

  attr :persist_geometry, :boolean,
    default: true,
    doc:
      "when false the window is ephemeral: the window manager neither applies nor saves " <>
        "layout state for it, so every mount starts from the default geometry (session " <>
        "windows whose content only exists while a live feature runs)"

  attr :on_close, :any,
    default: nil,
    doc:
      "server event for the close button; when set, closing is server-driven (e.g. ends an " <>
        "active feature) instead of a client-side hide"

  attr :class, :any, default: nil
  attr :body_class, :any, default: nil
  attr :rest, :global, doc: "extra attrs on the window root, e.g. data-testid"

  slot :icon, required: true, doc: "16×16 title bar icon"

  slot :meta,
    doc: "Live status shown after the title — see window_title_bar/1. Hidden on narrow windows."

  slot :inner_block, required: true, doc: "window body content"
  slot :status, doc: "window_status_bar_field/1 elements, pinned under the body"

  @spec desktop_window(map()) :: Phoenix.LiveView.Rendered.t()
  def desktop_window(assigns) do
    ~H"""
    <div
      id={@id}
      data-window-id={@id}
      data-window-pinned={to_string(@pinned)}
      data-window-managed={to_string(@managed)}
      data-window-initial-open={to_string(@open)}
      data-window-default-maximized={to_string(@default_maximized)}
      data-window-default-centered={to_string(@default_centered)}
      data-window-default-x={@default_x}
      data-window-default-y={@default_y}
      data-window-default-width={@width}
      data-window-default-height={@height}
      data-window-min-width={@min_width}
      data-window-min-height={@min_height}
      data-window-ephemeral={to_string(!@persist_geometry)}
      class={classes(["desktop-window u-hidden absolute", @class])}
      {@rest}
    >
      <.window class="h-full">
        <.window_title_bar
          title={@title}
          controls={window_controls(@pinned)}
          force_close={!@pinned}
          on_close={@on_close}
          data-window-titlebar
        >
          <:icon>{render_slot(@icon)}</:icon>
          <:meta :if={@meta != []}>{render_slot(@meta)}</:meta>
        </.window_title_bar>

        <.window_body data-window-body class={classes(["overflow-auto", @body_class])}>
          {render_slot(@inner_block)}
        </.window_body>

        <.window_status_bar :if={@status != []}>
          {render_slot(@status)}
        </.window_status_bar>

        <button
          :if={@resizable}
          type="button"
          data-window-resize="se"
          aria-label={dgettext("ui", "Resize")}
          class="desktop-window__resize desktop-window__resize--grip absolute bottom-0 right-0 h-4 w-4 cursor-nwse-resize"
        >
        </button>
        <span
          :for={dir <- ~w(n s e w ne nw sw)}
          :if={@resizable}
          data-window-resize={dir}
          aria-hidden="true"
          class={"desktop-window__resize desktop-window__resize--#{dir} absolute"}
        />
      </.window>
    </div>
    """
  end

  @doc """
  Renders the bottom taskbar.

  Slots: `start` (a Start button + menu), `inner_block` (one `taskbar_button/1`
  per window) and `tray` (a `desktop_tray/1`).

  Ships the two Win98 right-click menus: one for a window's taskbar button
  (restore/minimize/maximize/close) and one for the empty taskbar area
  (cascade/tile/minimize all). The `WindowManagerHook` opens and positions them
  and applies the actions — they render hidden and carry no server events.
  """
  attr :id, :string, default: nil
  attr :class, :any, default: nil
  attr :rest, :global

  slot :start, doc: "Start button and menu"
  slot :inner_block, doc: "taskbar_button/1 list"
  slot :tray, doc: "system tray content"

  @spec taskbar(map()) :: Phoenix.LiveView.Rendered.t()
  def taskbar(assigns) do
    ~H"""
    <div
      id={@id}
      class={
        classes([
          "desktop-taskbar shadow-retro-window bg-surface z-floating relative",
          "flex items-center gap-[3px] p-[2px]",
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@start)}
      <%!-- min-w-0: without it a flex item refuses to shrink below its content,
            so a full button strip pushes the tray off the bar instead of
            scrolling. --%>
      <div class="desktop-taskbar__buttons flex min-w-0 flex-1 items-center gap-[3px] overflow-x-auto">
        {render_slot(@inner_block)}
      </div>
      {render_slot(@tray)}
      <.taskbar_window_menu id={"#{@id || "desktop-taskbar"}-window-menu"} />
      <.taskbar_desktop_menu id={"#{@id || "desktop-taskbar"}-desktop-menu"} />
    </div>
    """
  end

  attr :id, :string, required: true

  defp taskbar_window_menu(assigns) do
    ~H"""
    <.context_menu id={@id} class="u-hidden" data-taskbar-menu="window">
      <.context_menu_item data-taskbar-menu-action="restore">
        <:icon><Icons.icon_win_restore class="h-[9px] w-[8px]" /></:icon>
        {dgettext("ui", "Restore")}
      </.context_menu_item>
      <.context_menu_item data-taskbar-menu-action="minimize">
        <:icon><Icons.icon_win_minimize class="h-[2px] w-[6px]" /></:icon>
        {dgettext("ui", "Minimize")}
      </.context_menu_item>
      <.context_menu_item data-taskbar-menu-action="maximize">
        <:icon><Icons.icon_win_maximize class="h-[9px] w-[9px]" /></:icon>
        {dgettext("ui", "Maximize")}
      </.context_menu_item>
      <.context_menu_separator />
      <.context_menu_item data-taskbar-menu-action="close">
        <:icon><Icons.icon_close_pixel class="h-[7px] w-[8px]" /></:icon>
        {dgettext("ui", "Close")}
      </.context_menu_item>
    </.context_menu>
    """
  end

  attr :id, :string, required: true

  defp taskbar_desktop_menu(assigns) do
    ~H"""
    <.context_menu id={@id} class="u-hidden" data-taskbar-menu="desktop">
      <.context_menu_item data-taskbar-menu-action="cascade">
        <:icon><Icons.icon_win_cascade class="h-[14px] w-[14px]" /></:icon>
        {dgettext("ui", "Cascade Windows")}
      </.context_menu_item>
      <.context_menu_item data-taskbar-menu-action="tile-h">
        <:icon><Icons.icon_win_tile_h class="h-[14px] w-[14px]" /></:icon>
        {dgettext("ui", "Tile Windows Horizontally")}
      </.context_menu_item>
      <.context_menu_item data-taskbar-menu-action="tile-v">
        <:icon><Icons.icon_win_tile_v class="h-[14px] w-[14px]" /></:icon>
        {dgettext("ui", "Tile Windows Vertically")}
      </.context_menu_item>
      <.context_menu_separator />
      <.context_menu_item data-taskbar-menu-action="minimize-all">
        <:icon><Icons.icon_win_minimize_all class="h-[14px] w-[14px]" /></:icon>
        {dgettext("ui", "Minimize All Windows")}
      </.context_menu_item>
    </.context_menu>
    """
  end

  @doc """
  Renders a taskbar button for a window.

  The `WindowManagerHook` toggles its visibility (hidden while the window is
  closed), pressed look (focused window) and flash (attention) via `data-window-taskbar`.
  Clicking focuses/restores the window, or minimizes it when already focused.
  """
  attr :window, :string, required: true, doc: "target window id"
  attr :label, :string, required: true
  attr :badge, :string, default: nil, doc: "live indicator (call duration, transfer %, ...)"
  attr :href, :string, default: nil, doc: "render as a link when the window is another page"
  attr :navigate, :string, default: nil, doc: "same, via LiveView navigation"
  attr :class, :any, default: nil
  attr :rest, :global

  slot :icon, required: true

  @spec taskbar_button(map()) :: Phoenix.LiveView.Rendered.t()
  def taskbar_button(assigns) do
    ~H"""
    <.chrome_control
      href={@href}
      navigate={@navigate}
      data-window-taskbar={@window}
      class={
        classes([
          "desktop-taskbar__button shadow-retro-raised bg-surface",
          "inline-flex shrink-0 items-center gap-1 px-2 py-[2px] text-xs",
          (@href || @navigate) && "text-text no-underline",
          @class
        ])
      }
      {@rest}
    >
      <span class="inline-flex h-4 w-4 shrink-0 items-center justify-center">
        {render_slot(@icon)}
      </span>
      <%!-- 16ch: a window titled after its conversation ("#lobby[Troll]") must
            fit without an ellipsis. --%>
      <span class="max-w-[16ch] truncate">{@label}</span>
      <span :if={@badge} class="text-primary shrink-0 font-bold tabular-nums">{@badge}</span>
    </.chrome_control>
    """
  end

  @doc """
  Renders one taskbar button standing for a family of open windows.

  A family collapses only while **two or more** of its windows are open —
  a group wrapping a single window would cost a click and buy nothing. The
  trigger shows how many are open; clicking it reveals a panel of the family's
  windows, and clicking one of those focuses it exactly like a plain taskbar
  button (the items carry `data-window-taskbar` themselves).

  Driven by `WindowManagerHook` through `data-taskbar-group` /
  `data-taskbar-group-panel` — a contract of its own, not the Start menu's: the
  two live in different roots and reusing the attribute would make each close
  the other's panel.

  The panel is `fixed` and anchored by the hook, not `absolute`: the button strip
  is an `overflow-x-auto` scroller, which clips an upward flyout on both axes.
  The taskbar's right-click menus solve it the same way.
  """
  attr :label, :string, required: true
  attr :count, :integer, required: true
  attr :testid, :string, default: nil
  attr :class, :any, default: nil
  slot :icon, required: true
  slot :inner_block, required: true, doc: "taskbar_button/1 elements"

  @spec taskbar_group(map()) :: Phoenix.LiveView.Rendered.t()
  def taskbar_group(assigns) do
    ~H"""
    <div
      class={classes(["desktop-taskbar__group group/taskgroup relative shrink-0", @class])}
      data-taskbar-group
      data-group-open="false"
    >
      <button
        type="button"
        class={
          classes([
            "desktop-taskbar__button shadow-retro-raised bg-surface",
            "inline-flex shrink-0 items-center gap-1 px-2 py-[2px] text-xs",
            "group-data-[group-open=true]/taskgroup:shadow-retro-sunken"
          ])
        }
        data-taskbar-group-trigger
        data-testid={@testid}
        aria-haspopup="true"
        aria-expanded="false"
      >
        <span class="inline-flex h-4 w-4 shrink-0 items-center justify-center">
          {render_slot(@icon)}
        </span>
        <span class="max-w-[12ch] truncate">{@label}</span>
        <span class="text-primary shrink-0 font-bold tabular-nums">{@count}</span>
      </button>

      <div
        class="desktop-taskbar__group-panel u-hidden fixed z-floating min-w-[180px] p-[3px] bg-surface text-foreground shadow-retro-window"
        data-taskbar-group-panel
      >
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  @doc """
  Renders the Start button that toggles the Start menu.
  """
  attr :label, :string, required: true
  attr :class, :any, default: nil
  attr :rest, :global

  slot :icon, required: true

  @spec start_button(map()) :: Phoenix.LiveView.Rendered.t()
  def start_button(assigns) do
    ~H"""
    <button
      type="button"
      data-window-start
      class={
        classes([
          "desktop-start-button shadow-retro-raised bg-surface",
          "inline-flex shrink-0 items-center gap-1 px-2 py-[2px] text-xs font-bold",
          @class
        ])
      }
      {@rest}
    >
      <span class="inline-flex h-4 w-4 shrink-0 items-center justify-center">
        {render_slot(@icon)}
      </span>
      {@label}
    </button>
    """
  end

  @doc """
  Renders the Start menu popup (hidden until the Start button toggles it).

  Place it next to `start_button/1` inside a `relative`-positioned container so it
  anchors above the button.
  """
  attr :id, :string, required: true
  attr :class, :any, default: nil
  attr :rest, :global

  slot :inner_block, required: true, doc: "start_menu_item/1 and start_menu_separator/1"

  @spec start_menu(map()) :: Phoenix.LiveView.Rendered.t()
  def start_menu(assigns) do
    ~H"""
    <div
      id={@id}
      data-window-start-menu
      class={
        classes([
          "desktop-start-menu u-hidden shadow-retro-window bg-surface",
          "absolute bottom-full left-0 z-floating mb-[2px] w-56 p-[3px]",
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Renders a Start menu item.

  Pass `phx-click` for a server action or `data-window-open="<id>"` (read by the
  `WindowManagerHook`) to open/focus a window — both flow through `@rest`. Pass
  `href` or `navigate` when the entry leads to its own URL: the item becomes a
  real link, so the menu is navigable and crawlable without JavaScript.
  """
  attr :label, :string, required: true
  attr :href, :string, default: nil, doc: "render as a link to this URL instead of a button"
  attr :navigate, :string, default: nil, doc: "same, via LiveView navigation"
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(disabled)

  slot :icon, required: true

  @spec start_menu_item(map()) :: Phoenix.LiveView.Rendered.t()
  def start_menu_item(assigns) do
    ~H"""
    <.chrome_control
      href={@href}
      navigate={@navigate}
      class={
        classes([
          "desktop-start-menu__item flex w-full items-center gap-2 px-2 py-1 text-left text-xs",
          "hover:bg-primary hover:text-white disabled:opacity-50",
          (@href || @navigate) && "text-text no-underline",
          @class
        ])
      }
      {@rest}
    >
      <span class="inline-flex h-4 w-4 shrink-0 items-center justify-center">
        {render_slot(@icon)}
      </span>
      <span class="truncate">{@label}</span>
    </.chrome_control>
    """
  end

  @doc """
  Renders a nested group inside the Start menu.

  The row reads like a `start_menu_item/1` plus a right-pointing chevron, and
  reveals its own panel of items. Use it to keep a family of related entries out
  of the flat list — the Start menu has no scroll of its own, so a long flat list
  simply grows past the top of the screen.

  Driven by `WindowManagerHook` through `data-start-submenu` /
  `data-start-submenu-panel`. On desktop the panel flies out to the right; in
  the stacked shell it expands inline (CSS only, `window-manager.css`).
  """
  attr :label, :string, required: true
  attr :testid, :string, default: nil
  attr :class, :any, default: nil
  slot :icon, required: true
  slot :inner_block, required: true, doc: "start_menu_item/1 elements"

  @spec start_menu_submenu(map()) :: Phoenix.LiveView.Rendered.t()
  def start_menu_submenu(assigns) do
    ~H"""
    <div
      class={classes(["desktop-start-submenu group/start relative", @class])}
      data-start-submenu
      data-submenu-open="false"
    >
      <button
        type="button"
        class={
          classes([
            "desktop-start-menu__item flex w-full items-center gap-2 px-2 py-1 text-left text-xs",
            "hover:bg-primary hover:text-white",
            "group-data-[submenu-open=true]/start:bg-primary",
            "group-data-[submenu-open=true]/start:text-white"
          ])
        }
        data-start-submenu-trigger
        data-testid={@testid}
        aria-haspopup="true"
      >
        <span class="inline-flex h-4 w-4 shrink-0 items-center justify-center">
          {render_slot(@icon)}
        </span>
        <span class="flex-1 truncate">{@label}</span>
        <Icons.icon_chevron_right class="h-[14px] w-[14px] shrink-0" />
      </button>

      <div
        class="desktop-start-submenu__panel u-hidden absolute bottom-0 left-full z-floating w-56 p-[3px] bg-surface text-foreground shadow-retro-window"
        data-start-submenu-panel
      >
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  @doc "Renders a horizontal separator inside a Start menu."
  attr :class, :any, default: nil

  @spec start_menu_separator(map()) :: Phoenix.LiveView.Rendered.t()
  def start_menu_separator(assigns) do
    ~H"""
    <div class={classes(["shadow-retro-status my-[2px] h-[2px]", @class])}></div>
    """
  end

  @doc """
  Renders the system tray (right end of the taskbar) — an inset panel for status
  widgets such as a clock.
  """
  attr :class, :any, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  @spec desktop_tray(map()) :: Phoenix.LiveView.Rendered.t()
  def desktop_tray(assigns) do
    ~H"""
    <div
      class={
        classes([
          "shadow-retro-status flex shrink-0 items-center gap-2 px-2 py-[2px] text-xs",
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  # Pinned windows expose minimize + maximize/restore but never a close control.
  # Maximize and restore are both rendered; the WindowManagerHook shows exactly
  # one of them depending on the window's maximized state.
  defp window_controls(true), do: [:minimize, :maximize, :restore]
  defp window_controls(false), do: [:minimize, :maximize, :restore, :close]
end
