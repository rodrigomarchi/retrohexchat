import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import {
  clearWindowManagerMemory,
  createWindowManager,
} from "../../../js/lib/window_manager/window_manager";

function windowMarkup(
  id,
  {
    pinned = false,
    open = true,
    defaultMaximized = false,
    defaultCentered = false,
    defaultFill = null,
    defaultHeight = null,
  } = {},
) {
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
         data-window-initial-open="${open}" data-window-default-maximized="${defaultMaximized}"
         data-window-default-centered="${defaultCentered}"
         data-window-default-x="20" data-window-default-y="20"
         ${defaultFill ? `data-window-default-fill="${defaultFill}"` : ""}
         ${defaultHeight ? `data-window-default-height="${defaultHeight}"` : ""}
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
        <div data-start-submenu data-submenu-open="false">
          <button data-start-submenu-trigger>Admin</button>
          <div data-start-submenu-panel class="u-hidden">
            <button data-window-open="conn" data-testid="start-menu-item-open_admin"></button>
            <button
              data-menubar-copy-selection
              data-copy-disabled="true"
              data-testid="start-menu-item-copy_selection"
            ></button>
          </div>
        </div>
      </div>
      <button data-window-taskbar="conn"></button>
      <div data-taskbar-group data-group-open="false">
        <button data-taskbar-group-trigger data-testid="taskbar-group-admin">Admin</button>
        <div data-taskbar-group-panel class="u-hidden">
          <button data-window-taskbar="call" class="desktop-taskbar__group-item"></button>
        </div>
      </div>
      <button data-window-taskbar="chat"></button>
      <button data-window-taskbar="call"></button>
      ${taskbarMenusMarkup()}
    </div>`;
  document.body.appendChild(el);
  return el;
}

describe("WindowManager", () => {
  let hook;
  let el;
  let command;

  beforeEach(() => {
    clearWindowManagerMemory();
    el = buildDesktop();
    command = null;
    hook = createWindowManager(el);
    // The server drives windows through this entry point; the LiveView hook
    // simply forwards `window_command` payloads to it.
    command = (payload = {}) => hook.command(payload.action, payload.id, null, payload);
    hook.workspaceSize = () => ({ w: 1024, h: 768 }); // jsdom has no layout
    hook.mount();
  });

  afterEach(() => {
    hook.destroy();
    el.remove();
    clearWindowManagerMemory();
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

  it("docks a primary and secondary window without stealing focus from the primary", () => {
    command({
      action: "dock_pair",
      id: "call",
      secondary_id: "chat",
      secondary_width: 360,
    });

    const call = hook.windows.call.state;
    const chat = hook.windows.chat.state;

    expect(call.open).toBe(true);
    expect(chat.open).toBe(true);
    expect(call.minimized).toBe(false);
    expect(chat.minimized).toBe(false);
    expect(call.maximized).toBe(false);
    expect(chat.maximized).toBe(false);
    expect(hook.focusedId).toBe("call");
    expect(call.x).toBe(16);
    expect(call.y).toBe(16);
    expect(chat.x).toBe(call.x + call.w + 8);
    expect(chat.y).toBe(16);
    expect(chat.w).toBe(360);
    expect(call.h).toBe(736);
    expect(chat.h).toBe(736);
    expect(call.z).toBeGreaterThan(chat.z);
  });

  it("sets a window geometry from a server command", () => {
    command({
      action: "set_geometry",
      id: "call",
      width: 280,
      height: 180,
      anchor: "bottom_right",
      margin: 20,
    });

    const call = hook.windows.call.state;

    expect(call.open).toBe(true);
    expect(call.minimized).toBe(false);
    expect(call.maximized).toBe(false);
    expect(call.w).toBe(280);
    expect(call.h).toBe(180);
    expect(call.x).toBe(724);
    expect(call.y).toBe(568);
    expect(hook.focusedId).toBe("call");
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
      window.innerWidth = 375; // a phone-sized viewport, below the 768px breakpoint
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

    it("uses 768px as the stacked breakpoint", () => {
      const originalWidth = window.innerWidth;
      try {
        window.innerWidth = 767;
        hook.updateStacking();
        expect(hook.stacked).toBe(true);

        window.innerWidth = 768;
        hook.updateStacking();
        expect(hook.stacked).toBe(false);
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

  describe("taskbar groups", () => {
    function group() {
      return el.querySelector("[data-taskbar-group]");
    }

    function panelHidden() {
      return el.querySelector("[data-taskbar-group-panel]").classList.contains("u-hidden");
    }

    function trigger() {
      return el.querySelector("[data-taskbar-group-trigger]");
    }

    it("opens the group panel on trigger click", () => {
      trigger().click();

      expect(panelHidden()).toBe(false);
      expect(group().dataset.groupOpen).toBe("true");
      expect(trigger().getAttribute("aria-expanded")).toBe("true");
    });

    it("toggles the panel closed on a second click", () => {
      trigger().click();
      trigger().click();

      expect(panelHidden()).toBe(true);
      expect(trigger().getAttribute("aria-expanded")).toBe("false");
    });

    it("closes the panel when a window inside it is picked", () => {
      trigger().click();
      el.querySelector("[data-taskbar-group-panel] [data-window-taskbar]").click();

      expect(panelHidden()).toBe(true);
    });

    it("focuses the window picked out of the group", () => {
      trigger().click();
      el.querySelector("[data-taskbar-group-panel] [data-window-taskbar]").click();

      expect(hook.focusedId).toBe("call");
    });

    it("closes on a pointerdown outside the group", () => {
      trigger().click();
      document.body.dispatchEvent(new MouseEvent("pointerdown", { bubbles: true }));

      expect(panelHidden()).toBe(true);
    });

    it("Escape closes the panel and leaves the windows alone", () => {
      trigger().click();
      const before = el.querySelectorAll('[data-window][data-window-open="true"]').length;

      document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }));

      expect(panelHidden()).toBe(true);
      expect(el.querySelectorAll('[data-window][data-window-open="true"]').length).toBe(before);
    });
  });

  // A window the reader lives in should take most of whatever screen it is
  // given and still fit a laptop, which a size in pixels cannot do. `fill`
  // rides on `centered` — both mean "this geometry belongs to the workspace
  // until you take it" — so everything that already hands ownership over
  // (drag, resize, tile, a saved layout) ends it for free.
  describe("workspace-filled windows", () => {
    function filled(size, opts = {}) {
      document.body.innerHTML = "";
      const el = document.createElement("div");
      el.className = "desktop";
      el.innerHTML = `<div class="desktop__workspace">${windowMarkup("fill", {
        open: true,
        defaultCentered: true,
        defaultFill: 0.8,
        ...opts,
      })}</div>`;
      document.body.appendChild(el);

      const wm = createWindowManager(el);
      wm.mount();
      wm.stacked = false;
      wm.workspaceSize = () => size;
      wm.applyAll();
      return wm;
    }

    it("opens at its share of a large workspace", () => {
      const wm = filled({ w: 2000, h: 1200 }, { defaultHeight: 400 });

      expect(wm.windows.fill.state.w).toBe(1600);
      expect(wm.windows.fill.state.h).toBe(960);
    });

    it("never opens below the size it registered", () => {
      // 0.8 of 300 is 240, under the registered 300 — the registered size wins.
      const wm = filled({ w: 375, h: 800 }, { defaultHeight: 400 });

      expect(wm.windows.fill.state.w).toBe(300);
    });

    it("never opens larger than the workspace", () => {
      const wm = filled({ w: 280, h: 800 }, { defaultHeight: 400 });

      expect(wm.windows.fill.state.w).toBe(280);
    });

    it("recomputes from the registered size, so it can shrink again", () => {
      // Reading the live size back as the floor would ratchet the window up and
      // never let it come down when the workspace does.
      const wm = filled({ w: 2000, h: 1200 }, { defaultHeight: 400 });
      expect(wm.windows.fill.state.w).toBe(1600);

      wm.workspaceSize = () => ({ w: 1000, h: 800 });
      wm.applyAll();
      expect(wm.windows.fill.state.w).toBe(800);
    });

    it("stops filling once the reader drags it", () => {
      const wm = filled({ w: 2000, h: 1200 }, { defaultHeight: 400 });
      const titlebar = document.querySelector("[data-window-titlebar]");
      titlebar.dispatchEvent(
        new MouseEvent("pointerdown", { bubbles: true, button: 0, clientX: 50, clientY: 10 }),
      );
      document.dispatchEvent(new MouseEvent("pointermove", { clientX: 90, clientY: 40 }));
      document.dispatchEvent(new MouseEvent("pointerup", {}));

      expect(wm.windows.fill.state.centered).toBe(false);

      wm.workspaceSize = () => ({ w: 1000, h: 800 });
      wm.applyAll();
      expect(wm.windows.fill.state.w).toBe(1600);
    });

    it("leaves a window with no fill at its registered size", () => {
      const wm = filled({ w: 2000, h: 1200 }, { defaultFill: null, defaultHeight: 400 });

      expect(wm.windows.fill.state.w).toBe(300);
    });
  });

  // A window that carries its own menu bar decides between the text strip and
  // the icon rail on ITS width, not the viewport's: the desk can be 1920 wide
  // while the window on it is dragged to 480.
  describe("a window that carries its own menu bar", () => {
    function withMenu(size, { maximized = false, width = 1000, menus = 0 } = {}) {
      document.body.innerHTML = "";
      const el = document.createElement("div");
      el.className = "desktop";
      const strip = '<span class="app-menu-bar__desktop-menu"></span>'.repeat(menus);
      el.innerHTML = `<div class="desktop__workspace">${windowMarkup("app", {
        open: true,
      }).replace(
        "<div data-window-content>",
        `<div data-window-menu>${strip}</div><div data-window-content>`,
      )}</div>`;
      document.body.appendChild(el);

      const wm = createWindowManager(el);
      wm.mount();
      wm.stacked = false;
      wm.workspaceSize = () => size;
      wm.windows.app.state.w = width;
      wm.windows.app.state.maximized = maximized;
      wm.applyAll();
      return wm;
    }

    const narrow = () =>
      document.querySelector('[data-window-id="app"]').classList.contains("desktop-window--narrow");

    it("keeps the strip while the window is wide enough for it", () => {
      withMenu({ w: 1600, h: 900 }, { width: 1000 });
      expect(narrow()).toBe(false);
    });

    it("collapses when the window is dragged under the strip's width", () => {
      withMenu({ w: 1600, h: 900 }, { width: 500 });
      expect(narrow()).toBe(true);
    });

    it("reads a maximized window as the width of the desk, not of its restore size", () => {
      // `st.w` still holds the size it will restore to, which is not the size
      // it is being drawn at.
      withMenu({ w: 1600, h: 900 }, { width: 500, maximized: true });
      expect(narrow()).toBe(false);
    });

    it("collapses on a phone, where the window is the desk", () => {
      const wm = withMenu({ w: 390, h: 780 }, { width: 1000 });
      wm.stacked = true;
      wm.applyAll();
      expect(narrow()).toBe(true);
    });

    // A bar is only as wide as the menus on it: folding the help viewer's four
    // at the width the chat's seven need would collapse a strip with room to
    // spare.
    it("asks for less room when the bar carries fewer menus", () => {
      withMenu({ w: 1600, h: 900 }, { width: 500, menus: 3 });
      expect(narrow()).toBe(false);

      withMenu({ w: 1600, h: 900 }, { width: 500, menus: 7 });
      expect(narrow()).toBe(true);
    });

    it("leaves a window with no menu bar alone", () => {
      command({ action: "open", id: "call" });
      hook.stacked = false;
      hook.windows.call.state.w = 200;
      hook.workspaceSize = () => ({ w: 1600, h: 900 });
      hook.applyWindow("call");

      expect(win("call").classList.contains("desktop-window--narrow")).toBe(false);
    });
  });

  // Independent of fill: nothing stopped a window registered wider than the
  // screen from being drawn off the edge of an overflow-hidden workspace.
  describe("drawing a window bigger than the workspace", () => {
    it("draws it clamped without shrinking the size it remembers", () => {
      command({ action: "open", id: "call" });
      hook.stacked = false;
      hook.windows.call.state.w = 2000;
      hook.windows.call.state.h = 1500;
      hook.workspaceSize = () => ({ w: 800, h: 600 });
      hook.applyWindow("call");

      expect(win("call").style.getPropertyValue("--win-w")).toBe("800px");
      expect(win("call").style.getPropertyValue("--win-h")).toBe("600px");

      // The remembered size is untouched, so a wide screen gets it back.
      expect(hook.windows.call.state.w).toBe(2000);
      expect(hook.windows.call.state.h).toBe(1500);
    });
  });

  describe("Start menu groups", () => {
    function submenu() {
      return el.querySelector("[data-start-submenu]");
    }

    function panelHidden() {
      return el.querySelector("[data-start-submenu-panel]").classList.contains("u-hidden");
    }

    function openStartMenu() {
      el.querySelector("[data-window-start-menu]").classList.remove("u-hidden");
    }

    it("opens a group panel on trigger click", () => {
      openStartMenu();
      el.querySelector("[data-start-submenu-trigger]").click();

      expect(panelHidden()).toBe(false);
      expect(submenu().dataset.submenuOpen).toBe("true");
    });

    it("keeps the Start menu open when a group trigger is clicked", () => {
      openStartMenu();
      el.querySelector("[data-start-submenu-trigger]").click();

      const menu = el.querySelector("[data-window-start-menu]");
      expect(menu.classList.contains("u-hidden")).toBe(false);
    });

    it("toggles the group closed on a second click", () => {
      openStartMenu();
      el.querySelector("[data-start-submenu-trigger]").click();
      el.querySelector("[data-start-submenu-trigger]").click();

      expect(panelHidden()).toBe(true);
    });

    it("opens a group on hover", () => {
      openStartMenu();
      submenu().dispatchEvent(new MouseEvent("pointerover", { bubbles: true }));

      expect(panelHidden()).toBe(false);
    });

    it("closes the group when hovering a sibling row", () => {
      openStartMenu();
      el.querySelector("[data-start-submenu-trigger]").click();

      el.querySelector('[data-window-start-menu] > [data-window-open="call"]').dispatchEvent(
        new MouseEvent("pointerover", { bubbles: true }),
      );

      expect(panelHidden()).toBe(true);
    });

    it("opens a window from inside a group and closes the whole menu", () => {
      openStartMenu();
      el.querySelector("[data-start-submenu-trigger]").click();
      el.querySelector('[data-start-submenu-panel] [data-window-open="conn"]').click();

      const menu = el.querySelector("[data-window-start-menu]");
      expect(menu.classList.contains("u-hidden")).toBe(true);
      expect(panelHidden()).toBe(true);
    });

    // Start ▸ View ▸ Copy is the one row whose live state is a property of the
    // document rather than of the screen. `copy_selection.js` owns the rule;
    // what is checked here is that the Start menu reaches it at all, since a
    // row that fell through would be handled as a window opener instead.
    it("syncs the copy row against the selection as a group opens", () => {
      const chatLog = document.createElement("div");
      chatLog.id = "chat-messages";
      chatLog.innerHTML = "<p>a message</p>";
      document.body.appendChild(chatLog);

      vi.spyOn(window, "getSelection").mockReturnValue({
        rangeCount: 1,
        toString: () => "a message",
        getRangeAt: () => ({ commonAncestorContainer: chatLog.firstChild }),
      });

      openStartMenu();
      el.querySelector("[data-start-submenu-trigger]").click();

      const copyRow = el.querySelector("[data-menubar-copy-selection]");
      expect(copyRow.dataset.copyDisabled).toBe("false");

      chatLog.remove();
    });

    it("claims a click on the copy row instead of treating it as an opener", () => {
      const writeText = vi.fn().mockResolvedValue(undefined);
      vi.stubGlobal("navigator", { clipboard: { writeText } });

      openStartMenu();
      el.querySelector("[data-start-submenu-trigger]").click();
      el.querySelector("[data-menubar-copy-selection]").click();

      const menu = el.querySelector("[data-window-start-menu]");
      expect(menu.classList.contains("u-hidden")).toBe(true);
    });

    it("closes open groups when the Start menu itself closes", () => {
      openStartMenu();
      el.querySelector("[data-start-submenu-trigger]").click();

      hook.closeStartMenu();

      expect(panelHidden()).toBe(true);
      expect(submenu().dataset.submenuOpen).toBe("false");
    });

    it("reports which level is showing so the stacked menu can drill down", () => {
      const menu = el.querySelector("[data-window-start-menu]");
      const trigger = el.querySelector("[data-start-submenu-trigger]");
      openStartMenu();

      trigger.click();
      expect(menu.dataset.startLevel).toBe("submenu");
      expect(trigger.getAttribute("aria-expanded")).toBe("true");

      trigger.click();
      expect(menu.dataset.startLevel).toBe("root");
      expect(trigger.getAttribute("aria-expanded")).toBe("false");
    });

    it("opens groups by tap only in the stacked shell", () => {
      hook.stacked = true;
      openStartMenu();

      submenu().dispatchEvent(new MouseEvent("pointerover", { bubbles: true }));
      expect(panelHidden()).toBe(true);

      el.querySelector("[data-start-submenu-trigger]").click();
      expect(panelHidden()).toBe(false);
    });
  });

  it("remembers window state in browser memory for a fresh mount", () => {
    command({ action: "open", id: "call" });

    hook.destroy();
    hook = createWindowManager(el);
    hook.workspaceSize = () => ({ w: 1024, h: 768 });
    hook.mount();

    expect(hook.windows.call.state.open).toBe(true);
    expect(hook.windows.conn.state.open).toBe(true);
  });

  it("forgets remembered window state after the in-memory cache is cleared", () => {
    command({ action: "open", id: "call" });
    hook.destroy();
    clearWindowManagerMemory();

    const fresh = createWindowManager(el);
    fresh.workspaceSize = () => ({ w: 1024, h: 768 });
    fresh.mount();
    expect(fresh.windows.call.state.open).toBe(false);
    fresh.destroy();
  });

  it("keeps other windows visible when a server patch lands mid-drag", () => {
    hook.stacked = false; // dragging only exists in desktop (multi-window) mode
    command({ action: "open", id: "call" }); // conn, chat and call all visible

    // Start dragging chat.
    hook.drag = { id: "chat", px: 0, py: 0, ox: 20, oy: 20 };

    // A server patch re-renders the pinned conn window, resetting its class to the
    // server default (which always includes `u-hidden`).
    win("conn").classList.add("u-hidden");
    hook.reconcile();

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
    hook.reconcile();
    expect(win("chat").classList.contains("u-hidden")).toBe(true);

    // Releasing the pointer restores it immediately.
    hook.onPointerUp();
    expect(win("chat").classList.contains("u-hidden")).toBe(false);
  });

  it("restores remembered open state on a fresh mount", () => {
    command({ action: "open", id: "call" });
    hook.destroy();

    const fresh = createWindowManager(el);
    fresh.workspaceSize = () => ({ w: 1024, h: 768 });
    fresh.mount();
    expect(fresh.windows.call.state.open).toBe(true);
    fresh.destroy();
  });
});

describe("WindowManager — dynamic windows (reconciliation)", () => {
  let el;
  let hook;

  beforeEach(() => {
    clearWindowManagerMemory();
    el = buildDesktop();
    el.dataset.persist = "false";
    hook = createWindowManager(el, { pushEvent: vi.fn() });
    hook.workspaceSize = () => ({ w: 1024, h: 768 }); // jsdom has no layout
    hook.mount();
  });

  afterEach(() => {
    hook.destroy();
    el.remove();
    clearWindowManagerMemory();
  });

  const workspace = () => el.querySelector(".desktop__workspace");

  it("registers a window patched in after mount and focuses it", () => {
    workspace().insertAdjacentHTML("beforeend", windowMarkup("game", { open: true }));
    hook.reconcile();

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
    hook.reconcile();

    expect(hook.windows.chat).toBeUndefined();
    expect(hook.focusedId).toBe("conn");
  });

  it("re-binds a window whose root node was replaced, keeping its client state", () => {
    const st = hook.windows.chat.state;
    st.x = 111;

    const old = document.getElementById("chat");
    old.insertAdjacentHTML("afterend", windowMarkup("chat", { open: true }));
    old.remove();
    hook.reconcile();

    expect(hook.windows.chat.el).toBe(document.getElementById("chat"));
    expect(hook.windows.chat.state.x).toBe(111);
  });

  it("cancels an active gesture when the dragged window is pruned", () => {
    hook.drag = { id: "chat", px: 0, py: 0, ox: 20, oy: 20 };
    document.getElementById("chat").remove();
    hook.reconcile();

    expect(hook.drag).toBe(null);
  });

  it("hands focus to a visible window when the arrival is restored as minimized", () => {
    // Remembered layouts can mark a late-arriving window minimized; registerWindow
    // claims focus before the remembered state applies, so reconcile must hand it back.
    hook.focusWindow("chat");
    workspace().insertAdjacentHTML("beforeend", windowMarkup("game", { open: true }));
    hook.readRememberedLayout = () => ({ game: { minimized: true } });
    hook.reconcile();

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

  it("does not treat a window root as an opener when clicking inside it", () => {
    const chat = document.getElementById("chat");
    chat.dataset.windowOpen = "true";
    chat.querySelector("[data-window-content]").innerHTML = "<button>Profile</button>";

    chat.querySelector("button").click();

    expect(hook.pushEvent).not.toHaveBeenCalled();
    expect(workspace().querySelector("[data-window-pending-id]")).toBeNull();
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
    hook.reconcile();

    expect(workspace().querySelector('[data-window-pending-id="game-x"]')).toBeNull();
    expect(hook.windows["game-x"]).toBeTruthy();
  });

  it("notifies the server when a managed window is closed client-side", () => {
    workspace().insertAdjacentHTML("beforeend", windowMarkup("game", { open: true }));
    document.getElementById("game").dataset.windowManaged = "true";
    hook.reconcile();

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

describe("WindowManager — memory opt-out", () => {
  beforeEach(() => {
    clearWindowManagerMemory();
  });

  afterEach(() => {
    clearWindowManagerMemory();
  });

  it("clears remembered state on mount and never writes when persistence is off", () => {
    const rememberedEl = buildDesktop();
    const remembered = createWindowManager(rememberedEl);
    remembered.mount();
    remembered.openWindow("call");
    remembered.destroy();
    rememberedEl.remove();

    const el = buildDesktop();
    el.dataset.persist = "false";
    const hook = createWindowManager(el);
    hook.mount();

    // The old layout was wiped on open, so the remembered "call open" is ignored.
    expect(hook.windows.call.state.open).toBe(false);

    // Opening a window does not write anything back.
    hook.openWindow("call");

    hook.destroy();
    el.remove();

    const laterEl = buildDesktop();
    const later = createWindowManager(laterEl);
    later.mount();
    expect(later.windows.call.state.open).toBe(false);
    later.destroy();
    laterEl.remove();
  });
});

describe("WindowManager — Escape closes the focused window", () => {
  let el;
  let hook;
  let windowSpy;

  const pressEscape = () =>
    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }));

  function mount({ escapeCloses = true } = {}) {
    el = buildDesktop();
    el.dataset.persist = "false";
    if (escapeCloses) el.dataset.escapeClosesWindows = "true";
    hook = createWindowManager(el, { pushEvent: vi.fn() });
    hook.mount();
  }

  beforeEach(() => {
    clearWindowManagerMemory();
    windowSpy = vi.fn();
    window.addEventListener("keydown", windowSpy);
  });

  afterEach(() => {
    window.removeEventListener("keydown", windowSpy);
    hook.destroy();
    el.remove();
    document.querySelectorAll("[data-escape-test]").forEach((n) => n.remove());
    clearWindowManagerMemory();
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

describe("WindowManager — default maximized", () => {
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
    hook = createWindowManager(el);
    hook.workspaceSize = () => ({ w: 1024, h: 768 }); // jsdom has no layout
    hook.mount();
  }

  beforeEach(() => {
    clearWindowManagerMemory();
  });

  afterEach(() => {
    hook.destroy();
    el.remove();
    clearWindowManagerMemory();
  });

  it("mounts maximized when there is no remembered layout", () => {
    mountDesktop();

    expect(hook.windows.chat.state.maximized).toBe(true);
    const winEl = document.getElementById("chat");
    expect(winEl.classList.contains("desktop-window--maximized")).toBe(true);
    // Windows without the flag keep the normal default.
    expect(hook.windows.tools.state.maximized).toBe(false);
  });

  it("lets a remembered layout win over the default", () => {
    mountDesktop();
    hook.command("set_geometry", "chat", null, { x: 60, y: 70, width: 400, height: 300 });
    hook.destroy();
    el.remove();

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

  it("applies the default to a window patched in after mount, unless remembered state exists", () => {
    mountDesktop();
    const workspace = el.querySelector(".desktop__workspace");
    workspace.insertAdjacentHTML(
      "beforeend",
      windowMarkup("late", { open: true, defaultMaximized: true }),
    );
    hook.reconcile();
    expect(hook.windows.late.state.maximized).toBe(true);

    // A remembered layout for a late arrival still wins over the default.
    hook.readRememberedLayout = () => ({ later: { open: true, maximized: false } });
    workspace.insertAdjacentHTML(
      "beforeend",
      windowMarkup("later", { open: true, defaultMaximized: true }),
    );
    hook.reconcile();
    expect(hook.windows.later.state.maximized).toBe(false);
  });
});

describe("WindowManager — default centered", () => {
  let el;
  let hook;

  function mountDesktop() {
    el = document.createElement("div");
    el.dataset.persistKey = "test";
    el.innerHTML = `
      <div class="desktop__workspace">
        ${windowMarkup("logon", { pinned: true, open: true, defaultCentered: true })}
      </div>
      <div class="desktop-taskbar">
        <button data-window-taskbar="logon"></button>
      </div>`;
    document.body.appendChild(el);
    hook = createWindowManager(el);
    hook.workspaceSize = () => ({ w: 1024, h: 768 }); // jsdom has no layout
    hook.mount();
  }

  beforeEach(() => {
    clearWindowManagerMemory();
  });

  afterEach(() => {
    hook.destroy();
    el.remove();
    clearWindowManagerMemory();
  });

  it("centers the window in the workspace on mount", () => {
    mountDesktop();

    const st = hook.windows.logon.state;
    // Width from the markup: 300 → x = (1024 - 300) / 2. Auto height measures 0
    // in jsdom, so the minH fallback (120) drives y = (768 - 120) / 2.
    expect(st.x).toBe(362);
    expect(st.y).toBe(324);
    expect(document.getElementById("logon").style.getPropertyValue("--win-x")).toBe("362px");
  });

  it("recenters when the workspace resizes, until the user takes over", () => {
    mountDesktop();
    hook.workspaceSize = () => ({ w: 800, h: 600 });

    hook.applyAll();
    expect(hook.windows.logon.state.x).toBe(250);
    expect(hook.windows.logon.state.y).toBe(240);
  });

  it("a drag clears centering and the dragged position sticks", () => {
    mountDesktop();
    const st = hook.windows.logon.state;

    hook.startDrag({ preventDefault() {}, clientX: 500, clientY: 400 }, "logon");
    document.dispatchEvent(new MouseEvent("pointermove", { clientX: 540, clientY: 430 }));
    document.dispatchEvent(new MouseEvent("pointerup", {}));

    expect(st.centered).toBe(false);
    expect(st.x).toBe(402);
    expect(st.y).toBe(354);

    // A later re-apply (e.g. a workspace resize) must not recenter.
    hook.applyAll();
    expect(st.x).toBe(402);
    expect(st.y).toBe(354);
  });

  it("a pointerdown inside the window freezes the current position", () => {
    mountDesktop();
    const st = hook.windows.logon.state;
    expect(st.x).toBe(362);

    // A patch may have stored a slightly stale center; the press must keep it
    // as-is (recomputing here would move the window mid-click).
    st.y = 300;
    document
      .getElementById("logon")
      .querySelector("[data-window-content]")
      .dispatchEvent(new MouseEvent("pointerdown", { bubbles: true, button: 0 }));

    expect(st.centered).toBe(false);
    expect(st.y).toBe(300);

    hook.applyAll();
    expect(st.y).toBe(300);
  });

  it("a remembered layout wins over centering", () => {
    mountDesktop();
    hook.command("set_geometry", "logon", null, { x: 60, y: 70, width: 300, height: 200 });
    hook.destroy();
    el.remove();

    mountDesktop();

    const st = hook.windows.logon.state;
    expect(st.centered).toBe(false);
    expect(st.x).toBe(60);
    expect(st.y).toBe(70);
  });
});

describe("WindowManager — a centered window opts out of the mount cascade", () => {
  let el;
  let hook;

  afterEach(() => {
    hook?.destroy();
    el?.remove();
    clearWindowManagerMemory();
  });

  // The cascade hands its front slot the deepest offset, which is the worst
  // place for the tallest window on a page: it starts low, max-height caps it
  // against the bottom edge, and its last rows end up scrolled out of a window
  // that still looks like it fits. A window that declared itself centered keeps
  // the middle of the desk instead, and stays in front of the stack.
  it("keeps the centered window centered and frontmost", () => {
    clearWindowManagerMemory();
    el = document.createElement("div");
    el.dataset.persistKey = "cascade-centered";
    el.dataset.cascadeOnMount = "true";
    el.innerHTML = `
      <div class="desktop__workspace">
        ${windowMarkup("connect", { open: true, defaultCentered: true })}
        ${windowMarkup("intro", { open: true })}
        ${windowMarkup("details", { open: true })}
      </div>
      <div class="desktop-taskbar">
        <button data-window-taskbar="connect"></button>
        <button data-window-taskbar="intro"></button>
        <button data-window-taskbar="details"></button>
      </div>`;
    document.body.appendChild(el);
    hook = createWindowManager(el);
    hook.workspaceSize = () => ({ w: 1024, h: 768 });
    hook.mount();

    const connect = hook.windows.connect.state;
    const intro = hook.windows.intro.state;
    const details = hook.windows.details.state;

    expect(connect.centered).toBe(true);
    expect(connect.x).toBe(362);
    expect(connect.y).toBe(324);

    // The others still cascade, and neither of them outranks the centered one.
    expect(intro.centered).toBe(false);
    expect(details.centered).toBe(false);
    expect(connect.z).toBeGreaterThan(intro.z);
    expect(connect.z).toBeGreaterThan(details.z);

    // It is also the window a phone would show: focus follows page order.
    expect(hook.focusedId).toBe("connect");
  });
});

describe("WindowManager — desktop shortcuts", () => {
  let el;
  let hook;

  beforeEach(() => {
    clearWindowManagerMemory();
    el = buildDesktop();
    el.dataset.persist = "false";
    const workspace = el.querySelector(".desktop__workspace");
    workspace.insertAdjacentHTML(
      "afterbegin",
      `<div class="desktop__shortcuts">
         <button data-window-shortcut="call">call</button>
         <button data-window-shortcut="chat">chat</button>
         <button data-window-shortcut="arcade-games" data-window-shortcut-action="open_arcade">arcade</button>
       </div>`,
    );

    hook = createWindowManager(el);
    hook.mount();
  });

  afterEach(() => {
    hook.destroy();
    el.remove();
    clearWindowManagerMemory();
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

  it("pushes a shortcut action on double click before opening server-owned launchers", () => {
    hook.destroy();
    hook = createWindowManager(el, { pushEvent: vi.fn() });
    hook.mount();

    shortcut("arcade-games").dispatchEvent(new MouseEvent("dblclick", { bubbles: true }));

    expect(hook.pushEvent).toHaveBeenCalledWith("open_arcade", { id: "arcade-games" });
    expect(hook.pendingWindows["arcade-games"]).toBeUndefined();
  });

  it("clears the selection when clicking elsewhere", () => {
    shortcut("call").click();
    expect(shortcut("call").classList.contains("is-selected")).toBe(true);

    el.querySelector("[data-window-start]").click();
    expect(shortcut("call").classList.contains("is-selected")).toBe(false);
  });
});

// A desktop can be built from real links so the page works, and indexes, before
// any JavaScript runs. The manager takes over only the clicks it can serve here.
describe("WindowManager — navigable chrome", () => {
  let el;

  function buildLinkDesktop() {
    const node = document.createElement("div");
    node.dataset.persistKey = "links";
    node.innerHTML = `
      <div class="desktop__workspace">
        ${windowMarkup("here", { open: true })}
      </div>
      <div class="desktop-taskbar">
        <button data-window-start></button>
        <div data-window-start-menu class="u-hidden">
          <a href="/showcase/here" data-window-open="here">Here</a>
          <a href="/showcase/away" data-window-open="away">Away</a>
        </div>
        <a href="/showcase/here" data-window-taskbar="here">Here</a>
        <a href="/showcase/away" data-window-taskbar="away">Away</a>
        <a href="/showcase/away" data-window-shortcut="away">Away</a>
        <a href="/showcase/here" data-window-shortcut="here">Here</a>
        ${taskbarMenusMarkup()}
      </div>`;
    document.body.appendChild(node);
    return node;
  }

  function click(selector) {
    const event = new MouseEvent("click", { bubbles: true, cancelable: true });
    el.querySelector(selector).dispatchEvent(event);
    return event;
  }

  afterEach(() => {
    el.remove();
    clearWindowManagerMemory();
  });

  describe("without a server", () => {
    let wm;

    beforeEach(() => {
      el = buildLinkDesktop();
      wm = createWindowManager(el);
      wm.workspaceSize = () => ({ w: 1024, h: 768 });
      wm.mount();
    });

    afterEach(() => wm.destroy());

    it("handles a taskbar link whose window is on this page", () => {
      const event = click('[data-window-taskbar="here"]');

      expect(event.defaultPrevented).toBe(true);
      expect(wm.windows.here.state.open).toBe(true);
    });

    it("lets a taskbar link to another page navigate", () => {
      const event = click('[data-window-taskbar="away"]');

      expect(event.defaultPrevented).toBe(false);
    });

    it("lets a Start menu link to another page navigate", () => {
      const event = click('[data-window-open="away"]');

      expect(event.defaultPrevented).toBe(false);
    });

    it("opens a Start menu link whose window is on this page", () => {
      const event = click('[data-window-open="here"]');

      expect(event.defaultPrevented).toBe(true);
      expect(wm.windows.here.state.open).toBe(true);
    });

    it("selects a local shortcut instead of following it", () => {
      const event = click('[data-window-shortcut="here"]');

      expect(event.defaultPrevented).toBe(true);
    });

    it("lets a shortcut pointing at another page behave as a plain link", () => {
      const event = click('[data-window-shortcut="away"]');

      expect(event.defaultPrevented).toBe(false);
    });
  });

  describe("with a server that can mount windows", () => {
    let wm;

    beforeEach(() => {
      el = buildLinkDesktop();
      wm = createWindowManager(el, { pushEvent: vi.fn() });
      wm.workspaceSize = () => ({ w: 1024, h: 768 });
      wm.mount();
    });

    afterEach(() => wm.destroy());

    it("asks the server for an absent window rather than navigating", () => {
      const event = click('[data-window-open="away"]');

      expect(event.defaultPrevented).toBe(true);
      expect(wm.pushEvent).toHaveBeenCalledWith("window_open", { id: "away" });
    });
  });

  // The showcase documents the desktop by running one inside its own shell, so
  // two managers share a document with one nested in the other. Each has to
  // claim only its own subtree: an outer manager that adopts the inner windows
  // fights the inner one over their geometry, focus and visibility, and the
  // winner comes down to which patch ran last.
  describe("nested inside another desktop", () => {
    let outer;
    let inner;
    let outerEl;
    let innerEl;

    beforeEach(() => {
      clearWindowManagerMemory();

      outerEl = document.createElement("div");
      outerEl.id = "outer-desktop";
      outerEl.dataset.windowManager = "";
      outerEl.innerHTML = `
        <div class="desktop__workspace">
          ${windowMarkup("shell", { open: true })}
          <div id="inner-desktop" data-window-manager>
            <div class="desktop__workspace">
              ${windowMarkup("demo", { open: true })}
            </div>
            <div class="desktop-taskbar">
              <button data-window-taskbar="demo"></button>
              ${taskbarMenusMarkup()}
            </div>
          </div>
        </div>
        <div class="desktop-taskbar">
          <button data-window-taskbar="shell"></button>
          ${taskbarMenusMarkup()}
        </div>`;
      document.body.appendChild(outerEl);
      innerEl = outerEl.querySelector("#inner-desktop");

      outer = createWindowManager(outerEl);
      inner = createWindowManager(innerEl);
      outer.workspaceSize = () => ({ w: 1024, h: 768 });
      inner.workspaceSize = () => ({ w: 400, h: 300 });
      outer.mount();
      inner.mount();
    });

    afterEach(() => {
      outer.destroy();
      inner.destroy();
      outerEl.remove();
      clearWindowManagerMemory();
    });

    it("claims only the windows in its own subtree", () => {
      expect(Object.keys(outer.windows)).toEqual(["shell"]);
      expect(Object.keys(inner.windows)).toEqual(["demo"]);
    });

    it("keeps a taskbar button for the other manager's window out of reach", () => {
      expect(outer.taskbarButtons("demo")).toEqual([]);
      expect(inner.taskbarButtons("demo")).toHaveLength(1);
    });

    it("leaves the nested manager's windows alone when it reconciles", () => {
      inner.command("minimize", "demo");
      expect(inner.windows.demo.state.minimized).toBe(true);

      // A patch anywhere re-runs the outer manager's reconcile. It must not
      // re-register `demo` and undo the state the inner manager just set.
      outer.reconcile();

      expect(Object.keys(outer.windows)).toEqual(["shell"]);
      expect(inner.windows.demo.state.minimized).toBe(true);
    });
  });
});
