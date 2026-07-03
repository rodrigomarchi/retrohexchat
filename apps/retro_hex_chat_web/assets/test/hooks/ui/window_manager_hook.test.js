import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import WindowManagerHook from "../../../js/hooks/ui/window_manager_hook";

function windowMarkup(id, { pinned = false, open = true, defaultMaximized = false } = {}) {
  const controls = pinned
    ? `<button data-window-control="minimize"></button>
       <button data-window-control="maximize"></button>
       <button data-window-control="restore"></button>`
    : `<button data-window-control="minimize"></button>
       <button data-window-control="maximize"></button>
       <button data-window-control="restore"></button>
       <button data-window-control="close"></button>`;

  return `
    <div id="${id}" data-window-id="${id}" data-window-pinned="${pinned}"
         data-window-open="${open}" data-window-default-maximized="${defaultMaximized}"
         data-window-default-x="20" data-window-default-y="20"
         data-window-default-width="300" data-window-min-width="200" data-window-min-height="120">
      <div data-window-titlebar>${controls}</div>
      <div data-window-content></div>
      <button data-window-resize></button>
      <span data-window-resize="w"></span>
      <span data-window-resize="n"></span>
    </div>`;
}

function taskbarMenusMarkup() {
  return `
    <div data-taskbar-menu="window" class="u-hidden">
      <li data-taskbar-menu-action="restore"></li>
      <li data-taskbar-menu-action="minimize"></li>
      <li data-taskbar-menu-action="maximize"></li>
      <li data-taskbar-menu-action="close"></li>
    </div>
    <div data-taskbar-menu="desktop" class="u-hidden">
      <li data-taskbar-menu-action="cascade"></li>
      <li data-taskbar-menu-action="tile-h"></li>
      <li data-taskbar-menu-action="tile-v"></li>
      <li data-taskbar-menu-action="minimize-all"></li>
    </div>`;
}

function buildDesktop() {
  const el = document.createElement("div");
  el.id = "lobby-desktop";
  el.dataset.persistKey = "test";
  el.innerHTML = `
    <div class="desktop__workspace">
      ${windowMarkup("conn", { pinned: true, open: true })}
      ${windowMarkup("chat", { open: true })}
      ${windowMarkup("call", { open: false })}
    </div>
    <div class="desktop-taskbar">
      <button data-window-start></button>
      <div data-window-start-menu class="u-hidden">
        <button data-window-open="call"></button>
      </div>
      <button data-window-taskbar="conn"></button>
      <button data-window-taskbar="chat"></button>
      <button data-window-taskbar="call"></button>
      ${taskbarMenusMarkup()}
    </div>`;
  document.body.appendChild(el);
  return el;
}

describe("WindowManagerHook", () => {
  let hook;
  let el;
  let command;

  beforeEach(() => {
    const store = new Map();
    vi.stubGlobal("localStorage", {
      getItem: (k) => (store.has(k) ? store.get(k) : null),
      setItem: (k, v) => store.set(k, String(v)),
      removeItem: (k) => store.delete(k),
      clear: () => store.clear(),
    });

    el = buildDesktop();
    command = null;
    hook = {
      ...WindowManagerHook,
      el,
      handleEvent: vi.fn((name, cb) => {
        if (name === "window_command") command = cb;
      }),
    };
    hook.workspaceSize = () => ({ w: 1024, h: 768 }); // jsdom has no layout
    hook.mounted();
  });

  afterEach(() => {
    hook.destroyed();
    el.remove();
    vi.unstubAllGlobals();
  });

  const win = (id) => document.getElementById(id);
  const taskbarBtn = (id) => el.querySelector(`[data-window-taskbar="${id}"]`);

  it("collects every window and honours initial open state", () => {
    hook.stacked = false; // desktop mode: every open window is visible at once
    hook.applyAll();
    expect(Object.keys(hook.windows).sort()).toEqual(["call", "chat", "conn"]);
    expect(win("conn").classList.contains("u-hidden")).toBe(false);
    expect(win("call").classList.contains("u-hidden")).toBe(true);
  });

  it("hides the taskbar button of a closed window", () => {
    expect(taskbarBtn("chat").classList.contains("u-hidden")).toBe(false);
    expect(taskbarBtn("call").classList.contains("u-hidden")).toBe(true);
  });

  it("opens a window via a server window_command", () => {
    expect(typeof command).toBe("function");
    command({ action: "open", id: "call" });

    expect(hook.windows.call.state.open).toBe(true);
    expect(win("call").classList.contains("u-hidden")).toBe(false);
    expect(taskbarBtn("call").classList.contains("u-hidden")).toBe(false);
  });

  it("minimizing hides the window but keeps it open", () => {
    command({ action: "open", id: "call" });
    hook.minimizeWindow("call");

    expect(hook.windows.call.state.open).toBe(true);
    expect(hook.windows.call.state.minimized).toBe(true);
    expect(win("call").classList.contains("u-hidden")).toBe(true);
  });

  it("never closes a pinned window", () => {
    hook.closeWindow("conn");
    expect(hook.windows.conn.state.open).toBe(true);
  });

  it("closes a non-pinned window", () => {
    command({ action: "open", id: "call" });
    hook.closeWindow("call");
    expect(hook.windows.call.state.open).toBe(false);
    expect(win("call").classList.contains("u-hidden")).toBe(true);
  });

  describe("stacked (mobile) mode", () => {
    it("shows only the focused window, hiding other open windows", () => {
      hook.stacked = true;
      hook.focusWindow("chat");

      expect(hook.focusedId).toBe("chat");
      expect(win("chat").classList.contains("u-hidden")).toBe(false);
      // conn is open (pinned) but not focused — hidden in the single-window layout.
      expect(win("conn").classList.contains("u-hidden")).toBe(true);
      expect(win("call").classList.contains("u-hidden")).toBe(true);
    });

    it("opening a window makes it the sole visible window", () => {
      hook.stacked = true;
      command({ action: "open", id: "call" });

      expect(hook.focusedId).toBe("call");
      expect(win("call").classList.contains("u-hidden")).toBe(false);
      expect(win("chat").classList.contains("u-hidden")).toBe(true);
      expect(win("conn").classList.contains("u-hidden")).toBe(true);
    });

    it("falls back to another open window when the focused one closes", () => {
      hook.stacked = true;
      command({ action: "open", id: "call" });
      hook.closeWindow("call");

      expect(hook.focusedId).not.toBe("call");
      expect(["chat", "conn"]).toContain(hook.focusedId);
      expect(win(hook.focusedId).classList.contains("u-hidden")).toBe(false);
    });

    it("entering stacked mode focuses the topmost open window when none is focused", () => {
      const originalWidth = window.innerWidth;
      window.innerWidth = 375; // a phone-sized viewport, below the breakpoint
      try {
        hook.stacked = false;
        hook.focusedId = null;
        hook.updateStacking();

        expect(hook.stacked).toBe(true);
        expect(hook.focusedId).not.toBeNull();
        expect(hook.windows[hook.focusedId].state.open).toBe(true);
      } finally {
        window.innerWidth = originalWidth;
      }
    });
  });

  it("toggles maximize and swaps the maximize/restore controls", () => {
    command({ action: "open", id: "call" });
    hook.toggleMaximize("call");

    expect(hook.windows.call.state.maximized).toBe(true);
    const maxBtn = win("call").querySelector('[data-window-control="maximize"]');
    const resBtn = win("call").querySelector('[data-window-control="restore"]');
    expect(maxBtn.classList.contains("u-hidden")).toBe(true);
    expect(resBtn.classList.contains("u-hidden")).toBe(false);

    hook.toggleMaximize("call");
    expect(hook.windows.call.state.maximized).toBe(false);
  });

  it("restores the pre-maximize geometry when unmaximizing", () => {
    command({ action: "open", id: "call" });
    const st = hook.windows.call.state;
    st.x = 60;
    st.y = 80;
    st.w = 400;

    hook.toggleMaximize("call");
    expect(win("call").classList.contains("desktop-window--maximized")).toBe(true);

    hook.toggleMaximize("call");
    expect(win("call").classList.contains("desktop-window--maximized")).toBe(false);
    expect(st.x).toBe(60);
    expect(st.y).toBe(80);
    expect(st.w).toBe(400);
  });

  it("toggles maximize on a title bar double-click", () => {
    command({ action: "open", id: "call" });
    hook.stacked = false; // jsdom has no layout; force the desktop (non-stacked) mode

    const titlebar = win("call").querySelector("[data-window-titlebar]");
    titlebar.dispatchEvent(new MouseEvent("dblclick", { bubbles: true }));
    expect(hook.windows.call.state.maximized).toBe(true);

    titlebar.dispatchEvent(new MouseEvent("dblclick", { bubbles: true }));
    expect(hook.windows.call.state.maximized).toBe(false);
  });

  it("does not toggle maximize when double-clicking a control button", () => {
    command({ action: "open", id: "call" });
    hook.stacked = false;

    const minBtn = win("call").querySelector('[data-window-control="minimize"]');
    minBtn.dispatchEvent(new MouseEvent("dblclick", { bubbles: true }));
    expect(hook.windows.call.state.maximized).toBe(false);
  });

  it("does not start a resize gesture on a maximized window", () => {
    command({ action: "open", id: "call" });
    hook.stacked = false;
    hook.toggleMaximize("call");

    const grip = win("call").querySelector("[data-window-resize]");
    grip.dispatchEvent(new MouseEvent("pointerdown", { bubbles: true, button: 0 }));
    expect(hook.resize).toBe(null);
  });

  it("resizes from the west edge, keeping the right edge fixed and clamping at min width", () => {
    command({ action: "open", id: "call" });
    hook.stacked = false;
    hook.workspaceSize = () => ({ w: 800, h: 600 }); // jsdom has no layout

    // Defaults from the markup: x=20, w=300, minW=200 — the right edge sits at 320.
    const handle = win("call").querySelector('[data-window-resize="w"]');
    handle.dispatchEvent(
      new MouseEvent("pointerdown", { bubbles: true, button: 0, clientX: 100, clientY: 50 }),
    );
    expect(hook.resize.dir).toBe("w");

    document.dispatchEvent(new MouseEvent("pointermove", { clientX: 80, clientY: 50 }));
    expect(hook.windows.call.state.w).toBe(320);
    expect(hook.windows.call.state.x).toBe(0);

    document.dispatchEvent(new MouseEvent("pointermove", { clientX: 250, clientY: 50 }));
    expect(hook.windows.call.state.w).toBe(200);
    expect(hook.windows.call.state.x).toBe(120);

    document.dispatchEvent(new MouseEvent("pointerup", {}));
    expect(hook.resize).toBe(null);
  });

  it("resizes from the north edge, keeping the bottom edge fixed and clamping at min height", () => {
    command({ action: "open", id: "call" });
    hook.stacked = false;
    hook.workspaceSize = () => ({ w: 800, h: 600 });
    const st = hook.windows.call.state;
    st.h = 200; // markup has auto height; the bottom edge sits at y=20+200=220

    const handle = win("call").querySelector('[data-window-resize="n"]');
    handle.dispatchEvent(
      new MouseEvent("pointerdown", { bubbles: true, button: 0, clientX: 50, clientY: 100 }),
    );

    document.dispatchEvent(new MouseEvent("pointermove", { clientX: 50, clientY: 90 }));
    expect(st.h).toBe(210);
    expect(st.y).toBe(10);

    document.dispatchEvent(new MouseEvent("pointermove", { clientX: 50, clientY: 400 }));
    expect(st.h).toBe(120);
    expect(st.y).toBe(100);

    document.dispatchEvent(new MouseEvent("pointerup", {}));
  });

  const windowMenu = () => el.querySelector('[data-taskbar-menu="window"]');
  const desktopMenu = () => el.querySelector('[data-taskbar-menu="desktop"]');
  const menuItem = (menu, action) => menu.querySelector(`[data-taskbar-menu-action="${action}"]`);

  it("opens the window menu on taskbar-button right-click with state-aware items", () => {
    command({ action: "open", id: "call" });

    taskbarBtn("call").dispatchEvent(new MouseEvent("contextmenu", { bubbles: true }));
    expect(windowMenu().classList.contains("u-hidden")).toBe(false);
    expect(hook.menuWindowId).toBe("call");
    // Visible + not maximized: restore is inapplicable, everything else applies.
    expect(menuItem(windowMenu(), "restore").getAttribute("aria-disabled")).toBe("true");
    expect(menuItem(windowMenu(), "minimize").hasAttribute("aria-disabled")).toBe(false);
    expect(menuItem(windowMenu(), "maximize").hasAttribute("aria-disabled")).toBe(false);
    expect(menuItem(windowMenu(), "close").hasAttribute("aria-disabled")).toBe(false);

    // A pinned window never offers close.
    taskbarBtn("conn").dispatchEvent(new MouseEvent("contextmenu", { bubbles: true }));
    expect(menuItem(windowMenu(), "close").getAttribute("aria-disabled")).toBe("true");
  });

  it("applies a window-menu action to the right-clicked window and closes the menu", () => {
    command({ action: "open", id: "call" });

    taskbarBtn("call").dispatchEvent(new MouseEvent("contextmenu", { bubbles: true }));
    menuItem(windowMenu(), "minimize").dispatchEvent(new MouseEvent("click", { bubbles: true }));

    expect(hook.windows.call.state.minimized).toBe(true);
    expect(windowMenu().classList.contains("u-hidden")).toBe(true);
    expect(hook.menuWindowId).toBe(null);
  });

  it("opens the desktop menu on empty-taskbar right-click and minimizes all windows", () => {
    command({ action: "open", id: "call" });

    el.querySelector(".desktop-taskbar").dispatchEvent(
      new MouseEvent("contextmenu", { bubbles: true }),
    );
    expect(desktopMenu().classList.contains("u-hidden")).toBe(false);

    menuItem(desktopMenu(), "minimize-all").dispatchEvent(
      new MouseEvent("click", { bubbles: true }),
    );
    for (const id of ["conn", "chat", "call"]) {
      expect(hook.windows[id].state.minimized).toBe(true);
    }
  });

  it("cascades visible windows into a staggered stack", () => {
    command({ action: "open", id: "call" });
    hook.workspaceSize = () => ({ w: 800, h: 600 });

    el.querySelector(".desktop-taskbar").dispatchEvent(
      new MouseEvent("contextmenu", { bubbles: true }),
    );
    menuItem(desktopMenu(), "cascade").dispatchEvent(new MouseEvent("click", { bubbles: true }));

    // z-order at this point: conn, chat, call (call was focused last).
    ["conn", "chat", "call"].forEach((id, i) => {
      const st = hook.windows[id].state;
      expect(st.maximized).toBe(false);
      expect(st.x).toBe(i * 26);
      expect(st.y).toBe(i * 26);
      expect(st.w).toBe(480);
      expect(st.h).toBe(360);
    });
    expect(hook.focusedId).toBe("call");
  });

  it("tiles visible windows horizontally as full-width rows", () => {
    command({ action: "open", id: "call" });
    hook.workspaceSize = () => ({ w: 800, h: 600 });

    hook.tileWindows("h");

    ["conn", "chat", "call"].forEach((id, i) => {
      const st = hook.windows[id].state;
      expect(st.x).toBe(0);
      expect(st.y).toBe(i * 200);
      expect(st.w).toBe(800);
      expect(st.h).toBe(200);
    });
  });

  it("tiles visible windows vertically as full-height columns", () => {
    command({ action: "open", id: "call" });
    hook.workspaceSize = () => ({ w: 900, h: 600 });

    hook.tileWindows("v");

    ["conn", "chat", "call"].forEach((id, i) => {
      const st = hook.windows[id].state;
      expect(st.x).toBe(i * 300);
      expect(st.y).toBe(0);
      expect(st.w).toBe(300);
      expect(st.h).toBe(600);
    });
  });

  it("closes taskbar menus on Escape", () => {
    el.querySelector(".desktop-taskbar").dispatchEvent(
      new MouseEvent("contextmenu", { bubbles: true }),
    );
    expect(desktopMenu().classList.contains("u-hidden")).toBe(false);

    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }));
    expect(desktopMenu().classList.contains("u-hidden")).toBe(true);
  });

  it("plays a zoom wireframe on minimize and removes it after the transition", () => {
    hook.stacked = false;
    hook.reducedMotion = false;
    win("chat").getBoundingClientRect = () => ({ left: 30, top: 40, width: 200, height: 150 });
    taskbarBtn("chat").getBoundingClientRect = () => ({
      left: 5,
      top: 500,
      width: 80,
      height: 20,
    });

    hook.minimizeWindow("chat");

    const ghost = el.querySelector(".desktop-zoom");
    expect(ghost).not.toBe(null);
    // Both keyframes were applied synchronously; the ghost ends at the button rect.
    expect(ghost.style.getPropertyValue("--zoom-x")).toBe("5px");
    expect(ghost.style.getPropertyValue("--zoom-w")).toBe("80px");

    ghost.dispatchEvent(new Event("transitionend"));
    expect(el.querySelector(".desktop-zoom")).toBe(null);
  });

  it("skips the zoom animation when the user prefers reduced motion", () => {
    hook.stacked = false;
    hook.reducedMotion = true;
    win("chat").getBoundingClientRect = () => ({ left: 30, top: 40, width: 200, height: 150 });

    hook.minimizeWindow("chat");
    expect(el.querySelector(".desktop-zoom")).toBe(null);
  });

  it("does not client-close a window whose X is wired to a server event", () => {
    command({ action: "open", id: "call" });
    const closeBtn = win("call").querySelector('[data-window-control="close"]');
    closeBtn.setAttribute("phx-click", "end_call");

    closeBtn.click();

    // The hook must defer to LiveView (which ends the feature, then closes the
    // window via a window_command) rather than hiding it client-side.
    expect(hook.windows.call.state.open).toBe(true);
    expect(win("call").classList.contains("u-hidden")).toBe(false);
  });

  it("toggles the Start menu when the Start button is clicked", () => {
    const menu = el.querySelector("[data-window-start-menu]");
    expect(menu.classList.contains("u-hidden")).toBe(true);

    el.querySelector("[data-window-start]").click();
    expect(menu.classList.contains("u-hidden")).toBe(false);
  });

  it("opens a window from a Start-menu item and closes the menu", () => {
    const menu = el.querySelector("[data-window-start-menu]");
    menu.classList.remove("u-hidden");

    el.querySelector('[data-window-open="call"]').click();

    expect(hook.windows.call.state.open).toBe(true);
    expect(menu.classList.contains("u-hidden")).toBe(true);
  });

  it("persists window state to localStorage", () => {
    command({ action: "open", id: "call" });
    const saved = JSON.parse(localStorage.getItem("rhc:desktop:test"));
    expect(saved.call.open).toBe(true);
    expect(saved.conn.open).toBe(true);
  });

  it("keeps other windows visible when a server patch lands mid-drag", () => {
    hook.stacked = false; // dragging only exists in desktop (multi-window) mode
    command({ action: "open", id: "call" }); // conn, chat and call all visible

    // Start dragging chat.
    hook.drag = { id: "chat", px: 0, py: 0, ox: 20, oy: 20 };

    // A server patch re-renders the pinned conn window, resetting its class to the
    // server default (which always includes `u-hidden`).
    win("conn").classList.add("u-hidden");
    hook.updated();

    // The non-dragged window must be re-asserted, not left hidden.
    expect(win("conn").classList.contains("u-hidden")).toBe(false);

    hook.drag = null;
  });

  it("re-asserts every window's visibility on pointer up", () => {
    hook.stacked = false; // dragging only exists in desktop (multi-window) mode
    command({ action: "open", id: "call" });

    hook.drag = { id: "chat", px: 0, py: 0, ox: 20, oy: 20 };
    // A patch clobbers the dragged window mid-gesture (updated() skips it).
    win("chat").classList.add("u-hidden");
    hook.updated();
    expect(win("chat").classList.contains("u-hidden")).toBe(true);

    // Releasing the pointer restores it immediately.
    hook.onPointerUp();
    expect(win("chat").classList.contains("u-hidden")).toBe(false);
  });

  it("restores saved open state on a fresh mount", () => {
    localStorage.setItem(
      "rhc:desktop:test",
      JSON.stringify({ call: { open: true, minimized: false, maximized: false } }),
    );

    const fresh = { ...WindowManagerHook, el, handleEvent: vi.fn() };
    fresh.mounted();
    expect(fresh.windows.call.state.open).toBe(true);
    fresh.destroyed();
  });
});

describe("WindowManagerHook — dynamic windows (reconciliation)", () => {
  let el;
  let hook;

  beforeEach(() => {
    vi.stubGlobal("localStorage", {
      getItem: () => null,
      setItem: () => {},
      removeItem: () => {},
      clear: () => {},
    });

    el = buildDesktop();
    el.dataset.persist = "false";
    hook = { ...WindowManagerHook, el, handleEvent: vi.fn(), pushEvent: vi.fn() };
    hook.workspaceSize = () => ({ w: 1024, h: 768 }); // jsdom has no layout
    hook.mounted();
  });

  afterEach(() => {
    hook.destroyed();
    el.remove();
    vi.unstubAllGlobals();
  });

  const workspace = () => el.querySelector(".desktop__workspace");

  it("registers a window patched in after mount and focuses it", () => {
    workspace().insertAdjacentHTML("beforeend", windowMarkup("game", { open: true }));
    hook.updated();

    expect(hook.windows.game).toBeTruthy();
    expect(hook.focusedId).toBe("game");
    expect(document.getElementById("game").classList.contains("u-hidden")).toBe(false);

    // Once registered, it behaves like any other window.
    hook.minimizeWindow("game");
    expect(hook.windows.game.state.minimized).toBe(true);
  });

  it("prunes a window removed by a patch and moves focus to the topmost survivor", () => {
    hook.focusWindow("chat");
    document.getElementById("chat").remove();
    hook.updated();

    expect(hook.windows.chat).toBeUndefined();
    expect(hook.focusedId).toBe("conn");
  });

  it("re-binds a window whose root node was replaced, keeping its client state", () => {
    const st = hook.windows.chat.state;
    st.x = 111;

    const old = document.getElementById("chat");
    old.insertAdjacentHTML("afterend", windowMarkup("chat", { open: true }));
    old.remove();
    hook.updated();

    expect(hook.windows.chat.el).toBe(document.getElementById("chat"));
    expect(hook.windows.chat.state.x).toBe(111);
  });

  it("cancels an active gesture when the dragged window is pruned", () => {
    hook.drag = { id: "chat", px: 0, py: 0, ox: 20, oy: 20 };
    document.getElementById("chat").remove();
    hook.updated();

    expect(hook.drag).toBe(null);
  });

  it("hands focus to a visible window when the arrival is restored as minimized", () => {
    // Saved layouts can mark a late-arriving window minimized; registerWindow
    // claims focus before the saved state applies, so reconcile must hand it back.
    hook.focusWindow("chat");
    workspace().insertAdjacentHTML("beforeend", windowMarkup("game", { open: true }));
    hook.readStorage = () => ({ game: { minimized: true } });
    hook.updated();

    expect(hook.windows.game.state.minimized).toBe(true);
    expect(hook.focusedId).toBe("chat");
  });

  it("ignores a disabled window opener", () => {
    const opener = document.createElement("button");
    opener.dataset.windowOpen = "call";
    opener.setAttribute("aria-disabled", "true");
    el.appendChild(opener);

    opener.click();
    expect(hook.windows.call.state.open).toBe(false);
    expect(hook.pushEvent).not.toHaveBeenCalled();
  });

  it("asks the server to mount an unknown window instead of failing silently", () => {
    hook.command("open", "game-x");
    expect(hook.pushEvent).toHaveBeenCalledWith("window_open", { id: "game-x" });

    // Non-open actions on unknown windows stay no-ops.
    hook.pushEvent.mockClear();
    hook.command("close", "game-x");
    expect(hook.pushEvent).not.toHaveBeenCalled();
  });

  it("shows a pending window while an unknown managed window is being mounted", () => {
    const opener = document.createElement("button");
    opener.textContent = "Games";

    hook.command("open", "game-x", opener);

    const pending = workspace().querySelector('[data-window-pending-id="game-x"]');
    expect(pending).toBeTruthy();
    expect(pending.textContent).toContain("Games");
    expect(pending.textContent).toContain("Opening...");

    workspace().insertAdjacentHTML("beforeend", windowMarkup("game-x", { open: true }));
    hook.updated();

    expect(workspace().querySelector('[data-window-pending-id="game-x"]')).toBeNull();
    expect(hook.windows["game-x"]).toBeTruthy();
  });

  it("notifies the server when a managed window is closed client-side", () => {
    workspace().insertAdjacentHTML("beforeend", windowMarkup("game", { open: true }));
    document.getElementById("game").dataset.windowManaged = "true";
    hook.updated();

    hook.closeWindow("game");
    expect(hook.pushEvent).toHaveBeenCalledWith("window_closed", { id: "game" });
    // Hidden immediately for snappy feedback; the server patch unmounts it after.
    expect(document.getElementById("game").classList.contains("u-hidden")).toBe(true);

    // Static windows close silently on the client.
    hook.pushEvent.mockClear();
    hook.closeWindow("chat");
    expect(hook.pushEvent).not.toHaveBeenCalled();
  });
});

describe("WindowManagerHook — persistence opt-out", () => {
  let store;

  beforeEach(() => {
    store = new Map();
    vi.stubGlobal("localStorage", {
      getItem: (k) => (store.has(k) ? store.get(k) : null),
      setItem: (k, v) => store.set(k, String(v)),
      removeItem: (k) => store.delete(k),
      clear: () => store.clear(),
    });
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("clears stale saved state on mount and never writes when persistence is off", () => {
    store.set("rhc:desktop:test", JSON.stringify({ call: { open: true } }));

    const el = buildDesktop();
    el.dataset.persist = "false";
    const hook = { ...WindowManagerHook, el, handleEvent: vi.fn() };
    hook.mounted();

    // The old layout was wiped on open...
    expect(store.has("rhc:desktop:test")).toBe(false);
    // ...the saved "call open" was ignored (default layout: call starts closed)...
    expect(hook.windows.call.state.open).toBe(false);

    // ...and opening a window does not write anything back.
    hook.openWindow("call");
    expect(store.has("rhc:desktop:test")).toBe(false);

    hook.destroyed();
    el.remove();
  });
});

describe("WindowManagerHook — Escape closes the focused window", () => {
  let el;
  let hook;
  let windowSpy;

  const pressEscape = () =>
    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }));

  function mount({ escapeCloses = true } = {}) {
    el = buildDesktop();
    el.dataset.persist = "false";
    if (escapeCloses) el.dataset.escapeClosesWindows = "true";
    hook = { ...WindowManagerHook, el, handleEvent: vi.fn(), pushEvent: vi.fn() };
    hook.mounted();
  }

  beforeEach(() => {
    vi.stubGlobal("localStorage", {
      getItem: () => null,
      setItem: () => {},
      removeItem: () => {},
      clear: () => {},
    });
    windowSpy = vi.fn();
    window.addEventListener("keydown", windowSpy);
  });

  afterEach(() => {
    window.removeEventListener("keydown", windowSpy);
    hook.destroyed();
    el.remove();
    document.querySelectorAll("[data-escape-test]").forEach((n) => n.remove());
    vi.unstubAllGlobals();
  });

  it("closes the topmost unpinned window and stops the event", () => {
    mount();
    hook.command("open", "call"); // call is now topmost
    pressEscape();

    expect(hook.windows.call.state.open).toBe(false);
    expect(hook.windows.chat.state.open).toBe(true);
    // The press was consumed — it must not also reach the server's window
    // keydown binding and double-dismiss something there.
    expect(windowSpy).not.toHaveBeenCalled();
  });

  it("picks the topmost by z-order", () => {
    mount();
    hook.command("open", "call");
    hook.focusWindow("chat"); // chat now above call
    pressEscape();

    expect(hook.windows.chat.state.open).toBe(false);
    expect(hook.windows.call.state.open).toBe(true);
  });

  it("never closes a pinned window and lets the event through", () => {
    mount();
    hook.closeWindow("chat"); // only pinned conn remains visible
    pressEscape();

    expect(hook.windows.conn.state.open).toBe(true);
    expect(windowSpy).toHaveBeenCalled();
  });

  it("an open menu wins: Escape closes the menu, not a window", () => {
    mount();
    el.querySelector("[data-window-start-menu]").classList.remove("u-hidden");
    pressEscape();

    expect(el.querySelector("[data-window-start-menu]").classList.contains("u-hidden")).toBe(true);
    expect(hook.windows.chat.state.open).toBe(true);
  });

  it("an open modal dialog wins", () => {
    mount();
    const modal = document.createElement("div");
    modal.setAttribute("phx-show-modal", "");
    modal.setAttribute("data-state", "open");
    modal.setAttribute("data-escape-test", "");
    document.body.appendChild(modal);

    pressEscape();
    expect(hook.windows.chat.state.open).toBe(true);
    expect(windowSpy).toHaveBeenCalled();
  });

  it("a visible escape-guard overlay wins; a hidden one does not", () => {
    mount();
    const overlay = document.createElement("div");
    overlay.setAttribute("data-escape-guard", "");
    overlay.setAttribute("data-escape-test", "");
    document.body.appendChild(overlay);

    pressEscape();
    expect(hook.windows.chat.state.open).toBe(true);

    overlay.classList.add("u-hidden");
    pressEscape();
    expect(hook.windows.chat.state.open).toBe(false);
  });

  it("mirrors the X button for a server-owned close", () => {
    mount();
    const closeBtn = document.getElementById("chat").querySelector('[data-window-control="close"]');
    closeBtn.setAttribute("phx-click", "end_feature");
    const clickSpy = vi.fn();
    closeBtn.addEventListener("click", clickSpy);

    pressEscape();
    // Deferred to LiveView via the button, not client-closed.
    expect(clickSpy).toHaveBeenCalled();
    expect(hook.windows.chat.state.open).toBe(true);
  });

  it("does nothing without the desktop opt-in flag", () => {
    mount({ escapeCloses: false });
    pressEscape();

    expect(hook.windows.chat.state.open).toBe(true);
    expect(windowSpy).toHaveBeenCalled();
  });
});

describe("WindowManagerHook — default maximized", () => {
  let store;
  let el;
  let hook;

  function mountDesktop() {
    el = document.createElement("div");
    el.dataset.persistKey = "test";
    el.innerHTML = `
      <div class="desktop__workspace">
        ${windowMarkup("chat", { pinned: true, open: true, defaultMaximized: true })}
        ${windowMarkup("tools", { open: false })}
      </div>
      <div class="desktop-taskbar">
        <button data-window-taskbar="chat"></button>
        <button data-window-taskbar="tools"></button>
      </div>`;
    document.body.appendChild(el);
    hook = { ...WindowManagerHook, el, handleEvent: vi.fn() };
    hook.workspaceSize = () => ({ w: 1024, h: 768 }); // jsdom has no layout
    hook.mounted();
  }

  beforeEach(() => {
    store = new Map();
    vi.stubGlobal("localStorage", {
      getItem: (k) => (store.has(k) ? store.get(k) : null),
      setItem: (k, v) => store.set(k, String(v)),
      removeItem: (k) => store.delete(k),
      clear: () => store.clear(),
    });
  });

  afterEach(() => {
    hook.destroyed();
    el.remove();
    vi.unstubAllGlobals();
  });

  it("mounts maximized when there is no saved layout", () => {
    mountDesktop();

    expect(hook.windows.chat.state.maximized).toBe(true);
    const winEl = document.getElementById("chat");
    expect(winEl.classList.contains("desktop-window--maximized")).toBe(true);
    // Windows without the flag keep the normal default.
    expect(hook.windows.tools.state.maximized).toBe(false);
  });

  it("lets a saved layout win over the default", () => {
    store.set(
      "rhc:desktop:test",
      JSON.stringify({ chat: { open: true, maximized: false, x: 60, y: 70, w: 400, h: 300 } }),
    );
    mountDesktop();

    const st = hook.windows.chat.state;
    expect(st.maximized).toBe(false);
    expect(st.x).toBe(60);
    expect(st.y).toBe(70);
  });

  it("restores from the default-maximized state to the default geometry, not zeros", () => {
    mountDesktop();
    hook.workspaceSize = () => ({ w: 800, h: 600 });

    hook.toggleMaximize("chat");

    const st = hook.windows.chat.state;
    expect(st.maximized).toBe(false);
    // Defaults from the markup: x=20, y=20, w=300.
    expect(st.x).toBe(20);
    expect(st.y).toBe(20);
    expect(st.w).toBe(300);
  });

  it("applies the default to a window patched in after mount, unless saved state exists", () => {
    mountDesktop();
    const workspace = el.querySelector(".desktop__workspace");
    workspace.insertAdjacentHTML(
      "beforeend",
      windowMarkup("late", { open: true, defaultMaximized: true }),
    );
    hook.updated();
    expect(hook.windows.late.state.maximized).toBe(true);

    // A saved layout for a late arrival still wins over the default.
    store.set("rhc:desktop:test", JSON.stringify({ later: { open: true, maximized: false } }));
    workspace.insertAdjacentHTML(
      "beforeend",
      windowMarkup("later", { open: true, defaultMaximized: true }),
    );
    hook.updated();
    expect(hook.windows.later.state.maximized).toBe(false);
  });
});

describe("WindowManagerHook — desktop shortcuts", () => {
  let el;
  let hook;

  beforeEach(() => {
    vi.stubGlobal("localStorage", {
      getItem: () => null,
      setItem: () => {},
      removeItem: () => {},
      clear: () => {},
    });

    el = buildDesktop();
    el.dataset.persist = "false";
    const workspace = el.querySelector(".desktop__workspace");
    workspace.insertAdjacentHTML(
      "afterbegin",
      `<div class="desktop__shortcuts">
         <button data-window-shortcut="call">call</button>
         <button data-window-shortcut="chat">chat</button>
       </div>`,
    );

    hook = { ...WindowManagerHook, el, handleEvent: vi.fn() };
    hook.mounted();
  });

  afterEach(() => {
    hook.destroyed();
    el.remove();
    vi.unstubAllGlobals();
  });

  const shortcut = (id) => el.querySelector(`[data-window-shortcut="${id}"]`);

  it("selects a shortcut on single click, exclusively", () => {
    shortcut("call").click();
    expect(shortcut("call").classList.contains("is-selected")).toBe(true);

    shortcut("chat").click();
    expect(shortcut("chat").classList.contains("is-selected")).toBe(true);
    expect(shortcut("call").classList.contains("is-selected")).toBe(false);
  });

  it("opens the target window on double click", () => {
    expect(hook.windows.call.state.open).toBe(false);
    shortcut("call").dispatchEvent(new MouseEvent("dblclick", { bubbles: true }));
    expect(hook.windows.call.state.open).toBe(true);
  });

  it("clears the selection when clicking elsewhere", () => {
    shortcut("call").click();
    expect(shortcut("call").classList.contains("is-selected")).toBe(true);

    el.querySelector("[data-window-start]").click();
    expect(shortcut("call").classList.contains("is-selected")).toBe(false);
  });
});
