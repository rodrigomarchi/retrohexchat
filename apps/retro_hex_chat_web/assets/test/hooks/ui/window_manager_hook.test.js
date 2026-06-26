import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import WindowManagerHook from "../../../js/hooks/ui/window_manager_hook";

function windowMarkup(id, { pinned = false, open = true } = {}) {
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
         data-window-open="${open}" data-window-default-x="20" data-window-default-y="20"
         data-window-default-width="300" data-window-min-width="200" data-window-min-height="120">
      <div data-window-titlebar>${controls}</div>
      <div data-window-content></div>
      <button data-window-resize></button>
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
