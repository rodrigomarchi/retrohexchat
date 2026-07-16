/**
 * LiveView hook for a Win98-style desktop window manager.
 *
 * Mounted on a `.desktop` container (see the `Desktop` component family). Owns all
 * window chrome state on the client — position, size, z-order, minimize/maximize,
 * open/closed — and persists it to localStorage keyed by `data-persist-key`.
 *
 * Windows, their taskbar buttons and Start-menu entries are wired purely through
 * data attributes, so the hook is generic and reusable:
 *   - `[data-window-id]`            a window (with `data-window-default-*` geometry;
 *                                   `data-window-default-maximized` starts it maximized
 *                                   when no saved layout exists;
 *                                   `data-window-default-centered` centers it in the
 *                                   workspace until the user touches it — pointerdown
 *                                   freezes the current position so the window never
 *                                   moves mid-click — or a saved layout applies)
 *   - `[data-window-titlebar]`      drag handle inside a window
 *   - `[data-window-resize=<dir>]`  resize handle (n|s|e|w|ne|nw|se|sw; bare = se)
 *   - `[data-window-control=...]`   minimize | maximize | restore | close button
 *   - `[data-window-taskbar=<id>]`  taskbar button targeting a window
 *   - `[data-window-start]`         Start button (toggles the menu)
 *   - `[data-window-start-menu]`    Start menu popup
 *   - `[data-window-open=<id>]`     opens/focuses a window (e.g. a menu item)
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
 * registered (honouring any saved layout), replaced nodes are re-bound keeping
 * their client state, and removed windows are pruned. A window marked
 * `data-window-managed` has a server-owned lifecycle (presence in the DOM means
 * open): opening one that is not in the DOM pushes `"window_open"` and closing
 * it client-side pushes `"window_closed"`, so the host can mount/unmount its
 * island. Hosts with managed windows must handle both events.
 */
const STORAGE_PREFIX = "rhc:desktop:";
const Z_BASE = 10;
const STACK_BREAKPOINT = 768;
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
  '[phx-show-modal][data-state="open"], [data-escape-guard]:not(.u-hidden)';

const WindowManagerHook = {
  mounted() {
    this.workspace = this.el.querySelector(".desktop__workspace");
    this.persistKey = this.el.dataset.persistKey || null;
    this.persistEnabled = this.el.dataset.persist !== "false";
    this.zCounter = Z_BASE;
    this.focusedId = null;
    this.stacked = false;
    this.drag = null;
    this.resize = null;
    this.windows = {};
    this.pendingWindows = {};
    this.menuWindowId = null;
    this._ghosts = new Set();
    this.reducedMotion =
      typeof window.matchMedia === "function" &&
      window.matchMedia("(prefers-reduced-motion: reduce)").matches;

    // Persistence disabled: wipe any stale saved layout so we always open from the
    // default layout (and a layout saved by an older version can't corrupt the
    // current desktop). In-session window state still lives in memory.
    if (this.persistKey && !this.persistEnabled) {
      try {
        localStorage.removeItem(STORAGE_PREFIX + this.persistKey);
      } catch {
        // best-effort
      }
    }

    this.collectWindows();
    this.restore();
    this.bindEvents();
    this.updateStacking();
    this.applyAll();

    this.handleEvent("window_command", (payload = {}) =>
      this.command(payload.action, payload.id, null, payload),
    );
  },

  updated() {
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
    for (const el of this.el.querySelectorAll("[data-window-id]")) {
      const id = el.dataset.windowId;
      present.add(id);
      this.clearPendingWindow(id);
      if (!this.windows[id]) {
        this.registerWindow(el);
        const saved = this.readStorage();
        if (saved && saved[id]) this.applySavedState(id, saved[id]);
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
        // registerWindow claimed focus before the saved layout marked the
        // window minimized — hand focus back to a visible window.
        this.focusTopmost();
      }
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

  destroyed() {
    this.unbindEvents();
    for (const pending of Object.values(this.pendingWindows)) {
      clearTimeout(pending.timer);
      pending.el.remove();
    }
    this.pendingWindows = {};
  },

  // ── Setup ──────────────────────────────────────────────────

  collectWindows() {
    for (const el of this.el.querySelectorAll("[data-window-id]")) this.registerWindow(el);
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
      // starts from the default geometry (session windows).
      ephemeral: d.windowEphemeral === "true",
      minW: int(d.windowMinWidth, 220),
      minH: int(d.windowMinHeight, 120),
      state: {
        open,
        minimized: false,
        // Default only — a saved layout overrides it in applySavedState. The
        // default_* geometry stays populated either way, so restoring from a
        // default-maximized window lands on sane coordinates.
        maximized: d.windowDefaultMaximized === "true",
        // Centered geometry is computed lazily in applyWindow (the workspace may
        // have no laid-out size at mount); cleared once anything else takes
        // ownership of the position (drag, resize, cascade/tile, saved layout).
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
    const saved = this.readStorage();
    if (!saved) return;
    for (const id in this.windows) {
      if (!saved[id]) continue;
      this.applySavedState(id, saved[id]);
      const st = this.windows[id].state;
      if (st.open && !st.minimized) {
        st.z = this.zCounter += 1;
        this.focusedId = id;
      }
    }
  },

  applySavedState(id, s) {
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
    // already means open (the server owns that flag); otherwise honour storage.
    if (!win.pinned && !win.managed && typeof s.open === "boolean") st.open = s.open;
  },

  bindEvents() {
    this._onPointerDown = (e) => this.onPointerDown(e);
    this._onClick = (e) => this.onClick(e);
    this._onDblClick = (e) => this.onDblClick(e);
    this._onContextMenu = (e) => this.onContextMenu(e);
    this._onKeyDown = (e) => this.onKeyDown(e);
    this._onPointerMove = (e) => this.onPointerMove(e);
    this._onPointerUp = (e) => this.onPointerUp(e);
    this._onDocPointerDown = (e) => this.onDocPointerDown(e);
    this._onResize = () => this.onViewportResize();

    this.el.addEventListener("pointerdown", this._onPointerDown);
    this.el.addEventListener("click", this._onClick);
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
    this.resetStackedScroll();

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

    const taskBtn = e.target.closest("[data-window-taskbar]");
    if (taskBtn) {
      this.onTaskbarClick(taskBtn.dataset.windowTaskbar, taskBtn);
      return;
    }

    if (e.target.closest("[data-window-start]")) {
      this.toggleStartMenu();
      return;
    }

    const opener = e.target.closest("[data-window-open]");
    if (opener) {
      // Window roots used to carry data-window-open as initial state. Keep this
      // guard so a click inside a window can never be mistaken for an opener.
      if (opener.hasAttribute("data-window-id")) return;
      // A disabled menu item still carries data-window-open (it's a <li>, not a
      // <button>) — it must not act.
      if (opener.getAttribute("aria-disabled") === "true" || opener.disabled) return;
      this.command("open", opener.dataset.windowOpen, opener);
      this.closeStartMenu();
      return;
    }

    // Any other click inside the start menu (e.g. a server-action item) closes it.
    if (e.target.closest("[data-window-start-menu]")) this.closeStartMenu();
  },

  onDblClick(e) {
    const shortcut = e.target.closest("[data-window-shortcut]");
    if (shortcut) {
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
    for (const menu of this.el.querySelectorAll("[data-taskbar-menu]")) {
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

    // An open WM menu owns the press: close it and consume the event so the
    // server's window-level Escape ladder cannot also dismiss something.
    if (this.anyMenuOpen()) {
      e.stopPropagation();
      this.closeTaskbarMenus();
      this.closeStartMenu();
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

  anyMenuOpen() {
    const start = this.startMenu();
    if (start && !start.classList.contains("u-hidden")) return true;
    for (const menu of this.el.querySelectorAll("[data-taskbar-menu]")) {
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
    const selected = this.el.querySelectorAll("[data-window-shortcut].is-selected");
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
    if (wasMinimized) {
      const btn = this.taskbarButton(id);
      if (btn) this.animateZoom(btn.getBoundingClientRect(), win.el.getBoundingClientRect());
    }
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
    this.focusedId = id;
    win.state.z = this.zCounter += 1;
    this.applyAll();
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
    const btn = this.taskbarButton(id);
    if (btn) btn.classList.add("is-flashing");
  },

  clearFlash(id) {
    const btn = this.taskbarButton(id);
    if (btn) btn.classList.remove("is-flashing");
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

    el.classList.toggle("u-hidden", !visible);
    el.classList.toggle("desktop-window--blurred", this.focusedId !== id);
    el.classList.toggle("desktop-window--maximized", st.maximized);

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
        this.setGeom(el, st.x, st.y, st.w, st.h, st.z);
      }
    }

    const maxBtn = el.querySelector('[data-window-control="maximize"]');
    const resBtn = el.querySelector('[data-window-control="restore"]');
    if (maxBtn) maxBtn.classList.toggle("u-hidden", st.maximized);
    if (resBtn) resBtn.classList.toggle("u-hidden", !st.maximized);

    this.updateTaskbar(id);
  },

  updateTaskbar(id) {
    const btn = this.taskbarButton(id);
    if (!btn) return;
    const st = this.windows[id].state;
    btn.classList.toggle("u-hidden", !st.open);
    btn.classList.toggle("is-active", st.open && !st.minimized && this.focusedId === id);
    if (st.open && !st.minimized && this.focusedId === id) {
      btn.classList.remove("is-flashing");
    }
  },

  // ── Start menu ─────────────────────────────────────────────

  startMenu() {
    return this.el.querySelector("[data-window-start-menu]");
  },

  toggleStartMenu() {
    const menu = this.startMenu();
    if (menu) menu.classList.toggle("u-hidden");
  },

  closeStartMenu() {
    const menu = this.startMenu();
    if (menu) menu.classList.add("u-hidden");
  },

  onDocPointerDown(e) {
    if (!e.target.closest("[data-taskbar-menu]")) this.closeTaskbarMenus();

    const menu = this.startMenu();
    if (!menu || menu.classList.contains("u-hidden")) return;
    if (e.target.closest("[data-window-start-menu]") || e.target.closest("[data-window-start]")) {
      return;
    }
    this.closeStartMenu();
  },

  // ── Responsive stacking ────────────────────────────────────

  onViewportResize() {
    if (this._rafResize) cancelAnimationFrame(this._rafResize);
    this._rafResize = requestAnimationFrame(() => {
      this.updateStacking();
      this.applyAll();
    });
  },

  updateStacking() {
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
      this.resetStackedScroll();
      requestAnimationFrame(() => this.resetStackedScroll());
    }
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

  workspaceSize() {
    const node = this.workspace || this.el;
    return { w: node.clientWidth, h: node.clientHeight };
  },

  setGeom(el, x, y, w, h, z) {
    el.style.setProperty("--win-x", `${x}px`);
    el.style.setProperty("--win-y", `${y}px`);
    el.style.setProperty("--win-w", `${w}px`);
    if (h) el.style.setProperty("--win-h", `${h}px`);
    else el.style.removeProperty("--win-h");
    el.style.setProperty("--win-z", String(z || Z_BASE));
  },

  clearGeom(el) {
    for (const prop of ["--win-x", "--win-y", "--win-w", "--win-h", "--win-z"]) {
      el.style.removeProperty(prop);
    }
  },

  windowIdOf(node) {
    const winEl = node.closest("[data-window-id]");
    return winEl ? winEl.dataset.windowId : null;
  },

  taskbarButton(id) {
    return this.el.querySelector(`[data-window-taskbar="${cssEscape(id)}"]`);
  },

  readStorage() {
    if (!this.persistKey || !this.persistEnabled) return null;
    try {
      const raw = localStorage.getItem(STORAGE_PREFIX + this.persistKey);
      return raw ? JSON.parse(raw) : null;
    } catch {
      return null;
    }
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
    try {
      localStorage.setItem(STORAGE_PREFIX + this.persistKey, JSON.stringify(data));
    } catch {
      // Ignore quota / privacy-mode failures — layout persistence is best-effort.
    }
  },
};

function int(value, fallback) {
  const n = parseInt(value, 10);
  return Number.isNaN(n) ? fallback : n;
}

function clamp(value, min, max) {
  return Math.min(Math.max(value, min), max);
}

function cssEscape(value) {
  if (window.CSS && typeof window.CSS.escape === "function") return window.CSS.escape(value);
  return String(value).replace(/["\\]/g, "\\$&");
}

export default WindowManagerHook;
