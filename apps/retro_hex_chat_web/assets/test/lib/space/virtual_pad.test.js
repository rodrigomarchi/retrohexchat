import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";

import { VirtualPadController } from "../../../js/lib/space/virtual_pad.js";

// jsdom has no PointerEvent constructor; a MouseEvent with a defined pointerId
// carries everything the controller reads.
function pointerEvent(type, { id = 1, x = 0, y = 0 } = {}) {
  const event = new MouseEvent(type, { bubbles: true, cancelable: true, clientX: x, clientY: y });
  Object.defineProperty(event, "pointerId", { value: id });
  return event;
}

function buildPad() {
  const root = document.createElement("div");
  root.setAttribute("data-space-pad", "");
  const buttons = {};
  for (const dir of ["up", "down", "left", "right"]) {
    const el = document.createElement("button");
    el.setAttribute("data-space-pad-dir", dir);
    root.appendChild(el);
    buttons[dir] = el;
  }
  const attack = document.createElement("button");
  attack.setAttribute("data-space-pad-action", "attack");
  root.appendChild(attack);
  buttons.attack = attack;
  document.body.appendChild(root);
  return { root, buttons };
}

describe("VirtualPadController", () => {
  let root;
  let buttons;
  let input;
  let controller;
  // What the injected hit-test reports under the pointer (jsdom has no layout).
  let under;

  beforeEach(() => {
    ({ root, buttons } = buildPad());
    input = { pressDirection: vi.fn(), releaseDirection: vi.fn(), triggerAction: vi.fn() };
    under = null;
    controller = new VirtualPadController({
      root,
      input,
      hitTest: () => under,
    });
    controller.attach();
  });

  afterEach(() => {
    controller.detach();
    root.remove();
  });

  function press(dir, { id = 1 } = {}) {
    under = {
      el: buttons[dir],
      dir: dir === "attack" ? null : dir,
      action: dir === "attack" ? "attack" : null,
    };
    root.dispatchEvent(pointerEvent("pointerdown", { id }));
  }

  it("presses a direction on pointerdown and releases on pointerup", () => {
    press("up");
    expect(input.pressDirection).toHaveBeenCalledWith("up");
    expect(buttons.up.hasAttribute("data-pressed")).toBe(true);

    root.dispatchEvent(pointerEvent("pointerup"));
    expect(input.releaseDirection).toHaveBeenCalledWith("up");
    expect(buttons.up.hasAttribute("data-pressed")).toBe(false);
  });

  it("slides between directions without lifting: release old, press new", () => {
    press("up");

    under = { el: buttons.right, dir: "right", action: null };
    root.dispatchEvent(pointerEvent("pointermove"));

    expect(input.releaseDirection).toHaveBeenCalledWith("up");
    expect(input.pressDirection).toHaveBeenLastCalledWith("right");
    expect(buttons.up.hasAttribute("data-pressed")).toBe(false);
    expect(buttons.right.hasAttribute("data-pressed")).toBe(true);
  });

  it("sliding off every control releases; sliding back re-presses", () => {
    press("down");

    under = null;
    root.dispatchEvent(pointerEvent("pointermove"));
    expect(input.releaseDirection).toHaveBeenCalledWith("down");

    under = { el: buttons.down, dir: "down", action: null };
    root.dispatchEvent(pointerEvent("pointermove"));
    expect(input.pressDirection).toHaveBeenCalledTimes(2);
  });

  it("fires an action once on press and does not slide into directions", () => {
    press("attack");
    expect(input.triggerAction).toHaveBeenCalledWith("attack");
    expect(buttons.attack.hasAttribute("data-pressed")).toBe(true);

    // Sliding an action pointer over the D-pad must not start walking.
    under = { el: buttons.left, dir: "left", action: null };
    root.dispatchEvent(pointerEvent("pointermove"));
    expect(input.pressDirection).not.toHaveBeenCalled();

    root.dispatchEvent(pointerEvent("pointerup"));
    expect(buttons.attack.hasAttribute("data-pressed")).toBe(false);
    expect(input.triggerAction).toHaveBeenCalledTimes(1);
  });

  it("tracks pointers independently (multi-touch: walk + attack)", () => {
    press("up", { id: 1 });
    press("attack", { id: 2 });

    root.dispatchEvent(pointerEvent("pointerup", { id: 2 }));
    // Lifting the attack finger must not release the walking finger.
    expect(input.releaseDirection).not.toHaveBeenCalled();

    root.dispatchEvent(pointerEvent("pointerup", { id: 1 }));
    expect(input.releaseDirection).toHaveBeenCalledWith("up");
  });

  it("pointercancel releases the held direction (no stuck walk)", () => {
    press("left");
    root.dispatchEvent(pointerEvent("pointercancel"));
    expect(input.releaseDirection).toHaveBeenCalledWith("left");
  });

  it("detach releases everything still held", () => {
    press("right");
    controller.detach();
    expect(input.releaseDirection).toHaveBeenCalledWith("right");
    expect(buttons.right.hasAttribute("data-pressed")).toBe(false);
  });

  it("a press outside any control is ignored", () => {
    under = null;
    root.dispatchEvent(pointerEvent("pointerdown"));
    expect(input.pressDirection).not.toHaveBeenCalled();
    expect(input.triggerAction).not.toHaveBeenCalled();
  });

  it("suppresses the context menu (mobile long-press)", () => {
    const event = new MouseEvent("contextmenu", { bubbles: true, cancelable: true });
    root.dispatchEvent(event);
    expect(event.defaultPrevented).toBe(true);
  });
});
