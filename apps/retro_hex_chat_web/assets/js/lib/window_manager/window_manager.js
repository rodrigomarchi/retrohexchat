/**
 * Win98-style desktop window manager — the engine, free of any framework.
 *
 * Owns all window chrome state on the client — position, size, z-order,
 * minimize/maximize, open/closed — and remembers it in tab memory keyed by
 * `data-persist-key`. It reads the DOM the server already rendered and decorates
 * it; it never produces content of its own. That is what lets the same desktop
 * run on a public, crawlable page: the markup stands on its own and the manager
 * is pure progressive enhancement.
 *
 * Create one with `createWindowManager(el, opts)` and drive it through
 * `mount()`, `reconcile()`, `command()` and `destroy()`. `opts.pushEvent` is
 * optional: supply it inside LiveView so server-managed windows can round-trip,
 * omit it on a static page and those code paths simply stay dormant.
 *
 * Windows, their taskbar buttons and Start-menu entries are wired purely through
 * data attributes, so the manager is generic and reusable:
 *   - `[data-window-id]`            a window (with `data-window-default-*` geometry;
 *                                   `data-window-default-maximized` starts it maximized
 *                                   when no remembered layout exists;
 *                                   `data-window-default-centered` centers it in the
 *                                   workspace until the user touches it — pointerdown
 *                                   freezes the current position so the window never
 *                                   moves mid-click — or a remembered layout applies)
 *   - `[data-window-titlebar]`      drag handle inside a window
 *   - `[data-window-resize=<dir>]`  resize handle (n|s|e|w|ne|nw|se|sw; bare = se)
 *   - `[data-window-control=...]`   minimize | maximize | restore | close button
 *   - `[data-window-taskbar=<id>]`  taskbar button targeting a window
 *   - `[data-window-start]`         Start button (toggles the menu)
 *   - `[data-window-start-menu]`    Start menu popup
 *   - `[data-window-open=<id>]`     opens/focuses a window (e.g. a menu item)
 *   - `[data-taskbar-group]`        taskbar button standing for a window family
 *   - `[data-taskbar-menu=<kind>]`  right-click menu (window | desktop)
 *   - `[data-taskbar-menu-action]`  item inside a taskbar menu
 *
 * Right-clicking a taskbar button opens the window menu (restore/minimize/
 * maximize/close); right-clicking elsewhere on the taskbar opens the desktop
 * menu (cascade/tile/minimize all). Minimize, restore-from-taskbar and
 * maximize play a Win98 zoom-wireframe animation (skipped when the user
 * prefers reduced motion).
 *
 * The server can drive it via `push_event("window_command", {action, id})` where
 * action is one of open | focus | flash | close | minimize | maximize | dock_pair.
 *
 * Escape first closes any open WM menu. On desktops opting in via
 * `data-escape-closes-windows`, it then closes the topmost unpinned window —
 * unless an open modal dialog or a visible `[data-escape-guard]` overlay owns
 * the key. A consumed press never reaches the server's keydown bindings.
 *
 * Windows may enter and leave the DOM after mount (server-conditional islands):
 * every patch reconciles the registry — new `[data-window-id]` elements are
 * registered (honouring any remembered layout), replaced nodes are re-bound keeping
 * their client state, and removed windows are pruned. A window marked
 * `data-window-managed` has a server-owned lifecycle (presence in the DOM means
 * open): opening one that is not in the DOM pushes `"window_open"` and closing
 * it client-side pushes `"window_closed"`, so the host can mount/unmount its
 * island. Hosts with managed windows must handle both events.
 */
import { handleCopySelectionClick, refreshCopySelectionItems } from "../ui/copy_selection";

const rememberedLayouts = new Map();
// What Phoenix's own focus_wrap considers reachable, minus the sentinel spans
// it puts at each end of the trap: those carry tabindex="0" and focusing one
// lands the caret on the boundary rather than on the first control.
const FOCUSABLE_SELECTOR = [
  "a[href]",
  "button:not([disabled])",
  "input:not([disabled]):not([type=hidden])",
  "select:not([disabled])",
  "textarea:not([disabled])",
  '[tabindex]:not([tabindex="-1"]):not([id$="-start"]):not([id$="-end"])',
].join(",");

const Z_BASE = 10;
const STACK_BREAKPOINT = 768;
// Below this, a window's own menu strip is swapped for the icon rail. Measured,
// not guessed: the six-menu strip runs 536px in English and 653px in German,
// the widest of the fourteen locales, plus the window's 3px padding either side.
// The slack above that is room for a locale longer than any we ship today.
//
// It was 800 while the strip carried eight menus and ran to 757px. Games and
// the two server groups left with the other launchers, and the number came
// down with them — the bar now holds out to a narrower window before folding.
const WINDOW_MENU_BREAKPOINT = 700;
// Not every bar is the chat's: the help viewer and the landing pages hang
// fewer menus under their title bars, and folding those into icons at the width
// the chat's own strip needs would collapse a strip with room to spare. So the
// measurement above is spent per menu, and each window asks for what its own bar
// holds.
const MENU_ENTRY_WIDTH = 100;
const MENU_ENTRY_SELECTOR = "[data-window-menu] .app-menu-bar__desktop-menu";
const EDGE_MARGIN = 40;
const CASCADE_STEP = 26;
const CASCADE_SIZE_RATIO = 0.6;
const ZOOM_FALLBACK_MS = 400;

// Overlays that own the Escape key while open — the hook must not close a
// window when one is visible. Modal dialogs flip data-state; other overlays
// (menu-bar dropdowns, context menus, the emoji picker) carry
// [data-escape-guard] and are either removed from the DOM or u-hidden when
// closed.
const ESCAPE_OWNER_SELECTOR =
  '[phx-show-modal][data-state="open"], [data-desktop-connect-dialog][data-state="open"], [data-desktop-static-dialog][data-state="open"], [data-escape-guard]:not(.u-hidden)';

const WindowManagerCore = {
  mount() {
    this.workspace = this.el.querySelector(".desktop__workspace");
    this.persistKey = this.el.dataset.persistKey || null;
    this.persistEnabled = this.el.dataset.persist !== "false";
    this.zCounter = Z_BASE;
    this._wsSize = null;
    this.focusedId = null;
    this.stacked = false;
    this.startMenuRootScroll = 0;
    this.drag = null;
    this.resize = null;
    this.windows = {};
    this.pendingWindows = {};
    this.menuWindowId = null;
    this._ghosts = new Set();
    this.reducedMotion =
      typeof window.matchMedia === "function" &&
      window.matchMedia("(prefers-reduced-motion: reduce)").matches;

    // Persistence disabled: wipe any remembered layout so we always open from the
    // default layout. In-session window state still lives on this manager instance.
    if (this.persistKey && !this.persistEnabled) {
      rememberedLayouts.delete(this.persistKey);
    }

    this.collectWindows();
    this.restore();
    // A desktop that opens with every window on screen needs a layout, not a
    // pile at one default position. Only on a first mount: once there is a
    // remembered layout it is the reader's, and it wins until the page reloads.
    if (this.el.dataset.cascadeOnMount === "true" && !this.readRememberedLayout()) {
      this.layoutOnMount();
    }
    this.bindEvents();
    this.updateStacking();
    this.applyAll();
  },

  reconcile() {
    this.reconcileWindows();
    this.pruneDetachedPendingWindows();

    // Re-assert the stacked-mode class: the server patch just rebuilt the desktop
    // root's class list without it (it is client-owned), and window visibility
    // below depends on the current stacked state.
    this.updateStacking();

    // A server-driven DOM patch resets the class/style we own on window roots
    // (the server always renders `u-hidden`), so re-assert client-owned geometry
    // and visibility after every patch. Mid-gesture the pointer handler owns the
    // dragged/resized window, so re-assert every OTHER window but leave that one
    // alone — otherwise a background patch (e.g. a stats tick) would hide the
    // other windows until the gesture ends.
    const activeId = (this.drag && this.drag.id) || (this.resize && this.resize.id);
    for (const id in this.windows) {
      if (id === activeId) continue;
      this.applyWindow(id);
    }
  },

  // Reconcile the registry with the patched DOM: register windows that entered,
  // re-bind windows whose root node was replaced (keeping their client state),
  // and prune windows that left.
  reconcileWindows() {
    const present = new Set();
    const added = [];
    // A server-managed window is not in the DOM when it is asked for: the click
    // pushes `window_open` and the island arrives a patch later. That is why
    // `openWindow` cannot be the only place the keyboard is handed over — for
    // these the open finishes here, when the thing we asked for shows up.
    const requested = [];
    for (const el of this.ownedElements("[data-window-id]")) {
      const id = el.dataset.windowId;
      present.add(id);
      if (this.pendingWindows[id]) requested.push(id);
      this.clearPendingWindow(id);
      if (!this.windows[id]) {
        this.registerWindow(el);
        const remembered = this.readRememberedLayout();
        if (remembered && remembered[id]) this.applyRememberedState(id, remembered[id]);
        added.push(id);
      } else if (this.windows[id].el !== el) {
        this.windows[id].el = el;
      }
    }
    for (const id of Object.keys(this.windows)) {
      if (!present.has(id)) this.pruneWindow(id);
    }
    // A window that arrived open takes focus, mirroring mount behaviour. Focus
    // state only — the updated() re-assert right after this renders everything.
    for (const id of added) {
      const st = this.windows[id].state;
      if (st.open && !st.minimized) {
        this.focusedId = id;
        st.z = this.zCounter += 1;
      } else if (this.focusedId === id) {
        // registerWindow claimed focus before the remembered layout marked the
        // window minimized — hand focus back to a visible window.
        this.focusTopmost();
      }
    }
    for (const id of requested) {
      const win = this.windows[id];
      if (win && win.state.open && !win.state.minimized) this.focusDialogInside(win.el);
    }
  },

  pruneWindow(id) {
    if (this.drag && this.drag.id === id) this.drag = null;
    if (this.resize && this.resize.id === id) this.resize = null;
    if (this.menuWindowId === id) this.closeTaskbarMenus();
    this.clearFlash(id);
    delete this.windows[id];
    if (this.focusedId === id) this.focusTopmost();
  },

  destroy() {
    this.unbindEvents();
    for (const pending of Object.values(this.pendingWindows)) {
      clearTimeout(pending.timer);
      pending.el.remove();
    }
    this.pendingWindows = {};
  },

  // ── Setup ──────────────────────────────────────────────────

  // Nested desktops mean a plain `this.el.querySelectorAll` reaches into another
  // manager's subtree. Every scan below goes through here so a window, taskbar
  // button or menu belongs to exactly one manager: the nearest one above it.
  ownsNode(node) {
    if (!node || typeof node.closest !== "function") return false;
    if (!this.el.contains(node)) return false;
    // The nearest manager root at or above the node has to be this one. A host
    // that renders no marker at all cannot be nesting anything, so containment
    // is the whole answer there — which keeps bare embeds working.
    const nearest = node.closest("[data-window-manager]");
    return !nearest || !this.el.contains(nearest) || nearest === this.el;
  },

  ownedElements(selector) {
    return Array.from(this.el.querySelectorAll(selector)).filter((el) => this.ownsNode(el));
  },

  collectWindows() {
    for (const el of this.ownedElements("[data-window-id]")) this.registerWindow(el);
  },

  registerWindow(el) {
    const id = el.dataset.windowId;
    const d = el.dataset;
    const open = d.windowInitialOpen !== "false";
    this.windows[id] = {
      el,
      pinned: d.windowPinned === "true",
      managed: d.windowManaged === "true",
      // Ephemeral windows never load or save layout state: every mount
      // starts from the default geometry for transient surfaces.
      ephemeral: d.windowEphemeral === "true",
      minW: int(d.windowMinWidth, 220),
      minH: int(d.windowMinHeight, 120),
      // The registered size, kept beside the live one: a filled window
      // recomputes from this every time the workspace changes, and reading the
      // live size back would ratchet it up and never let it shrink again.
      baseW: int(d.windowDefaultWidth, 360),
      baseH: d.windowDefaultHeight ? int(d.windowDefaultHeight, null) : null,
      // Fraction of the workspace a centered window opens at, when its
      // registered size is smaller than that. Zero means "the registered size".
      fill: float(d.windowDefaultFill, 0),
      state: {
        open,
        minimized: false,
        // Default only — a remembered layout overrides it in applyRememberedState. The
        // default_* geometry stays populated either way, so restoring from a
        // default-maximized window lands on sane coordinates.
        maximized: d.windowDefaultMaximized === "true",
        // Centered geometry is computed lazily in applyWindow (the workspace may
        // have no laid-out size at mount); cleared once anything else takes
        // ownership of the position (drag, resize, cascade/tile, remembered layout).
        centered: d.windowDefaultCentered === "true",
        x: int(d.windowDefaultX, 24),
        y: int(d.windowDefaultY, 24),
        w: int(d.windowDefaultWidth, 360),
        h: d.windowDefaultHeight ? int(d.windowDefaultHeight, null) : null,
        z: open ? (this.zCounter += 1) : Z_BASE,
      },
    };
    if (open) this.focusedId = id;
  },

  restore() {
    const remembered = this.readRememberedLayout();
    if (!remembered) return;
    for (const id in this.windows) {
      if (!remembered[id]) continue;
      this.applyRememberedState(id, remembered[id]);
      const st = this.windows[id].state;
      if (st.open && !st.minimized) {
        st.z = this.zCounter += 1;
        this.focusedId = id;
      }
    }
  },

  applyRememberedState(id, s) {
    const win = this.windows[id];
    if (win.ephemeral) return;
    const st = win.state;
    st.centered = false;
    if (typeof s.x === "number") st.x = s.x;
    if (typeof s.y === "number") st.y = s.y;
    if (typeof s.w === "number") st.w = Math.max(s.w, win.minW);
    if (typeof s.h === "number") st.h = Math.max(s.h, win.minH);
    st.maximized = !!s.maximized;
    st.minimized = !!s.minimized;
    // Pinned windows are always open; a managed window's presence in the DOM
    // already means open (the server owns that flag); otherwise honour memory.
    if (!win.pinned && !win.managed && typeof s.open === "boolean") st.open = s.open;
  },

  bindEvents() {
    // A desktop can contain another desktop — the showcase demos one inside the
    // shell's own. These five listeners sit on the root, so without this guard
    // the outer manager also answers for the inner manager's chrome.
    const scoped = (handler) => (e) => {
      if (this.ownsNode(e.target)) handler(e);
    };

    this._onPointerDown = scoped((e) => this.onPointerDown(e));
    this._onClick = scoped((e) => this.onClick(e));
    this._onStartMenuPointerOver = scoped((e) => this.onStartMenuPointerOver(e));
    this._onDblClick = scoped((e) => this.onDblClick(e));
    this._onContextMenu = scoped((e) => this.onContextMenu(e));
    this._onKeyDown = (e) => this.onKeyDown(e);
    this._onPointerMove = (e) => this.onPointerMove(e);
    this._onPointerUp = (e) => this.onPointerUp(e);
    this._onDocPointerDown = (e) => this.onDocPointerDown(e);
    this._onResize = () => this.onViewportResize();

    this.el.addEventListener("pointerdown", this._onPointerDown);
    this.el.addEventListener("click", this._onClick);
    this.el.addEventListener("pointerover", this._onStartMenuPointerOver);
    this.el.addEventListener("dblclick", this._onDblClick);
    this.el.addEventListener("contextmenu", this._onContextMenu);
    document.addEventListener("keydown", this._onKeyDown);
    document.addEventListener("pointermove", this._onPointerMove);
    document.addEventListener("pointerup", this._onPointerUp);
    document.addEventListener("pointerdown", this._onDocPointerDown, true);
    window.addEventListener("resize", this._onResize);

    // A ResizeObserver on the workspace catches container size changes the window
    // `resize` event misses (e.g. the lobby becoming visible from zero width), and
    // keeps stacking + off-screen clamping in sync with the real layout box.
    if (typeof ResizeObserver === "function" && this.workspace) {
      this._resizeObserver = new ResizeObserver(() => this.onViewportResize());
      this._resizeObserver.observe(this.workspace);
    }
  },

  unbindEvents() {
    this.el.removeEventListener("pointerdown", this._onPointerDown);
    this.el.removeEventListener("click", this._onClick);
    this.el.removeEventListener("pointerover", this._onStartMenuPointerOver);
    this.el.removeEventListener("dblclick", this._onDblClick);
    this.el.removeEventListener("contextmenu", this._onContextMenu);
    document.removeEventListener("keydown", this._onKeyDown);
    document.removeEventListener("pointermove", this._onPointerMove);
    document.removeEventListener("pointerup", this._onPointerUp);
    document.removeEventListener("pointerdown", this._onDocPointerDown, true);
    window.removeEventListener("resize", this._onResize);
    if (this._resizeObserver) this._resizeObserver.disconnect();
    if (this._rafResize) cancelAnimationFrame(this._rafResize);
    for (const ghost of this._ghosts) ghost.remove();
    this._ghosts.clear();
  },

  // ── Pointer interactions (drag / resize / focus) ───────────

  onPointerDown(e) {
    if (e.button !== 0) return;

    // Touching a centered window freezes it at its current position BEFORE any
    // re-apply below runs: a recompute here could move the window mid-click
    // (the press lands, the window shifts, the release misses the target).
    const touchedId = this.windowIdOf(e.target);
    if (touchedId && this.windows[touchedId]) {
      this.windows[touchedId].state.centered = false;
    }

    const resizeH = e.target.closest("[data-window-resize]");
    if (resizeH && !this.stacked) {
      const id = this.windowIdOf(resizeH);
      this.focusWindow(id);
      if (!this.windows[id].state.maximized) {
        this.startResize(e, id, resizeH.dataset.windowResize || "se");
      }
      return;
    }

    // Control buttons are handled on click; don't start a drag from them.
    if (e.target.closest("[data-window-control]")) {
      const id = this.windowIdOf(e.target);
      if (id) this.focusWindow(id);
      return;
    }

    const winEl = e.target.closest("[data-window-id]");
    if (!winEl) return;
    const id = winEl.dataset.windowId;
    this.focusWindow(id);

    const titlebar = e.target.closest("[data-window-titlebar]");
    if (titlebar && !this.stacked && !this.windows[id].state.maximized) {
      this.startDrag(e, id);
    }
  },

  startDrag(e, id) {
    e.preventDefault();
    const st = this.windows[id].state;
    st.centered = false;
    this.drag = { id, px: e.clientX, py: e.clientY, ox: st.x, oy: st.y };
  },

  startResize(e, id, dir) {
    e.preventDefault();
    const st = this.windows[id].state;
    st.centered = false;
    const rect = this.windows[id].el.getBoundingClientRect();
    this.resize = {
      id,
      dir,
      px: e.clientX,
      py: e.clientY,
      ox: st.x,
      oy: st.y,
      ow: st.w || rect.width,
      oh: st.h || rect.height,
    };
  },

  onPointerMove(e) {
    if (this.drag) {
      const win = this.windows[this.drag.id];
      const st = win.state;
      const { w, h } = this.workspaceSize();
      st.x = clamp(this.drag.ox + (e.clientX - this.drag.px), 0, Math.max(0, w - EDGE_MARGIN));
      st.y = clamp(this.drag.oy + (e.clientY - this.drag.py), 0, Math.max(0, h - EDGE_MARGIN));
      this.applyWindow(this.drag.id);
    } else if (this.resize) {
      const win = this.windows[this.resize.id];
      const st = win.state;
      const { dir, px, py, ox, oy, ow, oh } = this.resize;
      const dx = e.clientX - px;
      const dy = e.clientY - py;
      if (dir.includes("e")) st.w = Math.max(win.minW, ow + dx);
      if (dir.includes("s")) st.h = Math.max(win.minH, oh + dy);
      // North/west handles move the near edge while the far edge stays put; the
      // upper clamp keeps the moving edge inside the workspace (x/y >= 0).
      if (dir.includes("w")) {
        st.w = clamp(ow - dx, win.minW, ox + ow);
        st.x = ox + ow - st.w;
      }
      if (dir.includes("n")) {
        st.h = clamp(oh - dy, win.minH, oy + oh);
        st.y = oy + oh - st.h;
      }
      this.applyWindow(this.resize.id);
    }
  },

  onPointerUp() {
    if (this.drag || this.resize) {
      this.drag = null;
      this.resize = null;
      // Re-assert every window now the gesture is over, so a state left stale by
      // the mid-gesture `updated()` guard is corrected immediately (not only on
      // the next server patch).
      this.applyAll();
      this.persist();
    }
  },

  // ── Click interactions (controls / taskbar / start menu) ───

  onClick(e) {
    const clickTarget = e.target.closest("[data-desktop-click-target]");
    if (clickTarget) {
      e.preventDefault();
      this.clearShortcutSelection();
      this.clickDesktopTarget(clickTarget.dataset.desktopClickTarget);
      return;
    }

    const staticDialogOpen = e.target.closest("[data-desktop-static-dialog-open]");
    if (staticDialogOpen) {
      e.preventDefault();
      this.clearShortcutSelection();
      this.showDesktopStaticDialog(staticDialogOpen.dataset.desktopStaticDialogOpen);
      return;
    }

    const connectRequired = e.target.closest("[data-desktop-connect-required]");
    if (connectRequired) {
      e.preventDefault();
      this.clearShortcutSelection();
      this.showDesktopStaticDialog(connectRequired.dataset.desktopConnectDialog);
      return;
    }

    const staticDialogClose = e.target.closest(
      "[data-desktop-static-dialog-close], [data-desktop-connect-dialog-close]",
    );
    if (staticDialogClose) {
      e.preventDefault();
      this.hideDesktopStaticDialog(
        staticDialogClose.closest("[data-desktop-static-dialog], [data-desktop-connect-dialog]"),
      );
      return;
    }

    const menuItem = e.target.closest("[data-taskbar-menu-action]");
    if (menuItem) {
      this.onTaskbarMenuAction(menuItem.dataset.taskbarMenuAction);
      this.closeTaskbarMenus();
      return;
    }

    // A single click selects a desktop shortcut (it opens on double-click); any
    // other click clears the selection, mirroring a real desktop.
    const shortcut = e.target.closest("[data-window-shortcut]");
    if (shortcut) {
      // Select-then-open is a desktop idiom, and it only makes sense for a
      // window this page can actually show. A shortcut pointing somewhere else
      // is a plain link and behaves like one — a single click follows it.
      if (!this.actsLocally(shortcut.dataset.windowShortcut)) return;
      e.preventDefault();
      this.selectShortcut(shortcut);
      return;
    }
    this.clearShortcutSelection();

    const ctrl = e.target.closest("[data-window-control]");
    if (ctrl) {
      // A close button wired to a server event (phx-click) ends an active feature
      // (hang up / cancel / quit). Let LiveView handle it; the server closes the
      // window afterwards via a window_command. Otherwise close it client-side.
      if (ctrl.dataset.windowControl === "close" && ctrl.getAttribute("phx-click")) return;
      this.onControl(ctrl.dataset.windowControl, this.windowIdOf(ctrl));
      return;
    }

    const groupTrigger = e.target.closest("[data-taskbar-group-trigger]");
    if (groupTrigger) {
      this.toggleTaskbarGroup(groupTrigger.closest("[data-taskbar-group]"));
      return;
    }

    const taskBtn = e.target.closest("[data-window-taskbar]");
    if (taskBtn) {
      if (!this.actsLocally(taskBtn.dataset.windowTaskbar)) return;
      e.preventDefault();
      // Picking a window out of a group closes the panel — the click already
      // did what the panel was open for.
      if (e.target.closest("[data-taskbar-group-panel]")) this.closeTaskbarGroups();
      this.onTaskbarClick(taskBtn.dataset.windowTaskbar, taskBtn);
      return;
    }

    if (e.target.closest("[data-window-start]")) {
      this.toggleStartMenu();
      return;
    }

    // A copy row is neither a window opener nor a server action, so it has to
    // be taken before either of those branches sees it. It can live in the
    // Start menu or in a desktop launcher window.
    if (handleCopySelectionClick(e)) {
      if (e.target.closest("[data-window-start-menu]")) this.closeStartMenu();
      return;
    }

    if (this.onStartMenuClick(e)) return;

    const opener = e.target.closest("[data-window-open]");
    if (opener) {
      // Window roots used to carry data-window-open as initial state. Keep this
      // guard so a click inside a window can never be mistaken for an opener.
      if (opener.hasAttribute("data-window-id")) return;
      // A disabled menu item still carries data-window-open (it's a <li>, not a
      // <button>) — it must not act.
      if (opener.getAttribute("aria-disabled") === "true" || opener.disabled) return;
      if (!this.actsLocally(opener.dataset.windowOpen)) return;
      e.preventDefault();
      this.command("open", opener.dataset.windowOpen, opener);
      this.closeStartMenu();
      return;
    }

    // Any other click inside the start menu (e.g. a server-action item) closes it.
    if (e.target.closest("[data-window-start-menu]")) this.closeStartMenu();
  },

  // Desktop chrome may be built from real `<a href>` links so the page stays
  // navigable — and crawlable — without JavaScript. Whether a click is ours to
  // handle depends only on whether the window it names can exist here: one
  // already in the registry, or one the server can mount on request. Anything
  // else lives at another URL, and the link is the only way to reach it.
  actsLocally(id) {
    return Boolean(this.windows[id]) || typeof this.pushEvent === "function";
  },

  onStartMenuPointerOver(e) {
    this.onStartMenuHover(e);
  },

  onDblClick(e) {
    const shortcut = e.target.closest("[data-window-shortcut]");
    if (shortcut) {
      if (!this.actsLocally(shortcut.dataset.windowShortcut)) return;
      e.preventDefault();
      if (shortcut.dataset.windowShortcutAction && typeof this.pushEvent === "function") {
        this.pushEvent(shortcut.dataset.windowShortcutAction, {
          id: shortcut.dataset.windowShortcut,
        });
        return;
      }
      this.command("open", shortcut.dataset.windowShortcut, shortcut);
      return;
    }

    // Double-clicking a title bar toggles maximize/restore, like real Windows.
    // Control buttons act on single click; a fast double-click on one must not
    // also toggle maximize. Stacked mode has no window geometry to toggle.
    if (e.target.closest("[data-window-control]") || this.stacked) return;
    const titlebar = e.target.closest("[data-window-titlebar]");
    if (!titlebar) return;
    const id = this.windowIdOf(titlebar);
    if (id) this.toggleMaximize(id);
  },

  // ── Taskbar context menus ──────────────────────────────────

  onContextMenu(e) {
    const taskBtn = e.target.closest("[data-window-taskbar]");
    const taskbar = e.target.closest(".desktop-taskbar");
    if (!taskBtn && !taskbar) return; // keep the native menu elsewhere
    e.preventDefault();
    this.closeStartMenu();
    if (taskBtn) this.openTaskbarMenu("window", e, taskBtn.dataset.windowTaskbar);
    else this.openTaskbarMenu("desktop", e, null);
  },

  openTaskbarMenu(kind, e, id) {
    this.closeTaskbarMenus();
    const menu = this.el.querySelector(`[data-taskbar-menu="${kind}"]`);
    if (!menu) return;
    this.menuWindowId = id;
    if (kind === "window") this.syncWindowMenu(menu, id);
    menu.classList.remove("u-hidden");
    // Anchor at the cursor, opening upward — the taskbar sits at the bottom.
    const x = clamp(e.clientX, 0, Math.max(0, window.innerWidth - menu.offsetWidth));
    const y = Math.max(0, e.clientY - menu.offsetHeight);
    menu.style.left = `${x}px`;
    menu.style.top = `${y}px`;
  },

  // Gray out the menu entries that don't apply to the target window's state,
  // mirroring the Win98 system menu.
  syncWindowMenu(menu, id) {
    const win = this.windows[id];
    if (!win) return;
    const st = win.state;
    const disabled = {
      restore: !st.maximized && !st.minimized,
      minimize: st.minimized,
      maximize: st.maximized,
      close: win.pinned,
    };
    for (const item of menu.querySelectorAll("[data-taskbar-menu-action]")) {
      const off = !!disabled[item.dataset.taskbarMenuAction];
      if (off) item.setAttribute("aria-disabled", "true");
      else item.removeAttribute("aria-disabled");
    }
  },

  closeTaskbarMenus() {
    for (const menu of this.ownedElements("[data-taskbar-menu]")) {
      menu.classList.add("u-hidden");
    }
    this.menuWindowId = null;
  },

  onTaskbarMenuAction(action) {
    const id = this.menuWindowId;
    switch (action) {
      case "restore": {
        const st = this.windows[id]?.state;
        if (!st) return;
        if (st.minimized) this.openWindow(id);
        else if (st.maximized) this.toggleMaximize(id);
        break;
      }
      case "minimize":
        if (this.windows[id]) this.minimizeWindow(id);
        break;
      case "maximize":
        if (this.windows[id] && !this.windows[id].state.maximized) this.toggleMaximize(id);
        break;
      case "close": {
        const win = this.windows[id];
        if (!win) return;
        // Mirror the X button: a close wired to a server event ends the feature
        // (hang up / cancel / quit) — the menu must not bypass it.
        const closeBtn = win.el.querySelector('[data-window-control="close"][phx-click]');
        if (closeBtn) closeBtn.click();
        else this.closeWindow(id);
        break;
      }
      case "cascade":
        this.cascadeWindows();
        break;
      case "tile-h":
        this.tileWindows("h");
        break;
      case "tile-v":
        this.tileWindows("v");
        break;
      case "minimize-all":
        this.minimizeAll();
        break;
    }
  },

  onKeyDown(e) {
    if (e.key !== "Escape") return;

    const staticDialog = this.openDesktopStaticDialog();
    if (staticDialog) {
      e.stopPropagation();
      this.hideDesktopStaticDialog(staticDialog);
      return;
    }

    // An open WM menu owns the press: close it and consume the event so the
    // server's window-level Escape ladder cannot also dismiss something.
    if (this.anyMenuOpen()) {
      e.stopPropagation();
      this.closeTaskbarMenus();
      this.closeStartMenu();
      this.closeTaskbarGroups();
      return;
    }

    // Escape-close is opt-in per desktop (dialog-window desktops like the chat).
    // Feature desktops (the lobby) keep Escape inert for windows.
    if (this.el.dataset.escapeClosesWindows !== "true") return;

    // Any other open overlay owns Escape: a modal dialog (its own phx-key +
    // the server ladder) or a visible [data-escape-guard] surface (menu-bar
    // dropdown, context menu, emoji picker). Defer entirely.
    if (document.querySelector(ESCAPE_OWNER_SELECTOR)) return;

    const id = this.topmostClosableWindow();
    if (!id) return;

    // This press is ours — consume it so the server ladder doesn't double-handle.
    e.stopPropagation();
    // Mirror the X button: a close wired to a server event ends the feature;
    // otherwise close client-side.
    const closeBtn = this.windows[id].el.querySelector('[data-window-control="close"][phx-click]');
    if (closeBtn) closeBtn.click();
    else this.closeWindow(id);
  },

  showDesktopStaticDialog(id) {
    if (!id) return;
    const dialog = this.el.querySelector(
      `#${cssEscape(id)}[data-desktop-static-dialog], #${cssEscape(id)}[data-desktop-connect-dialog]`,
    );
    if (!dialog) return;

    dialog.dataset.state = "open";
    dialog.classList.remove("hidden");
    document.body.classList.add("overflow-hidden");

    const target =
      dialog.querySelector(
        "button[data-desktop-static-dialog-close]:not([aria-label]), button[data-desktop-connect-dialog-close]:not([aria-label])",
      ) ||
      dialog.querySelector(`#${cssEscape(id)}-surface`) ||
      dialog;
    target.focus?.();
  },

  hideDesktopStaticDialog(dialog) {
    if (!dialog) return;

    dialog.dataset.state = "closed";
    dialog.classList.add("hidden");
    document.body.classList.remove("overflow-hidden");
  },

  openDesktopStaticDialog() {
    return this.ownedElements(
      '[data-desktop-static-dialog][data-state="open"], [data-desktop-connect-dialog][data-state="open"]',
    ).find((dialog) => !dialog.classList.contains("hidden"));
  },

  clickDesktopTarget(selector) {
    if (!selector) return;
    const target = this.el.querySelector(selector);
    if (!target) return;
    target.click();
    target.focus?.();
  },

  anyMenuOpen() {
    const start = this.startMenu();
    if (start && !start.classList.contains("u-hidden")) return true;
    for (const group of this.taskbarGroups()) {
      if (group.dataset.groupOpen === "true") return true;
    }
    for (const menu of this.ownedElements("[data-taskbar-menu]")) {
      if (!menu.classList.contains("u-hidden")) return true;
    }
    return false;
  },

  // Topmost open, visible, unpinned window — the one Escape may close.
  topmostClosableWindow() {
    let top = null;
    let topZ = -1;
    for (const id in this.windows) {
      const win = this.windows[id];
      const st = win.state;
      if (win.pinned || !st.open || st.minimized) continue;
      if ((st.z || 0) > topZ) {
        topZ = st.z || 0;
        top = id;
      }
    }
    return top;
  },

  selectShortcut(el) {
    this.clearShortcutSelection();
    el.classList.add("is-selected");
  },

  clearShortcutSelection() {
    const selected = this.ownedElements("[data-window-shortcut].is-selected");
    for (const node of selected) node.classList.remove("is-selected");
  },

  onControl(action, id) {
    if (!id) return;
    if (action === "minimize") this.minimizeWindow(id);
    else if (action === "close") this.closeWindow(id);
    else if (action === "maximize" || action === "restore") this.toggleMaximize(id);
  },

  onTaskbarClick(id, taskBtn = null) {
    const win = this.windows[id];
    if (!win) return;
    const st = win.state;
    if (!st.open || st.minimized || this.focusedId !== id) {
      this.command("open", id, taskBtn);
    } else {
      this.minimizeWindow(id);
    }
  },

  // ── Window operations ──────────────────────────────────────

  command(action, id, sourceEl = null, payload = {}) {
    if (!id) return;
    if (!this.windows[id]) {
      // Unknown id = a server-managed window that is not mounted. Ask the host
      // to mount its island; the patch registers it and it opens on arrival.
      if ((action === "open" || action === "focus") && typeof this.pushEvent === "function") {
        this.showPendingWindow(id, sourceEl);
        this.pushEvent("window_open", { id });
      }
      return;
    }
    this.clearPendingWindow(id);
    switch (action) {
      case "open":
      case "focus":
        this.openWindow(id);
        break;
      case "flash":
        this.flashWindow(id);
        break;
      case "close":
        this.closeWindow(id);
        break;
      case "minimize":
        this.minimizeWindow(id);
        break;
      case "maximize":
        this.toggleMaximize(id);
        break;
      case "set_geometry":
        this.setWindowGeometry(id, payload);
        break;
      case "dock_pair":
        this.dockPair(id, payload);
        break;
    }
  },

  setWindowGeometry(id, payload = {}) {
    const win = this.windows[id];
    if (!win || this.stacked) return;

    const st = win.state;
    const { w: wsW, h: wsH } = this.workspaceSize();
    const margin = Math.max(8, int(payload.margin, 16));
    const nextW = clamp(int(payload.width, st.w), win.minW, Math.max(win.minW, wsW - margin * 2));
    const nextH =
      payload.height === null
        ? null
        : clamp(
            int(payload.height, st.h || win.minH),
            win.minH,
            Math.max(win.minH, wsH - margin * 2),
          );

    st.open = true;
    st.minimized = false;
    st.maximized = false;
    st.centered = false;
    st.w = nextW;
    st.h = nextH;

    if (payload.anchor === "bottom_right") {
      const effectiveH = nextH || win.el.offsetHeight || win.minH;
      st.x = Math.max(0, wsW - margin - nextW);
      st.y = Math.max(0, wsH - margin - effectiveH);
    } else {
      if (payload.x !== undefined) st.x = int(payload.x, st.x);
      if (payload.y !== undefined) st.y = int(payload.y, st.y);
    }

    st.z = this.zCounter += 1;
    this.focusedId = id;
    this.applyAll();
    this.persist();
  },

  dockPair(primaryId, payload = {}) {
    const secondaryId = payload.secondary_id || payload.secondaryId;
    const primary = this.windows[primaryId];
    const secondary = this.windows[secondaryId];
    if (!primary || !secondary || this.stacked) return;

    const { w: wsW, h: wsH } = this.workspaceSize();
    const margin = Math.max(8, int(payload.margin, 16));
    const gap = Math.max(4, int(payload.gap, 8));
    const availableW = Math.max(0, wsW - margin * 2 - gap);
    const availableH = Math.max(0, wsH - margin * 2);
    const requestedSecondaryW = int(payload.secondary_width, 390);
    const secondaryW = clamp(
      requestedSecondaryW,
      secondary.minW,
      Math.max(secondary.minW, Math.floor(availableW * 0.45)),
    );
    const primaryW = Math.max(primary.minW, availableW - secondaryW);
    const height = Math.max(Math.max(primary.minH, secondary.minH), availableH);
    const y = margin;

    const primarySt = primary.state;
    primarySt.open = true;
    primarySt.minimized = false;
    primarySt.maximized = false;
    primarySt.centered = false;
    primarySt.x = margin;
    primarySt.y = y;
    primarySt.w = primaryW;
    primarySt.h = height;
    primarySt.z = this.zCounter += 1;

    const secondarySt = secondary.state;
    secondarySt.open = true;
    secondarySt.minimized = false;
    secondarySt.maximized = false;
    secondarySt.centered = false;
    secondarySt.x = margin + primaryW + gap;
    secondarySt.y = y;
    secondarySt.w = secondaryW;
    secondarySt.h = height;
    secondarySt.z = this.zCounter += 1;

    // Keep the work surface focused; stats becomes visible but does not steal focus.
    this.focusedId = primaryId;
    primarySt.z = this.zCounter += 1;
    this.applyWindow(secondaryId);
    this.applyWindow(primaryId);
    this.persist();
  },

  showPendingWindow(id, sourceEl) {
    const existing = this.pendingWindows[id];
    if (existing) {
      clearTimeout(existing.timer);
      existing.timer = setTimeout(() => this.clearPendingWindow(id), 5000);
      this.focusPendingWindow(id);
      return;
    }

    const node = document.createElement("div");
    node.className = "desktop-window desktop-window--pending";
    node.dataset.windowPendingId = id;
    node.setAttribute("role", "status");
    node.setAttribute("aria-live", "polite");

    const frame = document.createElement("div");
    frame.className = "desktop-window-opening";

    const titlebar = document.createElement("div");
    titlebar.className = "desktop-window-opening__titlebar";

    const icon = document.createElement("img");
    icon.className = "desktop-window-opening__icon";
    icon.src = "/images/header-hex.svg";
    icon.alt = "";
    icon.setAttribute("aria-hidden", "true");

    const title = document.createElement("span");
    title.className = "desktop-window-opening__title";
    title.textContent = this.pendingWindowTitle(id, sourceEl);

    const body = document.createElement("div");
    body.className = "desktop-window-opening__body";

    const logo = document.createElement("img");
    logo.className = "desktop-window-opening__logo";
    logo.src = "/images/header-hex.svg";
    logo.alt = "";
    logo.setAttribute("aria-hidden", "true");

    const text = document.createElement("span");
    text.className = "desktop-window-opening__text";
    text.textContent = this.el.dataset.windowLoadingText || "Opening...";

    const dot = document.createElement("span");
    dot.className = "desktop-window-opening__dot";
    dot.setAttribute("aria-hidden", "true");

    titlebar.append(icon, title);
    body.append(logo, text, dot);
    frame.append(titlebar, body);
    node.append(frame);
    node.setAttribute("aria-label", `${text.textContent} ${title.textContent}`);

    const { w, h } = this.workspaceSize();
    const width = Math.min(360, Math.max(260, w - 32));
    const height = 128;
    const x = clamp(Math.round((w - width) / 2), 0, Math.max(0, w - width));
    const y = clamp(Math.round(h * 0.28), 16, Math.max(16, h - height));
    const z = (this.zCounter += 1);
    this.setGeom(node, x, y, width, height, z);

    (this.workspace || this.el).appendChild(node);
    this.pendingWindows[id] = {
      el: node,
      timer: setTimeout(() => this.clearPendingWindow(id), 5000),
    };
  },

  focusPendingWindow(id) {
    const pending = this.pendingWindows[id];
    if (!pending) return;
    const z = (this.zCounter += 1);
    pending.el.style.setProperty("--win-z", String(z));
  },

  clearPendingWindow(id) {
    const pending = this.pendingWindows[id];
    if (!pending) return;
    clearTimeout(pending.timer);
    pending.el.remove();
    delete this.pendingWindows[id];
  },

  pruneDetachedPendingWindows() {
    for (const [id, pending] of Object.entries(this.pendingWindows)) {
      if (pending.el.isConnected) continue;
      clearTimeout(pending.timer);
      delete this.pendingWindows[id];
    }
  },

  pendingWindowTitle(id, sourceEl) {
    const sourceLabel =
      sourceEl?.getAttribute("aria-label") || sourceEl?.textContent || sourceEl?.innerText || "";
    const label = sourceLabel.replace(/\s+/g, " ").trim();
    if (label) return label.slice(0, 60);

    return String(id)
      .replace(/[-_]+/g, " ")
      .replace(/\b\w/g, (char) => char.toUpperCase());
  },

  openWindow(id) {
    const win = this.windows[id];
    const st = win.state;
    const wasMinimized = st.open && st.minimized;
    st.open = true;
    st.minimized = false;
    this.clearFlash(id);
    this.focusWindow(id);
    this.focusDialogInside(win.el);
    if (wasMinimized) {
      const btn = this.taskbarButton(id);
      if (btn) this.animateZoom(btn.getBoundingClientRect(), win.el.getBoundingClientRect());
    }
  },

  // Raising a window is a z-index change; it is not where the keyboard goes.
  // A dialog opened from its own menu item runs `JS.focus_first` on the server
  // and lands the caret inside; the same dialog opened from Start went through
  // here instead, and a keyboard user was left on <body> with nothing but Tab
  // from the top of the page. Only windows that trap focus are touched — they
  // are the ones that asked to own the keyboard.
  focusDialogInside(el) {
    const wrap = el?.querySelector?.('[id$="-focus-wrap"]');
    if (!wrap) return;
    if (wrap.contains(document.activeElement)) return;
    const target = wrap.querySelector(FOCUSABLE_SELECTOR);
    if (target) requestAnimationFrame(() => target.focus?.());
  },

  closeWindow(id) {
    const win = this.windows[id];
    if (win.pinned) return;
    // A managed window's lifecycle is server-owned: hide it right away for
    // snappy feedback, then tell the host so it unmounts the island (the patch
    // then prunes the registry).
    if (win.managed && typeof this.pushEvent === "function") {
      this.pushEvent("window_closed", { id });
    }
    win.state.open = false;
    this.clearFlash(id);
    if (this.focusedId === id) this.focusTopmost();
    this.applyAll();
    this.persist();
  },

  minimizeWindow(id) {
    const win = this.windows[id];
    const st = win.state;
    const fromRect = st.open && !st.minimized ? win.el.getBoundingClientRect() : null;
    st.minimized = true;
    if (this.focusedId === id) this.focusTopmost();
    this.applyAll();
    this.persist();
    const btn = this.taskbarButton(id);
    if (fromRect && btn) this.animateZoom(fromRect, btn.getBoundingClientRect());
  },

  toggleMaximize(id) {
    const win = this.windows[id];
    const st = win.state;
    // A window restored from the taskbar animates inside openWindow instead.
    const fromRect = st.open && !st.minimized ? win.el.getBoundingClientRect() : null;
    st.maximized = !st.maximized;
    this.openWindow(id);
    this.persist();
    if (fromRect) this.animateZoom(fromRect, win.el.getBoundingClientRect());
  },

  // Arrange every visible window: staggered stacks (cascade) or an even
  // one-direction split of the workspace (tile), like the Win98 taskbar menu.
  cascadeWindows() {
    const { w: wsW, h: wsH } = this.workspaceSize();
    const ids = this.visibleWindows();
    ids.forEach((id, i) => {
      const win = this.windows[id];
      const st = win.state;
      st.centered = false;
      st.maximized = false;
      st.w = Math.max(win.minW, Math.round(wsW * CASCADE_SIZE_RATIO));
      st.h = Math.max(win.minH, Math.round(wsH * CASCADE_SIZE_RATIO));
      st.x = i * CASCADE_STEP;
      st.y = i * CASCADE_STEP;
      st.z = this.zCounter += 1;
    });
    if (ids.length > 0) this.focusedId = ids[ids.length - 1];
    this.applyAll();
    this.persist();
  },

  // The opening layout of a desktop that shows every window at once.
  //
  // Deliberately *not* cascadeWindows(): that is the Win98 menu action, and it
  // makes every window the same size, which is right when the user asks to
  // tidy a desk they built and wrong for a page. Here each window keeps the
  // size it declared — including auto height, so a window is exactly as tall as
  // what it holds — and only the position is arranged. The first window ends up
  // in front, since on a page it is the one with something to say.
  layoutOnMount() {
    const all = this.visibleWindows();
    if (all.length === 0) return;

    // A window that declared itself centered opts out of the cascade and keeps
    // the middle of the desk. The cascade hands its front slot the deepest
    // offset, which is the worst place to put the tallest window on the page:
    // it starts low, `max-height` caps it against the bottom, and its last rows
    // end up scrolled out of a window that looks like it fits.
    const ids = all.filter((id) => !this.windows[id].state.centered);
    const centered = all.filter((id) => this.windows[id].state.centered);

    if (ids.length > 0) this.cascadeOnMount(ids);

    // Centered windows sit in front of the cascade, and the first window on the
    // page keeps the focus either way — on a phone it is the only one shown.
    for (const id of centered) {
      this.windows[id].state.maximized = false;
      this.windows[id].state.z = this.zCounter += 1;
    }

    this.focusedId = all[0];
    this.applyAll();
    if (ids.length > 0) this.centerLayout(ids);
    this.persist();
  },

  cascadeOnMount(ids) {
    // A fixed 26px step is right for a handful of windows and wrong for a
    // dozen: they bunch into one corner and leave most of the desk empty. Grow
    // the step with the room available and the number of windows sharing it,
    // never below the Win98 step and never so far apart that the stack stops
    // reading as one.
    const { w: wsW, h: wsH } = this.workspaceSize();
    const gaps = Math.max(1, ids.length - 1);
    const stepX = clamp(Math.floor((wsW * 0.5) / gaps), CASCADE_STEP, 76);
    const stepY = clamp(Math.floor((wsH * 0.45) / gaps), CASCADE_STEP, 46);

    ids.forEach((id, i) => {
      const st = this.windows[id].state;
      st.centered = false;
      st.maximized = false;
      // Slots run backwards so the front window sits at the end of the offsets
      // and every window behind shows its title bar above-left of it.
      const slot = ids.length - 1 - i;
      st.x = slot * stepX;
      st.y = slot * stepY;
      st.z = this.zCounter + (ids.length - i);
    });
    this.zCounter += ids.length;
  },

  // Anchoring a cascade at the top-left corner leaves the rest of the desk
  // conspicuously empty — most visible on the pages with only a few windows.
  // Heights are only known once the windows have been laid out, so this runs as
  // a second pass over the real boxes and slides the whole arrangement to the
  // middle of the desk.
  centerLayout(ids) {
    const { w: wsW, h: wsH } = this.workspaceSize();
    if (!wsW || !wsH) return;

    let right = 0;
    let bottom = 0;
    for (const id of ids) {
      const { el, state } = this.windows[id];
      right = Math.max(right, state.x + el.offsetWidth);
      bottom = Math.max(bottom, state.y + el.offsetHeight);
    }

    const dx = Math.floor((wsW - right) / 2);
    const dy = Math.floor((wsH - bottom) / 2);
    if (dx <= 0 && dy <= 0) return;

    for (const id of ids) {
      const st = this.windows[id].state;
      st.x += Math.max(0, dx);
      st.y += Math.max(0, dy);
    }
    this.applyAll();
  },

  tileWindows(direction) {
    const { w: wsW, h: wsH } = this.workspaceSize();
    const ids = this.visibleWindows();
    if (ids.length === 0) return;
    const rowH = Math.floor(wsH / ids.length);
    const colW = Math.floor(wsW / ids.length);
    let offset = 0;
    for (const id of ids) {
      const win = this.windows[id];
      const st = win.state;
      st.centered = false;
      st.maximized = false;
      if (direction === "h") {
        st.x = 0;
        st.y = offset;
        st.w = Math.max(win.minW, wsW);
        st.h = Math.max(win.minH, rowH);
        offset += st.h;
      } else {
        st.x = offset;
        st.y = 0;
        st.w = Math.max(win.minW, colW);
        st.h = Math.max(win.minH, wsH);
        offset += st.w;
      }
    }
    this.applyAll();
    this.persist();
  },

  minimizeAll() {
    for (const id of this.visibleWindows()) this.minimizeWindow(id);
  },

  // Visible (open, not minimized) window ids in z-order, bottom to top.
  visibleWindows() {
    return Object.keys(this.windows)
      .filter((id) => {
        const st = this.windows[id].state;
        return st.open && !st.minimized;
      })
      .sort((a, b) => (this.windows[a].state.z || 0) - (this.windows[b].state.z || 0));
  },

  focusWindow(id) {
    const win = this.windows[id];
    if (!win || !win.state.open || win.state.minimized) return;
    const previousFocusedId = this.focusedId;
    this.focusedId = id;
    win.state.z = this.zCounter += 1;
    this.applyAll();
    if (this.stacked && previousFocusedId !== id) this.resetStackedScrollSoon();
    this.persist();
  },

  focusTopmost() {
    let top = null;
    let topZ = -1;
    for (const id in this.windows) {
      const st = this.windows[id].state;
      if (st.open && !st.minimized && (st.z || 0) > topZ) {
        topZ = st.z || 0;
        top = id;
      }
    }
    this.focusedId = top;
  },

  flashWindow(id) {
    const st = this.windows[id].state;
    if (st.open && !st.minimized && this.focusedId === id) return;
    for (const btn of this.taskbarButtons(id)) {
      btn.classList.add("is-flashing");
    }
  },

  clearFlash(id) {
    for (const btn of this.taskbarButtons(id)) {
      btn.classList.remove("is-flashing");
    }
  },

  // ── Zoom animation ─────────────────────────────────────────

  // Win98 minimize/maximize zoom: a transient dotted wireframe flies from one
  // rect to the other. Purely decorative — the real window switches state
  // instantly, so a lost transitionend (or reduced-motion) costs nothing.
  animateZoom(fromRect, toRect) {
    if (this.reducedMotion || this.stacked) return;
    if (!fromRect || !toRect) return;
    if (fromRect.width === 0 && fromRect.height === 0) return;

    const ghost = document.createElement("div");
    ghost.className = "desktop-zoom";
    this.setZoomRect(ghost, fromRect);
    this.el.appendChild(ghost);
    this._ghosts.add(ghost);
    ghost.getBoundingClientRect(); // flush layout so the transition animates
    this.setZoomRect(ghost, toRect);

    const timer = setTimeout(() => cleanup(), ZOOM_FALLBACK_MS);
    const cleanup = () => {
      clearTimeout(timer);
      this._ghosts.delete(ghost);
      ghost.remove();
    };
    ghost.addEventListener("transitionend", cleanup, { once: true });
  },

  setZoomRect(el, rect) {
    el.style.setProperty("--zoom-x", `${rect.left}px`);
    el.style.setProperty("--zoom-y", `${rect.top}px`);
    el.style.setProperty("--zoom-w", `${rect.width}px`);
    el.style.setProperty("--zoom-h", `${rect.height}px`);
  },

  // ── Rendering ──────────────────────────────────────────────

  applyAll() {
    for (const id in this.windows) this.applyWindow(id);
  },

  applyWindow(id) {
    const win = this.windows[id];
    const el = win.el;
    const st = win.state;
    // In stacked (mobile) mode exactly one window shows at a time — the focused
    // one, filling the workspace like a fullscreen app. The taskbar switches
    // between them; there is always a focused window (the pinned base window).
    const visible = st.open && !st.minimized && (!this.stacked || this.focusedId === id);

    this.setClass(el, "u-hidden", !visible);
    this.setClass(el, "desktop-window--blurred", this.focusedId !== id);
    this.setClass(el, "desktop-window--maximized", st.maximized);
    this.syncWindowMenuBar(el, st);

    // Geometry is driven through CSS custom properties (consumed by .desktop-window
    // in retrohex.css) so the hook never sets width/height/z-index inline directly.
    if (this.stacked) {
      this.clearGeom(el);
    } else if (visible) {
      if (st.maximized) {
        const { w, h } = this.workspaceSize();
        this.setGeom(el, 0, 0, w, h, st.z);
      } else {
        // Keep at least EDGE_MARGIN of the title bar reachable, so a window saved
        // off a wider screen (or after the workspace shrinks) can't get stranded
        // outside an `overflow-hidden` workspace with no way to drag it back.
        const { w, h } = this.workspaceSize();
        if (st.centered) {
          // A filled window is sized off the workspace, so a big screen gets a
          // big window and a laptop gets one that still fits. It rides on
          // `centered` rather than carrying a flag of its own: both mean "this
          // geometry belongs to the workspace until you take it", and every
          // place that hands ownership over already clears this one.
          if (win.fill > 0) {
            st.w = fitToWorkspace(win.baseW, w, win.fill);
            if (win.baseH) st.h = fitToWorkspace(win.baseH, h, win.fill);
          }
          // Auto-height windows have no --win-h; measure the laid-out element
          // (u-hidden was removed above). A zero-size workspace at mount is fine:
          // the workspace ResizeObserver re-runs applyAll once it has real
          // dimensions, and the clamp below keeps the interim position sane.
          const winH = st.h || el.offsetHeight || win.minH;
          st.x = Math.round((w - st.w) / 2);
          st.y = Math.round((h - winH) / 2);
        }
        st.x = clamp(st.x, 0, Math.max(0, w - EDGE_MARGIN));
        st.y = clamp(st.y, 0, Math.max(0, h - EDGE_MARGIN));
        // Only what is drawn is clamped to the workspace, never `st` itself: a
        // window opened on a wide screen and then squeezed has to come back the
        // size it was, not the size the narrow moment allowed.
        this.setGeom(el, st.x, st.y, Math.min(st.w, w), st.h && Math.min(st.h, h), st.z);
      }
    }

    const maxBtn = el.querySelector('[data-window-control="maximize"]');
    const resBtn = el.querySelector('[data-window-control="restore"]');
    if (maxBtn) this.setClass(maxBtn, "u-hidden", st.maximized);
    if (resBtn) this.setClass(resBtn, "u-hidden", !st.maximized);

    this.updateTaskbar(id);
  },

  // A window that carries its own menu bar has to decide between the text strip
  // and the icon rail on ITS width, not the viewport's: the desk can be 1920px
  // wide while the window on it is dragged down to 480. The desktop-wide
  // `desktop--stacked` still applies on a phone; this is the same switch, per
  // window, and `app-menu.css` honours either.
  syncWindowMenuBar(el, st) {
    const strip = el.querySelector("[data-window-menu]");
    if (!strip) return;

    // Stacked and maximized windows are as wide as the desk, whatever `st.w`
    // remembers about the size they will restore to.
    const workspace = this.workspaceSize().w;
    const width = this.stacked || st.maximized ? workspace : Math.min(st.w, workspace);

    // A bar this manager does not recognise falls back to the widest one there
    // is, which folds early rather than overflowing the frame.
    const entries = el.querySelectorAll(MENU_ENTRY_SELECTOR).length;
    const needed = entries ? entries * MENU_ENTRY_WIDTH : WINDOW_MENU_BREAKPOINT;

    this.setClass(el, "desktop-window--narrow", width < needed);
    this.publishMenuStripMetrics(strip);
  },

  // The mobile drawer hangs off the bottom of the strip and is positioned
  // `fixed`, so it needs that edge in viewport pixels — and the chat's sidebar
  // overlays need the strip's height to know where the top chrome ends. Both
  // used to be read off a screen-wide header that no longer exists; a strip
  // under a window's title bar sits wherever that window does, so it is
  // measured rather than assumed. Stacked only: that is the one layout where
  // either number is used, and the read costs a reflow.
  publishMenuStripMetrics(strip) {
    if (!this.stacked) return;

    const rect = strip.getBoundingClientRect();
    if (!rect.height) return;

    this.el.style.setProperty("--rhc-menu-strip-height", `${Math.round(rect.height)}px`);
    this.el.style.setProperty("--rhc-menu-strip-bottom", `${Math.round(rect.bottom)}px`);
  },

  updateTaskbar(id) {
    const buttons = this.taskbarButtons(id);
    if (buttons.length === 0) return;
    const st = this.windows[id].state;
    for (const btn of buttons) {
      const active = st.open && !st.minimized && this.focusedId === id;
      this.setClass(btn, "u-hidden", !st.open);
      this.setClass(btn, "is-active", active);
      if (active) this.setClass(btn, "is-flashing", false);
    }
  },

  // ── Start menu ─────────────────────────────────────────────

  startMenu() {
    return this.el.querySelector("[data-window-start-menu]");
  },

  toggleStartMenu() {
    const menu = this.startMenu();
    if (!menu) return;
    menu.classList.toggle("u-hidden");
    if (menu.classList.contains("u-hidden")) this.closeStartSubmenus(menu);
  },

  closeStartMenu() {
    const menu = this.startMenu();
    if (!menu) return;
    menu.classList.add("u-hidden");
    this.closeStartSubmenus(menu);
  },

  // Groups inside the Start menu open on hover and on click. Hovering any
  // ungrouped row closes them, so at most one flyout shows at a time.
  //
  // Hover is a pointer affordance: the stacked menu is a drill-down where
  // opening a group replaces the whole list, and a finger dragging across the
  // rows would swap levels under itself. There, only a deliberate tap opens.
  onStartMenuHover(e) {
    if (this.stacked) return;

    const menu = this.startMenu();
    if (!menu || menu.classList.contains("u-hidden")) return;
    if (!e.target.closest || !menu.contains(e.target)) return;

    const submenu = e.target.closest("[data-start-submenu]");
    if (submenu) {
      this.openStartSubmenu(submenu);
      return;
    }

    if (e.target.closest("[data-window-start-menu] button")) this.closeStartSubmenus(menu);
  },

  onStartMenuClick(e) {
    const trigger = e.target.closest?.("[data-start-submenu-trigger]");
    if (!trigger) return false;

    e.preventDefault();
    e.stopPropagation();

    const submenu = trigger.closest("[data-start-submenu]");
    if (!submenu) return true;

    if (submenu.dataset.submenuOpen === "true") {
      this.setStartSubmenu(submenu, false);
    } else {
      this.openStartSubmenu(submenu);
    }

    return true;
  },

  openStartSubmenu(submenu) {
    const menu = this.startMenu();
    if (menu) this.closeStartSubmenus(menu, submenu);
    this.setStartSubmenu(submenu, true);
    // The selection cannot change while the menu is up, so reading it as the
    // group opens is enough — the same moment the menu bar reads it.
    refreshCopySelectionItems(submenu);
  },

  closeStartSubmenus(root, except = null) {
    root.querySelectorAll("[data-start-submenu]").forEach((submenu) => {
      if (submenu !== except) this.setStartSubmenu(submenu, false);
    });
  },

  taskbarGroups() {
    return this.ownedElements("[data-taskbar-group]");
  },

  toggleTaskbarGroup(group) {
    if (!group) return;
    const open = group.dataset.groupOpen === "true";
    this.closeTaskbarGroups();
    if (!open) this.setTaskbarGroup(group, true);
  },

  closeTaskbarGroups(except = null) {
    this.taskbarGroups().forEach((group) => {
      if (group !== except) this.setTaskbarGroup(group, false);
    });
  },

  setTaskbarGroup(group, open) {
    group.dataset.groupOpen = open ? "true" : "false";
    const panel = group.querySelector("[data-taskbar-group-panel]");
    const trigger = group.querySelector("[data-taskbar-group-trigger]");
    if (trigger) trigger.setAttribute("aria-expanded", open ? "true" : "false");
    if (!panel) return;

    panel.classList.toggle("u-hidden", !open);
    if (!open || !trigger) return;

    // The strip is an overflow scroller, so the panel is `fixed` and anchored
    // here: left-aligned with its trigger, opening upward off the taskbar.
    const rect = trigger.getBoundingClientRect();
    const x = clamp(rect.left, 0, Math.max(0, window.innerWidth - panel.offsetWidth));
    const y = Math.max(0, rect.top - panel.offsetHeight - 2);
    panel.style.left = `${x}px`;
    panel.style.top = `${y}px`;
  },

  setStartSubmenu(submenu, open) {
    submenu.dataset.submenuOpen = open ? "true" : "false";
    const trigger = submenu.querySelector("[data-start-submenu-trigger]");
    if (trigger) trigger.setAttribute("aria-expanded", open ? "true" : "false");
    const panel = submenu.querySelector("[data-start-submenu-panel]");
    if (panel) panel.classList.toggle("u-hidden", !open);
    this.syncStartMenuLevel();
  },

  // Which level the Start menu is showing. Desktop flies the group panel out
  // beside the list and both levels stay on screen; the stacked shell has no
  // room for that, so the open group takes the menu over and its own row
  // becomes the way back (the level swap itself is CSS). The two levels are
  // one scroll container, so the root's offset is carried across the drill and
  // handed back on the way out — otherwise returning from a group near the
  // bottom of a long menu lands at the top, nowhere near where the user was.
  syncStartMenuLevel() {
    const menu = this.startMenu();
    if (!menu) return;

    const open = Boolean(menu.querySelector('[data-start-submenu][data-submenu-open="true"]'));
    const level = open ? "submenu" : "root";
    if (menu.dataset.startLevel === level) return;

    if (open) this.startMenuRootScroll = menu.scrollTop;
    menu.dataset.startLevel = level;
    menu.scrollTop = open ? 0 : this.startMenuRootScroll || 0;
  },

  onDocPointerDown(e) {
    if (!e.target.closest("[data-taskbar-menu]")) this.closeTaskbarMenus();
    if (!e.target.closest("[data-taskbar-group]")) this.closeTaskbarGroups();

    const menu = this.startMenu();
    if (!menu || menu.classList.contains("u-hidden")) return;
    if (e.target.closest("[data-window-start-menu]") || e.target.closest("[data-window-start]")) {
      return;
    }
    this.closeStartMenu();
  },

  // ── Responsive stacking ────────────────────────────────────

  onViewportResize() {
    this.invalidateWorkspaceSize();
    if (this._rafResize) cancelAnimationFrame(this._rafResize);
    this._rafResize = requestAnimationFrame(() => {
      this.invalidateWorkspaceSize();
      this.updateStacking();
      this.applyAll();
    });
  },

  updateStacking() {
    const wasStacked = this.stacked;
    const previousFocusedId = this.focusedId;
    // Decide stacking from the viewport width, not the workspace width: at mount
    // the workspace has no laid-out width yet (dead render / page transition), so
    // measuring it there misclassifies a phone as a desktop. The desktop always
    // spans the viewport, so innerWidth is the reliable "is this a phone" signal.
    const viewportW =
      typeof window !== "undefined" && window.innerWidth
        ? window.innerWidth
        : this.workspaceSize().w;
    this.stacked = viewportW < STACK_BREAKPOINT;
    // Re-assert unconditionally (not only on change): a server DOM patch rebuilds
    // the desktop root from its server class list, which never carries this
    // client-owned class — so it must be reapplied after every patch.
    this.el.classList.toggle("desktop--stacked", this.stacked);
    // Stacked mode shows only the focused window; if none is focused (or the
    // focused one is closed/minimized), fall back to the topmost open window so
    // the mobile viewport is never blank.
    if (this.stacked) {
      const focused = this.focusedId && this.windows[this.focusedId];
      if (!focused || !focused.state.open || focused.state.minimized) {
        this.focusTopmost();
      }
      if (!wasStacked || previousFocusedId !== this.focusedId) {
        this.resetStackedScrollSoon();
      }
    }
  },

  resetStackedScrollSoon() {
    this.resetStackedScroll();
    requestAnimationFrame(() => this.resetStackedScroll());
  },

  resetStackedScroll() {
    if (!this.stacked) return;
    this.el.scrollLeft = 0;
    this.el.scrollTop = 0;
    if (this.workspace) {
      this.workspace.scrollLeft = 0;
      this.workspace.scrollTop = 0;
    }
  },

  // ── Helpers ────────────────────────────────────────────────

  // Measured once per workspace size, never once per patch. `updated()` calls
  // `applyWindow` for every window after every server patch, and morphdom has
  // just stripped the client-owned geometry off the window roots at that point —
  // reading `clientHeight` there forces the browser to lay the desktop out while
  // the windows have no size. Panels inside them briefly stop overflowing, and a
  // scroll container that briefly does not overflow has its offset clamped to
  // zero: the reader of a chat scrollback is thrown back to the top by a message
  // arriving. The cache is dropped whenever the workspace actually resizes.
  workspaceSize() {
    if (this._wsSize) return this._wsSize;

    const node = this.workspace || this.el;
    this._wsSize = { w: node.clientWidth, h: node.clientHeight };
    return this._wsSize;
  },

  invalidateWorkspaceSize() {
    this._wsSize = null;
  },

  // Every write below is compared before it is made, because `updated()`
  // re-asserts all of this after every server patch and almost none of it has
  // changed. Rewriting a class list or a geometry custom property with the value
  // it already holds still dirties style and relayouts the window — and a
  // relayout of a window is a relayout of the scrollable panels inside it, which
  // is enough to clamp a reader's scroll position in the chat log back to the
  // top. Idempotent writes keep a patch that changed nothing costing nothing.
  setClass(el, name, on) {
    if (el.classList.contains(name) === on) return;
    el.classList.toggle(name, on);
  },

  setStyleProp(el, prop, value) {
    if (el.style.getPropertyValue(prop) === value) return;
    el.style.setProperty(prop, value);
  },

  clearStyleProp(el, prop) {
    if (el.style.getPropertyValue(prop) === "") return;
    el.style.removeProperty(prop);
  },

  setGeom(el, x, y, w, h, z) {
    this.setStyleProp(el, "--win-x", `${x}px`);
    this.setStyleProp(el, "--win-y", `${y}px`);
    this.setStyleProp(el, "--win-w", `${w}px`);
    if (h) this.setStyleProp(el, "--win-h", `${h}px`);
    else this.clearStyleProp(el, "--win-h");
    this.setStyleProp(el, "--win-z", String(z || Z_BASE));
  },

  clearGeom(el) {
    for (const prop of ["--win-x", "--win-y", "--win-w", "--win-h", "--win-z"]) {
      this.clearStyleProp(el, prop);
    }
  },

  windowIdOf(node) {
    const winEl = node.closest("[data-window-id]");
    return winEl ? winEl.dataset.windowId : null;
  },

  taskbarButton(id) {
    const buttons = this.taskbarButtons(id);
    return buttons.find((btn) => btn.getClientRects().length > 0) || buttons[0] || null;
  },

  taskbarButtons(id) {
    return this.ownedElements(`[data-window-taskbar="${cssEscape(id)}"]`);
  },

  readRememberedLayout() {
    if (!this.persistKey || !this.persistEnabled) return null;
    return rememberedLayouts.get(this.persistKey) || null;
  },

  persist() {
    if (!this.persistKey || !this.persistEnabled) return;
    const data = {};
    for (const id in this.windows) {
      if (this.windows[id].ephemeral) continue;
      const s = this.windows[id].state;
      data[id] = {
        open: s.open,
        minimized: s.minimized,
        maximized: s.maximized,
        x: s.x,
        y: s.y,
        w: s.w,
        h: s.h,
      };
    }
    rememberedLayouts.set(this.persistKey, data);
  },
};

function int(value, fallback) {
  const n = parseInt(value, 10);
  return Number.isNaN(n) ? fallback : n;
}

function float(value, fallback) {
  const n = parseFloat(value);
  return Number.isNaN(n) ? fallback : n;
}

// The workspace share a window opens at, never below the size it registered and
// never past the workspace itself. `preferred > available` collapses to the
// workspace, which is what keeps a big window off a small screen.
function fitToWorkspace(preferred, available, ratio) {
  return Math.min(Math.max(Math.round(available * ratio), preferred), available);
}

function clamp(value, min, max) {
  return Math.min(Math.max(value, min), max);
}

function cssEscape(value) {
  if (window.CSS && typeof window.CSS.escape === "function") return window.CSS.escape(value);
  return String(value).replace(/["\\]/g, "\\$&");
}

/**
 * Builds a window manager over `el` (a `.desktop` container).
 *
 * `pushEvent` is the only seam to a host framework. Without it the manager runs
 * standalone, and windows whose lifecycle the server owns simply never appear.
 */
export function createWindowManager(el, { pushEvent = null } = {}) {
  const wm = Object.create(WindowManagerCore);
  wm.el = el;
  if (typeof pushEvent === "function") wm.pushEvent = pushEvent;
  return wm;
}

export function clearWindowManagerMemory() {
  rememberedLayouts.clear();
}

export default WindowManagerCore;
