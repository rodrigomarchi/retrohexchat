import { describe, it, expect, vi, afterEach } from "vitest";

import { ConstructController } from "../../../../js/lib/space/construct/construct_controller.js";
import { constructCamera, constructMap } from "./fixtures.js";

function setup({ items = [], person = null } = {}) {
  const map = constructMap({ items });
  const camera = constructCamera(map);
  camera.follow(5, 5);

  const canvas = document.createElement("canvas");
  canvas.width = 640;
  canvas.height = 480;
  canvas.getBoundingClientRect = () => ({ left: 0, top: 0, width: 640, height: 480 });
  canvas.setPointerCapture = vi.fn();

  const palette = document.createElement("div");
  palette.innerHTML = `
    <button data-construct-kind="tree" data-selected="false"></button>
    <button data-construct-rotate disabled></button>
    <button data-construct-remove disabled></button>
    <p data-construct-status data-hint="hint"></p>`;
  palette.setAttribute("data-refused-occupied", "Something is already there.");

  const engine = {
    map,
    camera,
    participants: new Map(),
    participantAtCanvasPoint: () => person,
    applyConstructLayout: vi.fn((patch) => map.applyPatch(patch)),
    setConstructOverlay: vi.fn(),
  };
  const send = vi.fn();
  const controller = new ConstructController({
    canvas,
    palette,
    engine: () => engine,
    atlas: null,
    send,
  });
  controller.attach();
  return { map, camera, canvas, palette, engine, send, controller };
}

function at(ctx, x, y) {
  const foot = ctx.camera.projection.footAnchor(x, y);
  return ctx.camera.worldToScreen(foot.x, foot.y);
}

function pointer(canvas, type, { x, y }, button = 0) {
  canvas.dispatchEvent(
    new MouseEvent(type, { clientX: x, clientY: y, button, bubbles: true, cancelable: true }),
  );
}

describe("ConstructController", () => {
  let ctx;
  afterEach(() => ctx?.controller.detach());

  it("arms a kind from the palette and asks to place it where the floor is clicked", () => {
    ctx = setup();
    ctx.palette.querySelector('[data-construct-kind="tree"]').click();
    expect(ctx.palette.querySelector('[data-construct-kind="tree"]').dataset.selected).toBe("true");

    pointer(ctx.canvas, "pointermove", at(ctx, 6, 7));
    const overlay = ctx.engine.setConstructOverlay.mock.calls.at(-1)[0];
    expect(overlay.ghost).toMatchObject({ x: 6, y: 7, tile: "cst_tree", valid: true });

    pointer(ctx.canvas, "pointerdown", at(ctx, 6, 7));
    expect(ctx.send.mock.calls[0][0]).toEqual({
      op: "place",
      kind: "tree",
      x: 6,
      y: 7,
      dir: "down",
    });
  });

  it("says a refusal in the status line", () => {
    ctx = setup();
    ctx.send.mockImplementation((_payload, { error }) => error("occupied"));
    ctx.palette.querySelector('[data-construct-kind="tree"]').click();
    pointer(ctx.canvas, "pointerdown", at(ctx, 6, 7));

    expect(ctx.palette.querySelector("[data-construct-status]").textContent).toBe(
      "Something is already there.",
    );
  });

  it("drags a placed piece to a new tile", () => {
    const tree = { id: "t1", kind: "tree", x: 6, y: 6, dir: "down" };
    ctx = setup({ items: [tree] });

    pointer(ctx.canvas, "pointerdown", at(ctx, 6, 6));
    expect(ctx.canvas.setPointerCapture).toHaveBeenCalled();
    pointer(ctx.canvas, "pointermove", at(ctx, 8, 6));
    expect(ctx.engine.setConstructOverlay.mock.calls.at(-1)[0].ghost).toMatchObject({ x: 8, y: 6 });
    pointer(ctx.canvas, "pointerup", at(ctx, 8, 6));

    expect(ctx.send.mock.calls[0][0]).toEqual({ op: "move", item_id: "t1", x: 8, y: 6 });
  });

  it("right-click removes a piece, but never over a person, whose nick menu it is", () => {
    const tree = { id: "t1", kind: "tree", x: 6, y: 6, dir: "down" };
    ctx = setup({ items: [tree] });
    pointer(ctx.canvas, "pointerdown", at(ctx, 6, 6), 2);
    expect(ctx.send.mock.calls[0][0]).toEqual({ op: "remove", item_id: "t1" });

    ctx.controller.detach();
    ctx = setup({ items: [tree], person: { nickname: "bob" } });
    pointer(ctx.canvas, "pointerdown", at(ctx, 6, 6), 2);
    expect(ctx.send).not.toHaveBeenCalled();
  });

  it("Delete removes the picked piece, unless the keyboard is in a text field", () => {
    const tree = { id: "t1", kind: "tree", x: 6, y: 6, dir: "down" };
    ctx = setup({ items: [tree] });
    pointer(ctx.canvas, "pointerdown", at(ctx, 6, 6));
    pointer(ctx.canvas, "pointerup", at(ctx, 6, 6));

    const input = document.createElement("input");
    document.body.appendChild(input);
    input.focus();
    window.dispatchEvent(new KeyboardEvent("keydown", { key: "Delete" }));
    expect(ctx.send).not.toHaveBeenCalled();
    input.remove();

    window.dispatchEvent(new KeyboardEvent("keydown", { key: "Delete" }));
    expect(ctx.send.mock.calls[0][0]).toEqual({ op: "remove", item_id: "t1" });
  });

  it("redraws from a layout broadcast and drops a pick that is gone", () => {
    const tree = { id: "t1", kind: "tree", x: 6, y: 6, dir: "down" };
    ctx = setup({ items: [tree] });
    pointer(ctx.canvas, "pointerdown", at(ctx, 6, 6));
    pointer(ctx.canvas, "pointerup", at(ctx, 6, 6));
    expect(ctx.palette.querySelector("[data-construct-remove]").disabled).toBe(false);

    ctx.controller.applyLayout({ revision: 1, items: [], decor: [], collision: [] });

    expect(ctx.map.items).toEqual([]);
    expect(ctx.palette.querySelector("[data-construct-remove]").disabled).toBe(true);
  });
});
