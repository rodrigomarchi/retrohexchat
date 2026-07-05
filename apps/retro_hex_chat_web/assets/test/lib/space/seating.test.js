import { describe, it, expect } from "vitest";

import { seatTarget } from "../../../js/lib/space/seating.js";
import { SpaceMap } from "../../../js/lib/space/map.js";

function map() {
  return SpaceMap.from({
    id: "t",
    width: 10,
    height: 10,
    tile_size: 16,
    spawn: [],
    collision: [],
    zones: [],
    seats: [{ id: "chair", x: 5, y: 3, dir: "up" }],
    interactables: [],
  });
}

describe("seatTarget", () => {
  it("proposes standing up when the participant is already sitting", () => {
    const target = seatTarget(map(), { x: 5, y: 3, dir: "up", pose: "sitting", seatId: "chair" });
    expect(target).toEqual({ action: "stand", id: "chair" });
  });

  it("resolves a seat on the tile the avatar faces", () => {
    const target = seatTarget(map(), { x: 5, y: 4, dir: "up", pose: "standing", seatId: null });
    expect(target).toEqual({ action: "sit", id: "chair" });
  });

  it("resolves an adjacent seat", () => {
    const target = seatTarget(map(), { x: 6, y: 3, dir: "right", pose: "standing", seatId: null });
    expect(target?.action).toBe("sit");
    expect(target?.id).toBe("chair");
  });

  it("returns null with no seat within reach", () => {
    expect(seatTarget(map(), { x: 0, y: 9, dir: "down", pose: "standing", seatId: null })).toBe(
      null,
    );
  });
});
