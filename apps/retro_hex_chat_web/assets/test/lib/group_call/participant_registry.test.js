import { createParticipantRegistry } from "../../../js/lib/group_call/participant_registry.js";

describe("createParticipantRegistry", () => {
  it("normalizes id to a string and fills the display defaults", () => {
    const registry = createParticipantRegistry();
    const record = registry.upsert({ id: 42 });
    expect(record).toEqual({
      id: "42",
      nickname: "Remote",
      status: "connected",
      media_state: {},
    });
  });

  it("keeps provided nickname, status and media state (either casing)", () => {
    const registry = createParticipantRegistry();
    const record = registry.upsert({
      id: "p",
      nickname: "alice",
      status: "away",
      mediaState: { audio: true },
    });
    expect(record.nickname).toBe("alice");
    expect(record.status).toBe("away");
    expect(record.media_state).toEqual({ audio: true });
  });

  it("prefers snake_case media_state when both are present", () => {
    const registry = createParticipantRegistry();
    const record = registry.upsert({ id: "p", media_state: { video: true }, mediaState: {} });
    expect(record.media_state).toEqual({ video: true });
  });

  it("returns null and stores nothing for a participant with no id", () => {
    const registry = createParticipantRegistry();
    expect(registry.upsert({})).toBe(null);
    expect(registry.upsert(null)).toBe(null);
    expect(registry.size).toBe(0);
  });

  it("stores the live record so an in-place media-state update is reflected", () => {
    const registry = createParticipantRegistry();
    const record = registry.upsert({ id: "p" });
    record.media_state = { screen: true };
    expect(registry.get("p").media_state).toEqual({ screen: true });
  });

  it("gets by string or number id", () => {
    const registry = createParticipantRegistry();
    registry.upsert({ id: 7 });
    expect(registry.get(7).id).toBe("7");
    expect(registry.get("7").id).toBe("7");
    expect(registry.get("missing")).toBe(null);
  });

  it("removes by id and reports whether anything was removed", () => {
    const registry = createParticipantRegistry();
    registry.upsert({ id: "p" });
    expect(registry.remove("p")).toBe(true);
    expect(registry.get("p")).toBe(null);
    expect(registry.remove("p")).toBe(false);
    expect(registry.size).toBe(0);
  });

  it("tracks size and clears", () => {
    const registry = createParticipantRegistry();
    registry.upsert({ id: "a" });
    registry.upsert({ id: "b" });
    expect(registry.size).toBe(2);
    registry.clear();
    expect(registry.size).toBe(0);
  });
});
