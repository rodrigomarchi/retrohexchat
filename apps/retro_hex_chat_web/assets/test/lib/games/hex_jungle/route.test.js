import { describe, expect, it } from "vitest";
import { SEED, TREASURES_TOTAL } from "../../../../js/lib/games/hex_jungle/protocol.js";
import { neighbours, wayToTreasure } from "../../../../js/lib/games/hex_jungle/route.js";
import {
  decodeScene,
  stepScreens,
  treasureSlot,
} from "../../../../js/lib/games/hex_jungle/world.js";

const ALL = Array.from({ length: 255 }, (_, i) => i + 1);
const ladderWith = (wall) =>
  ALL.find((s) => decodeScene(s).ladder && decodeScene(s).underground.wall === wall);
const exits = (place) => neighbours(place).filter((step) => step.move.kind === "exit");

describe("the jungle's map", () => {
  it("leads from the start to a treasure still lying", () => {
    const way = wayToTreasure({ screen: SEED, underground: false, heading: 0 }, 0);
    expect(decodeScene(way.target).treasure).not.toBeNull();
    expect(["exit", "descend"]).toContain(way.move.kind);
  });

  it("never leads to a treasure already taken", () => {
    const first = wayToTreasure({ screen: SEED, underground: false, heading: 0 }, 0);
    const taken = 1 << treasureSlot(first.target);
    const second = wayToTreasure({ screen: SEED, underground: false, heading: 0 }, taken);
    expect(second.target).not.toBe(first.target);
  });

  it("has no way left once all are taken", () => {
    const all = 2 ** TREASURES_TOTAL - 1;
    expect(wayToTreasure({ screen: SEED, underground: false, heading: 0 }, all)).toBeNull();
  });

  it("takes a ladder down away from the tunnel's wall", () => {
    const left = ladderWith("left");
    const down = neighbours({ screen: left, underground: false, heading: 0 }).find(
      (step) => step.move.kind === "descend",
    );
    expect(down.place).toEqual({ screen: left, underground: true, heading: 1 });
  });

  it("walks no tunnel into its wall, and enters none by a wall at its edge", () => {
    const left = ladderWith("left");
    expect(exits({ screen: left, underground: true, heading: -1 })).toEqual([]);
    // The screen three to the left of a left-walled one, heading right, cannot go in.
    const before = stepScreens(left, 3, -1);
    const into = exits({ screen: before, underground: true, heading: 1 });
    expect(into.map((step) => step.place.screen)).not.toContain(left);
  });

  it("goes three screens at a time underground", () => {
    const plain = ALL.find((s) => !decodeScene(s).ladder);
    const [step] = exits({ screen: plain, underground: true, heading: 1 });
    expect(step.place.screen).toBe(stepScreens(plain, 3, 1));
  });
});
