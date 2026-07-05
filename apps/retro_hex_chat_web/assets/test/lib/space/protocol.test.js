import { describe, it, expect, vi, afterEach } from "vitest";

import {
  PROTOCOL_VERSION,
  CLIENT_EVENTS,
  SERVER_EVENTS,
  normalizeSpaceInit,
  normalizeSnapshot,
  normalizeDelta,
  normalizeParticipant,
} from "../../../js/lib/space/protocol.js";

afterEach(() => {
  vi.restoreAllMocks();
});

describe("protocol constants", () => {
  it("exposes the current protocol version", () => {
    expect(PROTOCOL_VERSION).toBe(1);
  });

  it("names the client→server and server→client events", () => {
    expect(CLIENT_EVENTS.INPUT).toBe("space_input");
    expect(CLIENT_EVENTS.CHAT_BUBBLE).toBe("space_chat_bubble");
    expect(SERVER_EVENTS.DELTA).toBe("space_delta");
    expect(SERVER_EVENTS.SNAPSHOT).toBe("space_snapshot");
    expect(SERVER_EVENTS.CLOSED).toBe("space_closed");
  });
});

describe("normalizeParticipant", () => {
  it("fills missing fields with safe defaults", () => {
    const p = normalizeParticipant("registered:1", { nickname: "alice", x: 4, y: 5 });

    expect(p.key).toBe("registered:1");
    expect(p.nickname).toBe("alice");
    expect(p.x).toBe(4);
    expect(p.y).toBe(5);
    expect(p.dir).toBe("down");
    expect(p.pose).toBe("standing");
    expect(p.moving).toBe(false);
    expect(p.online).toBe(true);
    expect(p.seatId).toBe(null);
    expect(p.zoneId).toBe(null);
  });

  it("coerces coordinates to integers and clamps direction", () => {
    const p = normalizeParticipant("registered:2", { x: "7", y: 3.9, dir: "diagonal" });
    expect(p.x).toBe(7);
    expect(p.y).toBe(3);
    expect(p.dir).toBe("down");
  });
});

describe("normalizeSpaceInit", () => {
  it("normalizes a full init payload", () => {
    const init = normalizeSpaceInit({
      version: 1,
      token: "abc",
      self_key: "registered:1",
      map: { id: "tavern_cafe_v1", version: 1, tile_size: 16 },
      snapshot: {
        participants: { "registered:1": { nickname: "alice", x: 2, y: 2 } },
      },
    });

    expect(init.token).toBe("abc");
    expect(init.selfKey).toBe("registered:1");
    expect(init.map.id).toBe("tavern_cafe_v1");
    expect(init.snapshot.participants["registered:1"].nickname).toBe("alice");
  });

  it("logs an error but still returns a value for an unknown version", () => {
    const spy = vi.spyOn(console, "error").mockImplementation(() => {});
    const init = normalizeSpaceInit({ version: 99, token: "x", map: {}, snapshot: {} });

    expect(spy).toHaveBeenCalled();
    expect(init.token).toBe("x");
  });

  it("provides safe defaults when snapshot or map are missing", () => {
    const init = normalizeSpaceInit({ token: "y" });
    expect(init.map).toEqual({});
    expect(init.snapshot.participants).toEqual({});
  });
});

describe("normalizeSnapshot", () => {
  it("indexes participants by key with defaults", () => {
    const snap = normalizeSnapshot({
      server_time: 123,
      participants: {
        "registered:1": { nickname: "alice", x: 1, y: 1 },
        "registered:2": { nickname: "bob", x: 2, y: 2, dir: "up" },
      },
    });

    expect(snap.serverTime).toBe(123);
    expect(Object.keys(snap.participants)).toHaveLength(2);
    expect(snap.participants["registered:2"].dir).toBe("up");
  });

  it("returns empty participants when absent", () => {
    expect(normalizeSnapshot({}).participants).toEqual({});
  });
});

describe("normalizeDelta", () => {
  it("normalizes updates, joins, leaves and seq_ack", () => {
    const delta = normalizeDelta({
      server_time: 200,
      seq_ack: { "registered:1": 17 },
      updates: { "registered:1": { x: 5, y: 5, dir: "right" } },
      joined: { "registered:3": { nickname: "carol", x: 8, y: 8 } },
      left: ["registered:2"],
    });

    expect(delta.serverTime).toBe(200);
    expect(delta.seqAck["registered:1"]).toBe(17);
    expect(delta.updates["registered:1"].x).toBe(5);
    expect(delta.joined["registered:3"].nickname).toBe("carol");
    expect(delta.left).toEqual(["registered:2"]);
  });

  it("defaults every collection when the payload is sparse", () => {
    const delta = normalizeDelta({ server_time: 1 });
    expect(delta.updates).toEqual({});
    expect(delta.joined).toEqual({});
    expect(delta.left).toEqual([]);
    expect(delta.seqAck).toEqual({});
  });
});
