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

  it("reports the current pressed direction and clears on release", () => {
    window.dispatchEvent(keydown("ArrowLeft"));
    expect(controller.currentIntent()).toEqual({ dx: -1, dy: 0, dir: "left" });

    window.dispatchEvent(keyup("ArrowLeft"));
    expect(controller.currentIntent()).toBe(null);
  });

  it("detach removes listeners so later keys are ignored", () => {
    controller.detach();
    window.dispatchEvent(keydown("ArrowRight"));
    expect(intents).toHaveLength(0);
  });

  it("emits action intents for e (interact) and f (sit), coalesced and focus-aware", () => {
    const actions = [];
    const c = new InputController({ onAction: (a) => actions.push(a) });
    c.attach();

    window.dispatchEvent(keydown("e"));
    window.dispatchEvent(keydown("e")); // auto-repeat coalesced
    window.dispatchEvent(keyup("e"));
    window.dispatchEvent(keydown("f"));
    expect(actions).toEqual(["interact", "sit"]);

    const field = document.createElement("textarea");
    document.body.appendChild(field);
    field.focus();
    window.dispatchEvent(keydown("e"));
    expect(actions).toHaveLength(2);

    field.remove();
    c.detach();
  });
});
