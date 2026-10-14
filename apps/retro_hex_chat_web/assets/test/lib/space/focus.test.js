import { describe, it, expect } from "vitest";

import { focusKey, focusTarget, isFocusedProp } from "../../../js/lib/space/focus.js";
import { actionRequest } from "../../../js/lib/space/action_request.js";
import { SpaceMap } from "../../../js/lib/space/map.js";

function map() {
  return SpaceMap.from({
    id: "t",
    width: 20,
    height: 20,
    tile_size: 16,
    spawn: [],
    collision: [],
    zones: [],
    seats: [{ id: "seat:c1", x: 10, y: 10, dir: "down", item_id: "c1" }],
    interactables: [
      {
        id: "construct_portal",
        kind: "portal",
        x: 5,
        y: 3,
        title: "Construct",
        modal: { kind: "confirm", action: "enter_construct" },
      },
      { id: "item:l1", kind: "item", use: "toggle_light", x: 10, y: 9, item_id: "l1" },
    ],
  });
}

const standing = (extra) => ({ dir: "up", pose: "standing", seatId: null, ...extra });

describe("focusTarget", () => {
  it("names a gate by its modal action, ringed on its own tile", () => {
    expect(focusTarget(map(), standing({ x: 5, y: 4 }))).toEqual({
      id: "construct_portal",
      key: "interact",
      verb: "enter_construct",
      x: 5,
      y: 3,
      itemId: null,
      outline: true,
    });
  });

  it("names a piece by its use and carries the piece it belongs to", () => {
    const focus = focusTarget(map(), standing({ x: 11, y: 9, dir: "left" }));
    expect(focus).toMatchObject({ verb: "toggle_light", key: "interact", itemId: "l1" });
  });

  it("puts a piece in reach before a seat, as the use button does", () => {
    // (11,10) is next to both the lamp at (10,9) and the chair at (10,10).
    const focus = focusTarget(map(), standing({ x: 11, y: 10, dir: "left" }));
    expect(focus.verb).toBe("toggle_light");
  });

  it("offers a free seat with F, and getting up without a ring once seated", () => {
    expect(focusTarget(map(), standing({ x: 10, y: 11 }))).toMatchObject({
      key: "sit",
      verb: "sit",
      itemId: "c1",
      outline: true,
    });
    const seated = { x: 10, y: 10, dir: "down", pose: "sitting", seatId: "seat:c1" };
    expect(focusTarget(map(), seated)).toMatchObject({ verb: "stand", outline: false });
  });

  it("is null with nothing in reach, or no one to reach with", () => {
    expect(focusTarget(map(), standing({ x: 0, y: 19 }))).toBe(null);
    expect(focusTarget(map(), null)).toBe(null);
  });
});

describe("focusKey", () => {
  it("changes with the target and with what pressing does", () => {
    expect(focusKey(null)).toBe("");
    expect(focusKey({ id: "seat:c1", verb: "sit" })).not.toBe(
      focusKey({ id: "seat:c1", verb: "stand" }),
    );
  });
});

describe("isFocusedProp", () => {
  it("rings every layer of a piece, and a gate's art on its tile", () => {
    const piece = { itemId: "l1", x: 10, y: 9, outline: true };
    expect(isFocusedProp(piece, { item_id: "l1", x: 3, y: 3 })).toBe(true);
    expect(isFocusedProp(piece, { item_id: "l2", x: 10, y: 9 })).toBe(false);
    const gate = { itemId: null, x: 5, y: 3, outline: true };
    expect(isFocusedProp(gate, { x: 5, y: 3 })).toBe(true);
    expect(isFocusedProp(gate, { x: 5, y: 4 })).toBe(false);
    expect(isFocusedProp({ ...gate, outline: false }, { x: 5, y: 3 })).toBe(false);
  });
});

describe("focusTarget and the use button", () => {
  it("light up exactly what a press of the use button asks for, everywhere around", () => {
    const m = map();
    for (const taken of [new Set(), new Set(["seat:c1"])]) {
      for (let x = 2; x <= 13; x++) {
        for (let y = 0; y <= 13; y++) {
          for (const dir of ["up", "down", "left", "right"]) {
            const me = standing({ x, y, dir });
            const focus = focusTarget(m, me, taken);
            const request = actionRequest("use", m, me, taken);
            expect(focus?.id ?? null).toBe(request?.target_id ?? null);
          }
        }
      }
    }
  });
});
