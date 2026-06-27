/**
 * LiveView hook for a Win98-style desktop window manager.
 *
 * Mounted on a `.desktop` container (see the `Desktop` component family). Owns all
 * window chrome state on the client — position, size, z-order, minimize/maximize,
 * open/closed — and persists it to localStorage keyed by `data-persist-key`.
 *
 * Windows, their taskbar buttons and Start-menu entries are wired purely through
 * data attributes, so the hook is generic and reusable:
 *   - `[data-window-id]`            a window (with `data-window-default-*` geometry)
 *   - `[data-window-titlebar]`      drag handle inside a window
 *   - `[data-window-resize]`        resize grip inside a window
 *   - `[data-window-control=...]`   minimize | maximize | restore | close button
 *   - `[data-window-taskbar=<id>]`  taskbar button targeting a window
 *   - `[data-window-start]`         Start button (toggles the menu)
 *   - `[data-window-start-menu]`    Start menu popup
 *   - `[data-window-open=<id>]`     opens/focuses a window (e.g. a menu item)
 *
 * The server can drive it via `push_event("window_command", {action, id})` where
 * action is one of open | focus | flash | close | minimize | maximize.
 */
const STORAGE_PREFIX = "rhc:desktop:";
const Z_BASE = 10;
const STACK_BREAKPOINT = 720;
const EDGE_MARGIN = 40;

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

    this.handleEvent("window_command", ({ action, id }) => this.command(action, id));
  },

  updated() {
    // A server-driven DOM patch can reset the class/style we own on window roots.
    // Re-assert client-owned geometry and visibility after every patch — but never
    // mid-gesture, where the pointer handlers are already the source of truth.
    if (this.drag || this.resize) return;
    this.applyAll();
  },

  destroyed() {
    this.unbindEvents();
  },

  // ── Setup ──────────────────────────────────────────────────

  collectWindows() {
    const els = this.el.querySelectorAll("[data-window-id]");
    let order = 0;
    for (const el of els) {
      const id = el.dataset.windowId;
      const d = el.dataset;
      const open = d.windowOpen !== "false";
      this.windows[id] = {
        el,
        pinned: d.windowPinned === "true",
        minW: int(d.windowMinWidth, 220),
        minH: int(d.windowMinHeight, 120),
        state: {
          open,
          minimized: false,
          maximized: false,
          x: int(d.windowDefaultX, 24),
          y: int(d.windowDefaultY, 24),
          w: int(d.windowDefaultWidth, 360),
          h: d.windowDefaultHeight ? int(d.windowDefaultHeight, null) : null,
          z: open ? (this.zCounter += 1) : Z_BASE,
        },
      };
      if (open) this.focusedId = id;
      order += 1;
    }
    this._count = order;
  },

  restore() {
    const saved = this.readStorage();
    if (!saved) return;
    for (const id in this.windows) {
      const s = saved[id];
      if (!s) continue;
      const win = this.windows[id];
      const st = win.state;
      if (typeof s.x === "number") st.x = s.x;
      if (typeof s.y === "number") st.y = s.y;
      if (typeof s.w === "number") st.w = Math.max(s.w, win.minW);
      if (typeof s.h === "number") st.h = Math.max(s.h, win.minH);
      st.maximized = !!s.maximized;
      st.minimized = !!s.minimized;
      // Pinned windows are always open; otherwise honour the saved flag.
      if (!win.pinned && typeof s.open === "boolean") st.open = s.open;
      if (st.open && !st.minimized) {
        st.z = this.zCounter += 1;
        this.focusedId = id;
      }
    }
  },

  bindEvents() {
    this._onPointerDown = (e) => this.onPointerDown(e);
    this._onClick = (e) => this.onClick(e);
    this._onDblClick = (e) => this.onDblClick(e);
    this._onPointerMove = (e) => this.onPointerMove(e);
    this._onPointerUp = (e) => this.onPointerUp(e);
    this._onDocPointerDown = (e) => this.onDocPointerDown(e);
    this._onResize = () => this.onViewportResize();

    this.el.addEventListener("pointerdown", this._onPointerDown);
    this.el.addEventListener("click", this._onClick);
    this.el.addEventListener("dblclick", this._onDblClick);
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
    document.removeEventListener("pointermove", this._onPointerMove);
    document.removeEventListener("pointerup", this._onPointerUp);
    document.removeEventListener("pointerdown", this._onDocPointerDown, true);
    window.removeEventListener("resize", this._onResize);
    if (this._resizeObserver) this._resizeObserver.disconnect();
    if (this._rafResize) cancelAnimationFrame(this._rafResize);
  },

  // ── Pointer interactions (drag / resize / focus) ───────────

  onPointerDown(e) {
    if (e.button !== 0) return;

    const resizeH = e.target.closest("[data-window-resize]");
    if (resizeH && !this.stacked) {
      const id = this.windowIdOf(resizeH);
      this.focusWindow(id);
      this.startResize(e, id);
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
    this.drag = { id, px: e.clientX, py: e.clientY, ox: st.x, oy: st.y };
  },

  startResize(e, id) {
    e.preventDefault();
    const st = this.windows[id].state;
    const rect = this.windows[id].el.getBoundingClientRect();
    this.resize = {
      id,
      px: e.clientX,
      py: e.clientY,
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
      st.w = Math.max(win.minW, this.resize.ow + (e.clientX - this.resize.px));
      st.h = Math.max(win.minH, this.resize.oh + (e.clientY - this.resize.py));
      this.applyWindow(this.resize.id);
    }
  },

  onPointerUp() {
    if (this.drag || this.resize) {
      this.drag = null;
      this.resize = null;
      this.persist();
    }
  },

  // ── Click interactions (controls / taskbar / start menu) ───

  onClick(e) {
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
      this.onTaskbarClick(taskBtn.dataset.windowTaskbar);
      return;
    }

    if (e.target.closest("[data-window-start]")) {
      this.toggleStartMenu();
      return;
    }

    const opener = e.target.closest("[data-window-open]");
    if (opener) {
      this.command("open", opener.dataset.windowOpen);
      this.closeStartMenu();
      return;
    }

    // Any other click inside the start menu (e.g. a server-action item) closes it.
    if (e.target.closest("[data-window-start-menu]")) this.closeStartMenu();
  },

  onDblClick(e) {
    const shortcut = e.target.closest("[data-window-shortcut]");
    if (!shortcut) return;
    this.command("open", shortcut.dataset.windowShortcut);
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

  onTaskbarClick(id) {
    const win = this.windows[id];
    if (!win) return;
    const st = win.state;
    if (!st.open || st.minimized || this.focusedId !== id) {
      this.command("open", id);
    } else {
      this.minimizeWindow(id);
    }
  },

  // ── Window operations ──────────────────────────────────────

  command(action, id) {
    if (!this.windows[id]) return;
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
    }
  },

  openWindow(id) {
    const st = this.windows[id].state;
    st.open = true;
    st.minimized = false;
    this.clearFlash(id);
    this.focusWindow(id);
  },

  closeWindow(id) {
    const win = this.windows[id];
    if (win.pinned) return;
    win.state.open = false;
    this.clearFlash(id);
    if (this.focusedId === id) this.focusTopmost();
    this.applyAll();
    this.persist();
  },

  minimizeWindow(id) {
    this.windows[id].state.minimized = true;
    if (this.focusedId === id) this.focusTopmost();
    this.applyAll();
    this.persist();
  },

  toggleMaximize(id) {
    const st = this.windows[id].state;
    st.maximized = !st.maximized;
    this.openWindow(id);
    this.persist();
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

  // ── Rendering ──────────────────────────────────────────────

  applyAll() {
    for (const id in this.windows) this.applyWindow(id);
  },

  applyWindow(id) {
    const win = this.windows[id];
    const el = win.el;
    const st = win.state;
    const visible = st.open && !st.minimized;

    el.classList.toggle("u-hidden", !visible);
    el.classList.toggle("desktop-window--blurred", this.focusedId !== id);

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
    const stacked = this.workspaceSize().w < STACK_BREAKPOINT;
    if (stacked !== this.stacked) {
      this.stacked = stacked;
      this.el.classList.toggle("desktop--stacked", stacked);
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
