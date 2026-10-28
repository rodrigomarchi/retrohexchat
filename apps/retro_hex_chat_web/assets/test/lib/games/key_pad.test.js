import { describe, expect, it } from "vitest";
import { keyPadInput } from "../../../js/lib/games/key_pad.js";

/** Every key event the target hears, as [type, key]. */
function listening() {
  const target = new EventTarget();
  const heard = [];
  for (const type of ["keydown", "keyup"]) {
    target.addEventListener(type, (event) => heard.push([event.type, event.key]));
  }
  return { target, heard };
}

describe("the games' pad, as keys", () => {
  it("holds an arrow down while its direction is pressed", () => {
    const { target, heard } = listening();
    const input = keyPadInput(target);
    input.pressDirection("left");
    input.releaseDirection("left");
    input.pressDirection("up");
    expect(heard).toEqual([
      ["keydown", "ArrowLeft"],
      ["keyup", "ArrowLeft"],
      ["keydown", "ArrowUp"],
    ]);
  });

  it("holds an action's key down until its button comes up", () => {
    const { target, heard } = listening();
    const input = keyPadInput(target);
    input.triggerAction(" ");
    input.releaseAction(" ");
    input.triggerAction("Shift");
    expect(heard).toEqual([
      ["keydown", " "],
      ["keyup", " "],
      ["keydown", "Shift"],
    ]);
  });

  it("sends keys a page can stop, as real ones", () => {
    const target = new EventTarget();
    let seen = null;
    target.addEventListener("keydown", (event) => {
      seen = event;
    });
    keyPadInput(target).triggerAction("x");
    expect(seen).toBeInstanceOf(KeyboardEvent);
    expect(seen.cancelable).toBe(true);
    expect(seen.repeat).toBe(false);
  });
});
