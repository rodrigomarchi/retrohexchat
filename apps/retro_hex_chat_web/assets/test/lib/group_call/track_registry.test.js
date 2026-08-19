import { createTrackRegistry } from "../../../js/lib/group_call/track_registry.js";

describe("createTrackRegistry", () => {
  it("normalizes snake_case and camelCase ids and defaults the source to camera", () => {
    const registry = createTrackRegistry();
    const normalized = registry.upsert({
      id: 7,
      participant_id: 42,
      kind: "video",
      status: "live",
      stream_id: "s-1",
      webrtc_track_id: "w-1",
    });

    expect(normalized).toEqual({
      id: "7",
      participantId: "42",
      kind: "video",
      source: "camera",
      status: "live",
      streamId: "s-1",
      webrtcTrackId: "w-1",
    });
  });

  it("prefers camelCase fields but accepts either casing", () => {
    const registry = createTrackRegistry();
    const normalized = registry.upsert({
      id: "t",
      participantId: "p",
      streamId: "s",
      webrtcTrackId: "w",
      source: "screen",
    });
    expect(normalized.participantId).toBe("p");
    expect(normalized.streamId).toBe("s");
    expect(normalized.webrtcTrackId).toBe("w");
    expect(normalized.source).toBe("screen");
  });

  it("returns null and indexes nothing for a track with no id", () => {
    const registry = createTrackRegistry();
    expect(registry.upsert({})).toBe(null);
    expect(registry.upsert(null)).toBe(null);
    expect(registry.size).toBe(0);
  });

  it("indexes by stream id and webrtc track id", () => {
    const registry = createTrackRegistry();
    registry.upsert({ id: "t", stream_id: "s", webrtc_track_id: "w", participant_id: "p" });

    expect(registry.forTile("s").id).toBe("t");
    expect(registry.forTile("s").participantId).toBe("p");
    expect(registry.byWebrtcTrackId("w").id).toBe("t");
    expect(registry.size).toBe(1);
  });

  it("leaves stream/webrtc indexes empty when those ids are absent", () => {
    const registry = createTrackRegistry();
    registry.upsert({ id: "t" });
    expect(registry.forTile(undefined)).toBe(null);
    expect(registry.byWebrtcTrackId(undefined)).toBe(null);
  });

  describe("forTile lookup precedence", () => {
    it("prefers the stream id and falls back to the browser track id", () => {
      const registry = createTrackRegistry();
      registry.upsert({ id: "a", stream_id: "s", webrtc_track_id: "wa" });
      registry.upsert({ id: "b", webrtc_track_id: "wb" });

      expect(registry.forTile("s", "wb").id).toBe("a");
      expect(registry.forTile("missing", "wb").id).toBe("b");
      expect(registry.forTile("missing", "missing")).toBe(null);
    });
  });

  describe("remove", () => {
    it("drops a track from every index and returns it", () => {
      const registry = createTrackRegistry();
      registry.upsert({ id: "t", stream_id: "s", webrtc_track_id: "w" });

      const removed = registry.remove("t");
      expect(removed.id).toBe("t");
      expect(registry.forTile("s")).toBe(null);
      expect(registry.byWebrtcTrackId("w")).toBe(null);
      expect(registry.size).toBe(0);
    });

    it("returns null for an unknown or nullish id without disturbing the index", () => {
      const registry = createTrackRegistry();
      registry.upsert({ id: "t" });
      expect(registry.remove("nope")).toBe(null);
      expect(registry.remove(null)).toBe(null);
      expect(registry.size).toBe(1);
    });
  });

  it("clears every index", () => {
    const registry = createTrackRegistry();
    registry.upsert({ id: "a", stream_id: "s" });
    registry.upsert({ id: "b", webrtc_track_id: "w" });
    registry.clear();
    expect(registry.size).toBe(0);
    expect(registry.forTile("s")).toBe(null);
    expect(registry.byWebrtcTrackId("w")).toBe(null);
  });
});
