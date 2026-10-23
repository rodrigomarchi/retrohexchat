import { describe, it, expect, beforeEach, afterEach } from "vitest";

import { InputController } from "../../../js/lib/space/input.js";

function keydown(key) {
  return new KeyboardEvent("keydown", { key, bubbles: true, cancelable: true });
}
function keyup(key) {
  return new KeyboardEvent("keyup", { key, bubbles: true, cancelable: true });
}

describe("InputController", () => {
  let intents;
  let controller;

  beforeEach(() => {
    intents = [];
    controller = new InputController({ onIntent: (i) => intents.push(i) });
    controller.attach();
  });

  afterEach(() => {
    controller.detach();
  });

  it("maps arrow keys and WASD to cardinal intents", () => {
    window.dispatchEvent(keydown("ArrowRight"));
    expect(intents.at(-1)).toEqual({ dx: 1, dy: 0, dir: "right" });

    window.dispatchEvent(keyup("ArrowRight"));
    window.dispatchEvent(keydown("w"));
    expect(intents.at(-1)).toEqual({ dx: 0, dy: -1, dir: "up" });

    window.dispatchEvent(keyup("w"));
    window.dispatchEvent(keydown("a"));
    expect(intents.at(-1)).toEqual({ dx: -1, dy: 0, dir: "left" });
  });

  it("coalesces auto-repeat: holding a key emits at most one intent per drain", () => {
    window.dispatchEvent(keydown("ArrowDown"));
    window.dispatchEvent(keydown("ArrowDown"));
    window.dispatchEvent(keydown("ArrowDown"));
    expect(intents).toHaveLength(1);
  });

  it("emits again after the held key is released and pressed anew", () => {
    window.dispatchEvent(keydown("ArrowUp"));
    window.dispatchEvent(keyup("ArrowUp"));
    window.dispatchEvent(keydown("ArrowUp"));
    expect(intents).toHaveLength(2);
  });

  it("suppresses capture while an input or textarea is focused", () => {
    const field = document.createElement("input");
    document.body.appendChild(field);
    field.focus();

    window.dispatchEvent(keydown("ArrowRight"));
    expect(intents).toHaveLength(0);

    field.remove();
  });

  // The arrows pick an option in a select; they never walked the avatar
  // meanwhile, and the same goes for anything that says it takes text.
  it("suppresses capture while a select or a role=textbox is focused", () => {
    const select = document.createElement("select");
    select.innerHTML = "<option>a</option><option>b</option>";
    document.body.appendChild(select);
    select.focus();
    window.dispatchEvent(keydown("ArrowDown"));
    expect(intents).toHaveLength(0);
    select.remove();

    const box = document.createElement("div");
    box.setAttribute("role", "textbox");
    box.tabIndex = 0;
    document.body.appendChild(box);
    box.focus();
    window.dispatchEvent(keydown("ArrowDown"));
    expect(intents).toHaveLength(0);
    box.remove();
  });

  it("reports the current pressed direction and clears on release", () => {
    window.dispatchEvent(keydown("ArrowLeft"));
    expect(controller.currentIntent()).toEqual({ dx: -1, dy: 0, dir: "left" });

    window.dispatchEvent(keyup("ArrowLeft"));
    expect(controller.currentIntent()).toBe(null);
  });

  it("currentIntent ignores action keys and reports the last held direction", () => {
    window.dispatchEvent(keydown("ArrowRight"));
    window.dispatchEvent(keydown("e")); // action key pressed after a move key
    expect(controller.currentIntent()).toEqual({ dx: 1, dy: 0, dir: "right" });
  });

  it("clears pressed keys on window blur so a missed keyup can't stick", () => {
    window.dispatchEvent(keydown("ArrowRight"));
    expect(intents).toHaveLength(1);

    // Alt-Tab: the window loses focus and the keyup never arrives.
    window.dispatchEvent(new Event("blur"));

    // Pressing the same direction again must emit — not be coalesced as "held".
    window.dispatchEvent(keydown("ArrowRight"));
    expect(intents).toHaveLength(2);
    expect(controller.currentIntent()).toEqual({ dx: 1, dy: 0, dir: "right" });
  });

  it("detach removes listeners so later keys are ignored", () => {
    controller.detach();
    window.dispatchEvent(keydown("ArrowRight"));
    expect(intents).toHaveLength(0);
  });

  it("presses and releases virtual directions like held keys", () => {
    controller.pressDirection("right");
    expect(intents).toEqual([{ dx: 1, dy: 0, dir: "right" }]);
    expect(controller.currentIntent()).toEqual({ dx: 1, dy: 0, dir: "right" });

    // A held virtual press does not re-emit (parity with keydown coalescing).
    controller.pressDirection("right");
    expect(intents).toHaveLength(1);

    controller.releaseDirection("right");
    expect(controller.currentIntent()).toBe(null);
  });

  it("mixes virtual and keyboard sources: most recent press wins", () => {
    window.dispatchEvent(keydown("ArrowUp"));
    controller.pressDirection("left");
    expect(controller.currentIntent()).toEqual({ dx: -1, dy: 0, dir: "left" });

    controller.releaseDirection("left");
    expect(controller.currentIntent()).toEqual({ dx: 0, dy: -1, dir: "up" });
  });

  it("ignores unknown virtual directions and actions", () => {
    const actions = [];
    const c = new InputController({ onAction: (a) => actions.push(a) });
    c.pressDirection("diagonal");
    expect(c.currentIntent()).toBe(null);

    c.triggerAction("attack");
    c.triggerAction("jump");
    expect(actions).toEqual(["attack"]);
  });

  it("leaves a key held with Ctrl, Cmd or Alt to the browser: Ctrl+F finds, Ctrl+S saves", () => {
    const actions = [];
    const intents = [];
    const c = new InputController({
      onAction: (a) => actions.push(a),
      onIntent: (i) => intents.push(i),
    });
    c.attach();
    for (const mod of ["ctrlKey", "metaKey", "altKey"]) {
      for (const key of ["f", "z", "q", "e", "s", "a", "ArrowLeft"]) {
        const event = new KeyboardEvent("keydown", { key, [mod]: true, cancelable: true });
        window.dispatchEvent(event);
        expect(event.defaultPrevented).toBe(false);
      }
    }
    expect(actions).toEqual([]);
    expect(intents).toEqual([]);
    c.detach();
  });

  it("emits action intents for Space (attack), e (interact) and f (sit), coalesced and focus-aware", () => {
    const actions = [];
    const c = new InputController({ onAction: (a) => actions.push(a) });
    c.attach();

    window.dispatchEvent(keydown(" "));
    window.dispatchEvent(keydown(" ")); // auto-repeat coalesced
    window.dispatchEvent(keyup(" "));
    window.dispatchEvent(keydown("e"));
    window.dispatchEvent(keydown("e")); // auto-repeat coalesced
    window.dispatchEvent(keyup("e"));
    window.dispatchEvent(keydown("f"));
    window.dispatchEvent(keydown("q"));
    window.dispatchEvent(keydown("Z"));
    expect(actions).toEqual(["attack", "interact", "sit", "wave", "dance"]);

    const field = document.createElement("textarea");
    document.body.appendChild(field);
    field.focus();
    window.dispatchEvent(keydown(" "));
    expect(actions).toHaveLength(5);

    field.remove();
    c.detach();
  });
});
