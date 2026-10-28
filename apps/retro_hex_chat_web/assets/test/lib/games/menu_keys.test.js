import { describe, expect, it, vi } from "vitest";

import { menuShown, watchMenuKeys } from "../../../js/lib/games/menu_keys.js";

const esc = (target) => {
  const event = new KeyboardEvent("keydown", { key: "Escape", cancelable: true });
  target.dispatchEvent(event);
  return event;
};

describe("watchMenuKeys", () => {
  it("Esc opens the menu while it is wanted, and the key goes no further", () => {
    const target = new EventTarget();
    const later = vi.fn();
    const open = vi.fn();
    let wanted = true;
    const stop = watchMenuKeys({ wants: () => wanted, open, target });
    target.addEventListener("keydown", later, true);

    expect(esc(target).defaultPrevented).toBe(true);
    expect(open).toHaveBeenCalledOnce();
    expect(later).not.toHaveBeenCalled();

    wanted = false;
    esc(target);
    expect(open).toHaveBeenCalledOnce();
    expect(later).toHaveBeenCalledOnce();

    stop();
    wanted = true;
    esc(target);
    expect(open).toHaveBeenCalledOnce();
  });

  it("a held Esc opens it once", () => {
    const target = new EventTarget();
    const open = vi.fn();
    watchMenuKeys({ wants: () => true, open, target });
    esc(target);
    target.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", repeat: true }));
    expect(open).toHaveBeenCalledOnce();
  });

  it("knows the stage's menu is on screen by its layout", () => {
    const stage = document.createElement("div");
    stage.className = "game-stage";
    const menu = document.createElement("div");
    menu.setAttribute("role", "dialog");
    let shown = false;
    Object.defineProperty(menu, "offsetParent", { get: () => (shown ? stage : null) });
    const canvas = document.createElement("canvas");
    stage.append(canvas, menu);

    expect(menuShown(canvas)).toBe(false);
    shown = true;
    expect(menuShown(canvas)).toBe(true);
    expect(menuShown(document.createElement("div"))).toBe(false);
  });

  it("a hidden tab opens it only where asked to", () => {
    const doc = Object.assign(new EventTarget(), { visibilityState: "hidden" });
    const open = vi.fn();
    const stopHeld = watchMenuKeys({
      wants: () => true,
      open,
      onHidden: true,
      target: new EventTarget(),
      doc,
    });
    doc.dispatchEvent(new Event("visibilitychange"));
    expect(open).toHaveBeenCalledOnce();
    stopHeld();

    watchMenuKeys({ wants: () => true, open, target: new EventTarget(), doc });
    doc.dispatchEvent(new Event("visibilitychange"));
    expect(open).toHaveBeenCalledOnce();
  });
});
