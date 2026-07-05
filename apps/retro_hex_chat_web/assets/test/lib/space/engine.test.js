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
    token: "tok",
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
