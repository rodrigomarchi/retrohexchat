import { describe, it, expect } from "vitest";

import { BuildMode } from "../../../../js/lib/space/construct/build_mode.js";

const tile = (x, y) => ({ x, y });
const chair = { id: "c1", x: 4, y: 4 };

describe("BuildMode", () => {
  it("arms a kind, places it on every click, and disarms on a second press", () => {
    const mode = new BuildMode();
    mode.choose("tree");

    expect(mode.pointerDown({ tile: tile(5, 5), item: null, button: 0 }).command).toEqual({
      op: "place",
      kind: "tree",
      x: 5,
      y: 5,
      dir: "down",
    });
    expect(mode.pointerDown({ tile: tile(6, 5), item: null, button: 0 }).command.x).toBe(6);

    mode.choose("tree");
    expect(mode.state().mode).toBe("idle");
  });

  it("turns the armed kind before it is placed", () => {
    const mode = new BuildMode();
    mode.choose("chair");
    mode.key("r");
    expect(mode.pointerDown({ tile: tile(5, 5), item: null, button: 0 }).command.dir).toBe("right");
    mode.rotate();
    expect(mode.state().dir).toBe("down");
  });

  it("drags a piece to another tile, and a click without moving only picks it", () => {
    const mode = new BuildMode();

    mode.pointerDown({ tile: tile(4, 4), item: chair, button: 0 });
    expect(mode.state().mode).toBe("dragging");
    mode.pointerMove({ tile: tile(7, 3) });
    expect(mode.pointerUp({ tile: tile(7, 3) }).command).toEqual({
      op: "move",
      item_id: "c1",
      x: 7,
      y: 3,
    });
    expect(mode.state()).toEqual({ mode: "selected", itemId: "c1" });

    mode.pointerDown({ tile: tile(4, 4), item: chair, button: 0 });
    expect(mode.pointerUp({ tile: tile(4, 4) }).command).toBe(null);
    expect(mode.state().mode).toBe("selected");
  });

  it("removes the picked piece with Delete, Backspace or the palette, and turns it with R", () => {
    for (const remove of [(m) => m.key("Delete"), (m) => m.key("Backspace"), (m) => m.remove()]) {
      const mode = new BuildMode();
      mode.pointerDown({ tile: tile(4, 4), item: chair, button: 0 });
      mode.pointerUp({ tile: tile(4, 4) });

      expect(mode.rotate().command).toEqual({ op: "rotate", item_id: "c1" });
      expect(remove(mode).command).toEqual({ op: "remove", item_id: "c1" });
      expect(mode.state().mode).toBe("idle");
    }
  });

  it("right-click removes the piece under it, or cancels an armed kind", () => {
    const mode = new BuildMode();
    expect(mode.pointerDown({ tile: tile(4, 4), item: chair, button: 2 }).command).toEqual({
      op: "remove",
      item_id: "c1",
    });

    mode.choose("lamp");
    expect(mode.pointerDown({ tile: tile(4, 4), item: chair, button: 2 }).command).toBe(null);
    expect(mode.state().mode).toBe("idle");
  });

  it("Escape drops whatever is armed or picked, and says it handled the key", () => {
    const mode = new BuildMode();
    expect(mode.key("Escape").handled).toBe(false);
    mode.choose("lamp");
    expect(mode.key("Escape")).toEqual({ command: null, handled: true });
    expect(mode.state().mode).toBe("idle");
  });

  it("forgets a picked piece that left the room, and a drag that left the canvas", () => {
    const mode = new BuildMode();
    mode.pointerDown({ tile: tile(4, 4), item: chair, button: 0 });
    mode.pointerLeave();
    expect(mode.state()).toEqual({ mode: "selected", itemId: "c1" });
    expect(mode.hover()).toBe(null);

    mode.forget(() => false);
    expect(mode.state().mode).toBe("idle");
  });

  it("a click on empty floor with nothing armed picks nothing", () => {
    const mode = new BuildMode();
    mode.pointerDown({ tile: tile(4, 4), item: chair, button: 0 });
    mode.pointerUp({ tile: tile(4, 4) });
    expect(mode.pointerDown({ tile: tile(8, 8), item: null, button: 0 }).command).toBe(null);
    expect(mode.state().mode).toBe("idle");
  });
});
