import { describe, it, expect, vi, beforeEach } from "vitest";

import { SpaceEngine } from "../../../js/lib/space/engine.js";

function fakeCanvas() {
  const canvas = document.createElement("canvas");
  canvas.width = 320;
  canvas.height = 240;
  return canvas;
}

function tavernInit(overrides = {}) {
  return {
    channelName: "#test",
    selfKey: "registered:1",
    map: {
      id: "tavern_cafe_v1",
      width: 20,
      height: 15,
      tile_size: 16,
      spawn: [{ x: 1, y: 1, dir: "down" }],
      collision: [],
      zones: [],
      seats: [],
      interactables: [],
    },
    config: { scale: 2 },
    snapshot: {
      serverTime: 1,
      participants: {
        "registered:1": { nickname: "alice", x: 5, y: 5, dir: "down" },
        "registered:2": { nickname: "bob", x: 8, y: 6, dir: "up" },
      },
    },
    ...overrides,
  };
}

function buildEngine(overrides = {}) {
  const renderer = { draw: vi.fn(), resize: vi.fn(), destroy: vi.fn() };
  const scheduler = {
    frames: [],
    request(cb) {
      this.frames.push(cb);
      return this.frames.length;
    },
    cancel: vi.fn(),
    flush() {
      const pending = this.frames.splice(0);
      pending.forEach((cb) => cb(16));
    },
  };

  const engine = new SpaceEngine({
    canvas: fakeCanvas(),
    renderer,
    requestFrame: (cb) => scheduler.request(cb),
    cancelFrame: (id) => scheduler.cancel(id),
    ...overrides,
  });

  return { engine, renderer, scheduler };
}

describe("SpaceEngine", () => {
  let addSpy;
  let removeSpy;

  beforeEach(() => {
    addSpy = vi.spyOn(window, "addEventListener");
    removeSpy = vi.spyOn(window, "removeEventListener");
  });

  it("populates participants from the init snapshot", () => {
    const { engine } = buildEngine();
    engine.start(tavernInit());

    expect(engine.selfKey).toBe("registered:1");
    expect(engine.participant("registered:1").nickname).toBe("alice");
    expect(engine.participant("registered:2").x).toBe(8);
    expect(engine.participantCount()).toBe(2);
  });

  it("runs the render loop and draws each frame", () => {
    const { engine, renderer, scheduler } = buildEngine();
    engine.start(tavernInit());

    scheduler.flush();
    expect(renderer.draw).toHaveBeenCalled();
  });

  it("notifies after a frame is rendered", () => {
    const onFrameRendered = vi.fn();
    const { engine, scheduler } = buildEngine({ onFrameRendered });
    engine.start(tavernInit());

    scheduler.flush();

    expect(onFrameRendered).toHaveBeenCalledOnce();
  });

  it("finds a rendered participant under a canvas point", () => {
    const { engine } = buildEngine();
    engine.start(tavernInit());

    expect(engine.participantAtCanvasPoint(256, 112)?.nickname).toBe("bob");
    expect(engine.participantAtCanvasPoint(10, 10)).toBe(null);
  });

  it("hits the participant drawn on top when avatar bounds overlap", () => {
    const { engine } = buildEngine();
    engine.start(
      tavernInit({
        snapshot: {
          serverTime: 1,
          participants: {
            "registered:1": { nickname: "alice", x: 5, y: 5, dir: "down" },
            "registered:2": { nickname: "bob", x: 5, y: 6, dir: "up" },
          },
        },
      }),
    );

    expect(engine.participantAtCanvasPoint(160, 120)?.nickname).toBe("bob");
  });

  it("applies a delta: moves an existing participant", () => {
    const { engine } = buildEngine();
    engine.start(tavernInit());

    engine.applyDelta({
      serverTime: 2,
      seqAck: {},
      updates: { "registered:2": { x: 9, y: 6, dir: "right" } },
      joined: {},
      left: [],
    });

    expect(engine.participant("registered:2").x).toBe(9);
    expect(engine.participant("registered:2").dir).toBe("right");
  });

  it("applies a delta: joins and leaves", () => {
    const { engine } = buildEngine();
    engine.start(tavernInit());

    engine.applyDelta({
      serverTime: 3,
      seqAck: {},
      updates: {},
      joined: { "registered:3": { nickname: "carol", x: 2, y: 2 } },
      left: ["registered:2"],
    });

    expect(engine.participant("registered:3").nickname).toBe("carol");
    expect(engine.participant("registered:2")).toBe(null);
    expect(engine.participantCount()).toBe(2);
  });

  it("replaces all participants on a fresh snapshot", () => {
    const { engine } = buildEngine();
    engine.start(tavernInit());

    engine.applySnapshot({
      serverTime: 5,
      participants: { "registered:9": { nickname: "zed", x: 1, y: 1 } },
    });

    expect(engine.participantCount()).toBe(1);
    expect(engine.participant("registered:9").nickname).toBe("zed");
  });

  it("attaches a resize listener on start and removes it on destroy", () => {
    const { engine, scheduler } = buildEngine();
    engine.start(tavernInit());
    expect(addSpy).toHaveBeenCalledWith("resize", expect.any(Function));

    engine.destroy();
    expect(removeSpy).toHaveBeenCalledWith("resize", expect.any(Function));
    expect(scheduler.cancel).toHaveBeenCalled();
  });

  it("stops drawing after destroy", () => {
    const { engine, renderer, scheduler } = buildEngine();
    engine.start(tavernInit());
    renderer.draw.mockClear();

    engine.destroy();
    scheduler.flush();

    expect(renderer.draw).not.toHaveBeenCalled();
    expect(renderer.destroy).toHaveBeenCalled();
  });
});

describe("SpaceEngine local prediction and reconciliation", () => {
  function startedEngine(initOverrides = {}) {
    const { engine } = buildEngine();
    engine.start(tavernInit(initOverrides));
    return engine;
  }

  it("predicts a step immediately and tracks it as pending", () => {
    const engine = startedEngine();
    const self = engine.participant("registered:1");

    const result = engine.predict({ dx: 1, dy: 0, dir: "right" });

    expect(result.moved).toBe(true);
    expect(result.seq).toBe(1);
    expect(engine.participant("registered:1").x).toBe(self.x + 1);
    expect(engine.participant("registered:1").dir).toBe("right");
    expect(engine.pendingCount()).toBe(1);
  });

  it("does not predict into a locally-blocked tile", () => {
    // Wall directly to the left of the self spawn at (5,5).
    const engine = startedEngine({
      map: {
        id: "t",
        width: 20,
        height: 15,
        tile_size: 16,
        spawn: [{ x: 1, y: 1, dir: "down" }],
        collision: [{ x: 4, y: 5, w: 1, h: 1, kind: "wall" }],
        zones: [],
        seats: [],
        interactables: [],
      },
    });

    const result = engine.predict({ dx: -1, dy: 0, dir: "left" });

    expect(result.moved).toBe(false);
    expect(engine.participant("registered:1").x).toBe(5);
    expect(engine.pendingCount()).toBe(0);
  });

  it("confirms via seq_ack and discards acknowledged predictions", () => {
    const engine = startedEngine();
    engine.predict({ dx: 1, dy: 0, dir: "right" }); // seq 1 -> x=6
    engine.predict({ dx: 1, dy: 0, dir: "right" }); // seq 2 -> x=7
    expect(engine.pendingCount()).toBe(2);

    engine.applyDelta({
      serverTime: 1,
      seqAck: { "registered:1": 1 },
      updates: { "registered:1": { x: 6, y: 5, dir: "right" } },
      joined: {},
      left: [],
    });

    // Prediction 1 acknowledged; prediction 2 still pending and re-applied.
    expect(engine.pendingCount()).toBe(1);
    expect(engine.participant("registered:1").x).toBe(7);
  });

  it("rolls back a rejected prediction when the server corrects to the old tile", () => {
    const engine = startedEngine();
    const { x } = engine.participant("registered:1");
    engine.predict({ dx: 1, dy: 0, dir: "right" }); // seq 1 -> optimistic x+1
    expect(engine.participant("registered:1").x).toBe(x + 1);

    // Server rejected (e.g. cooldown): it acks seq 1 but reports the OLD tile.
    engine.applyDelta({
      serverTime: 2,
      seqAck: { "registered:1": 1 },
      updates: { "registered:1": { x, y: 5, dir: "right" } },
      joined: {},
      left: [],
    });

    expect(engine.pendingCount()).toBe(0);
    expect(engine.participant("registered:1").x).toBe(x);
  });

  it("interpolates a remote participant's move over time", () => {
    const engine = startedEngine();
    let clock = 0;
    engine.setClock(() => clock);

    engine.applyDelta({
      serverTime: 10,
      seqAck: {},
      updates: { "registered:2": { x: 9, y: 6, dir: "right" } },
      joined: {},
      left: [],
    });

    // registered:2 started at (8,6); it should glide, not teleport.
    clock = 0;
    const mid = engine.renderPosition("registered:2", 60);
    expect(mid.x).toBeGreaterThan(8);
    expect(mid.x).toBeLessThan(9);

    const settled = engine.renderPosition("registered:2", 1000);
    expect(settled.x).toBe(9);
  });
});

describe("SpaceEngine visual actions", () => {
  it("performs a local sword action and expires it from rendered state", () => {
    const { engine, renderer, scheduler } = buildEngine();
    let clock = 1000;
    engine.setClock(() => clock);
    engine.start(tavernInit());

    expect(engine.performAction("sword")).toEqual({ acted: true, kind: "sword", dir: "down" });

    scheduler.flush();
    let state = renderer.draw.mock.calls.at(-1)[0];
    expect(state.participants.get("registered:1").action).toMatchObject({
      kind: "sword",
      dir: "down",
      startedAt: 1000,
    });
    expect(engine.performAction("sword")).toEqual({ acted: false });
    expect(engine.receiveAction({ key: "registered:1", kind: "sword", dir: "left" })).toBe(false);

    clock += 500;
    scheduler.flush();
    state = renderer.draw.mock.calls.at(-1)[0];
    expect(state.participants.get("registered:1").action).toBe(null);
  });

  it("records a remote sword action by participant key", () => {
    const { engine, renderer, scheduler } = buildEngine();
    const clock = 50;
    engine.setClock(() => clock);
    engine.start(tavernInit());

    expect(engine.receiveAction({ key: "registered:2", kind: "sword", dir: "left" })).toBe(true);

    scheduler.flush();
    const state = renderer.draw.mock.calls.at(-1)[0];
    expect(state.participants.get("registered:2").action).toMatchObject({
      kind: "sword",
      dir: "left",
      startedAt: 50,
    });
  });

  it("does not perform an unknown action or swing while sitting", () => {
    const { engine } = buildEngine();
    engine.start(
      tavernInit({
        snapshot: {
          participants: {
            "registered:1": { nickname: "alice", x: 5, y: 5, dir: "down", pose: "sitting" },
          },
        },
      }),
    );

    expect(engine.performAction("dance")).toEqual({ acted: false });
    expect(engine.performAction("sword")).toEqual({ acted: false });
  });
});
