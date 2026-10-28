import { describe, expect, it, vi } from "vitest";

import LobbyGameCanvasHook from "../../../js/hooks/lobby/lobby_game_canvas_hook.js";

/** A hook on a canvas inside a stage whose menu is `menuOpen`. */
function mount({ menuOpen = false } = {}) {
  const stage = document.createElement("div");
  stage.className = "game-stage";
  const menu = document.createElement("div");
  menu.setAttribute("role", "dialog");
  // jsdom lays nothing out: a shown menu is one with an offsetParent.
  Object.defineProperty(menu, "offsetParent", { get: () => (menuOpen ? stage : null) });
  const el = document.createElement("div");
  el.appendChild(document.createElement("canvas"));
  stage.append(el, menu);
  document.body.appendChild(stage);

  const hook = Object.assign(Object.create(LobbyGameCanvasHook), {
    el,
    pushEvent: vi.fn(),
    pushEventTo: vi.fn(),
    handleEvent: vi.fn(),
  });
  hook.mounted();
  return { hook, stage };
}

const esc = () => {
  const event = new KeyboardEvent("keydown", { key: "Escape", cancelable: true });
  window.dispatchEvent(event);
  return event;
};

describe("LobbyGameCanvasHook", () => {
  it("Esc in a running match asks its island for the menu, and the key goes no further", () => {
    const { hook, stage } = mount();
    hook.engine = { running: true, stop: vi.fn() };
    const later = vi.fn();
    window.addEventListener("keydown", later);

    const event = esc();

    expect(hook.pushEventTo).toHaveBeenCalledWith(hook.el, "game_menu", {});
    expect(event.defaultPrevented).toBe(true);
    expect(later).not.toHaveBeenCalled();
    window.removeEventListener("keydown", later);
    hook.destroyed();
    stage.remove();
  });

  it("leaves Esc to the menu once it is open, and to the page with no match", () => {
    const open = mount({ menuOpen: true });
    open.hook.engine = { running: true, stop: vi.fn() };
    esc();
    expect(open.hook.pushEventTo).not.toHaveBeenCalled();
    open.hook.destroyed();
    open.stage.remove();

    const idle = mount();
    esc();
    expect(idle.hook.pushEventTo).not.toHaveBeenCalled();
    idle.hook.destroyed();
    idle.stage.remove();
  });
});
