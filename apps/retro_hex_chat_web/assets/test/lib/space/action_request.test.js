import { describe, it, expect } from "vitest";

import { actionRequest } from "../../../js/lib/space/action_request.js";
import { SpaceMap } from "../../../js/lib/space/map.js";

const map = SpaceMap.from({
  width: 10,
  height: 10,
  interactables: [{ id: "gate", x: 2, y: 2, title: "Construct" }],
  seats: [{ id: "seat:c", x: 5, y: 5, dir: "down" }],
});

const at = (x, y, extra = {}) => ({ x, y, dir: "up", pose: "standing", seatId: null, ...extra });

describe("actionRequest", () => {
  it("E uses the interactable next to the avatar, F sits on the seat next to it", () => {
    expect(actionRequest("interact", map, at(2, 3))).toEqual({ kind: "use", target_id: "gate" });
    expect(actionRequest("sit", map, at(5, 6))).toEqual({ kind: "sit", target_id: "seat:c" });
    expect(actionRequest("interact", map, at(5, 6))).toBe(null);
  });

  it("the pad's use does whichever applies, a gate first, and gets up when seated", () => {
    expect(actionRequest("use", map, at(2, 3))).toEqual({ kind: "use", target_id: "gate" });
    expect(actionRequest("use", map, at(5, 6))).toEqual({ kind: "sit", target_id: "seat:c" });
    expect(actionRequest("use", map, at(5, 5, { pose: "sitting", seatId: "seat:c" }))).toEqual({
      kind: "stand",
      target_id: "seat:c",
    });
    expect(actionRequest("use", map, at(8, 8))).toBe(null);
  });
});
