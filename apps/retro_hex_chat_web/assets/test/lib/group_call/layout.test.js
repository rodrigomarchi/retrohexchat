import { describe, expect, it } from "vitest";

import {
  focusedTileIndex,
  isTilePinned,
  tileIsVisible,
} from "../../../js/lib/group_call/layout.js";

describe("tileIsVisible", () => {
  it("always shows remote tiles", () => {
    expect(tileIsVisible(false, "hidden")).toBe(true);
    expect(tileIsVisible(false, "tile")).toBe(true);
  });

  it("hides the local tile only when self-view is hidden", () => {
    expect(tileIsVisible(true, "hidden")).toBe(false);
    expect(tileIsVisible(true, "tile")).toBe(true);
    expect(tileIsVisible(true, "pip")).toBe(true);
  });
});

describe("focusedTileIndex", () => {
  const tiles = [
    { participantId: "self", isLocal: true },
    { participantId: "a", streamId: "sa", isLocal: false },
    { participantId: "b", streamId: "sb", isLocal: false },
  ];

  it("is -1 in a non-focus mode", () => {
    expect(focusedTileIndex({ mode: "grid" }, tiles)).toBe(-1);
    expect(focusedTileIndex({ mode: "auto" }, tiles)).toBe(-1);
  });

  it("prefers the active speaker in speaker mode", () => {
    expect(focusedTileIndex({ mode: "speaker", activeSpeakerId: "b" }, tiles)).toBe(2);
  });

  it("falls back from active speaker to focused participant", () => {
    expect(
      focusedTileIndex(
        { mode: "speaker", activeSpeakerId: "ghost", focusedParticipantId: "a" },
        tiles,
      ),
    ).toBe(1);
  });

  it("focuses an explicit participant in focus mode", () => {
    expect(focusedTileIndex({ mode: "focus", focusedParticipantId: "b" }, tiles)).toBe(2);
  });

  it("focuses by stream when no participant matches", () => {
    expect(focusedTileIndex({ mode: "focus", focusedStreamId: "sa" }, tiles)).toBe(1);
  });

  it("falls back to the first remote tile", () => {
    expect(focusedTileIndex({ mode: "sidebar" }, tiles)).toBe(1);
  });

  it("falls back to the first tile when all are local", () => {
    expect(focusedTileIndex({ mode: "focus" }, [{ participantId: "self", isLocal: true }])).toBe(0);
  });

  it("is -1 when there are no tiles", () => {
    expect(focusedTileIndex({ mode: "focus" }, [])).toBe(-1);
  });
});

describe("isTilePinned", () => {
  it("is true only for a participant in the pinned list", () => {
    expect(isTilePinned("a", ["a", "b"])).toBe(true);
    expect(isTilePinned("c", ["a", "b"])).toBe(false);
    expect(isTilePinned(null, ["a"])).toBe(false);
  });
});
