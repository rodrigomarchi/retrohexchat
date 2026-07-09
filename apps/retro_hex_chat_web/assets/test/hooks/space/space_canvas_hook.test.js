import { describe, it, expect, vi } from "vitest";

import { createSpaceCanvasHook } from "../../../js/hooks/space/space_canvas_hook.js";
import { lazyFeatureHooks } from "../../../js/hooks/lazy_feature_hooks.js";

function fakeChannel() {
  const handlers = {};
  const receivers = {};
  const channel = {
    handlers,
    on: vi.fn((event, cb) => {
      handlers[event] = cb;
    }),
    join: vi.fn(() => {
      const chain = {
        receive: vi.fn((status, cb) => {
          receivers[status] = cb;
          return chain;
        }),
      };
      channel._receivers = receivers;
      return chain;
    }),
    leave: vi.fn(),
    push: vi.fn(),
  };
  return channel;
}

function fakeSocket(channel) {
  return {
    connect: vi.fn(),
    disconnect: vi.fn(),
    channel: vi.fn(() => channel),
  };
}

function mountContext() {
  const el = document.createElement("div");
  el.dataset.spaceChannel = "#lobby";
  el.dataset.joinToken = "signed-join-token";
  el.dataset.nickname = "alice";
  const canvas = document.createElement("canvas");
  el.appendChild(canvas);
  return { el, canvas };
}

function mountContextWithLoading() {
  const ctx = mountContext();
  const loading = document.createElement("div");
  loading.dataset.spaceLoading = "";
  loading.innerHTML = `
    <div data-space-loading-panel aria-label="Channel Space: Entering channel space...">
      <div><span>Channel Space</span></div>
      <span data-space-loading-text>Entering channel space...</span>
    </div>
  `;
  ctx.el.appendChild(loading);
  return { ...ctx, loading };
}

describe("SpaceCanvasHook lazy registration", () => {
  it("registers with serverEvents [] and a reason (channel-driven, no push_event)", () => {
    const meta = lazyFeatureHooks.SpaceCanvasHook.__lazyFeature;
    expect(meta.name).toBe("SpaceCanvasHook");
    expect(meta.serverEvents).toEqual([]);
    expect(meta.readyEvent).toBe(null);
    expect(typeof meta.reason).toBe("string");
    expect(meta.reason.length).toBeGreaterThan(0);
  });
});

describe("SpaceCanvasHook implementation", () => {
  it("mounts an engine, connects the socket and joins the space channel", () => {
    const engine = {
      start: vi.fn(),
      applyDelta: vi.fn(),
      applySnapshot: vi.fn(),
      receiveAction: vi.fn(),
      destroy: vi.fn(),
    };
    const channel = fakeChannel();
    const socket = fakeSocket(channel);
    const hook = Object.assign(
      Object.create(
        createSpaceCanvasHook({
          socketFactory: () => socket,
          engineFactory: () => engine,
        }),
      ),
      mountContext(),
    );

    hook.mounted();

    expect(socket.connect).toHaveBeenCalled();
    expect(socket.channel).toHaveBeenCalledWith("space:#lobby", {
      join_token: "signed-join-token",
    });
    expect(channel.join).toHaveBeenCalled();
  });

  it("starts the engine from the normalized space_init join reply", () => {
    const engine = {
      start: vi.fn(),
      applyDelta: vi.fn(),
      applySnapshot: vi.fn(),
      destroy: vi.fn(),
    };
    const channel = fakeChannel();
    const socket = fakeSocket(channel);
    const hook = Object.assign(
      Object.create(
        createSpaceCanvasHook({ socketFactory: () => socket, engineFactory: () => engine }),
      ),
      mountContext(),
    );

    hook.mounted();
    channel._receivers.ok({
      version: 1,
      channel_name: "#lobby",
      self_key: "registered:1",
      map: { id: "tavern_cafe_v1", width: 10, height: 8, tile_size: 16 },
      snapshot: { participants: { "registered:1": { nickname: "alice", x: 1, y: 1 } } },
    });

    expect(engine.start).toHaveBeenCalledOnce();
    const init = engine.start.mock.calls[0][0];
    expect(init.selfKey).toBe("registered:1");
    expect(init.snapshot.participants["registered:1"].nickname).toBe("alice");
  });

  it("keeps the loading panel until a frame renders after assets are ready", () => {
    let frameRendered;
    const engine = {
      start: vi.fn(),
      applyDelta: vi.fn(),
      applySnapshot: vi.fn(),
      destroy: vi.fn(),
    };
    const channel = fakeChannel();
    const socket = fakeSocket(channel);
    const hook = Object.assign(
      Object.create(
        createSpaceCanvasHook({
          socketFactory: () => socket,
          engineFactory: (opts) => {
            frameRendered = opts.onFrameRendered;
            return engine;
          },
        }),
      ),
      mountContextWithLoading(),
    );

    hook.mounted();

    expect(hook.loading.hidden).toBe(false);
    expect(hook.loading.querySelector("[data-space-loading-text]").textContent).toBe(
      "Connecting to space...",
    );

    frameRendered();
    expect(hook.loading.hidden).toBe(false);

    hook._assetsReady = true;
    frameRendered();
    expect(hook.loading.hidden).toBe(true);
    expect(hook.loading.getAttribute("aria-hidden")).toBe("true");
  });

  it("updates the loading panel when channel join fails", () => {
    const engine = {
      start: vi.fn(),
      applyDelta: vi.fn(),
      applySnapshot: vi.fn(),
      destroy: vi.fn(),
    };
    const channel = fakeChannel();
    const socket = fakeSocket(channel);
    const hook = Object.assign(
      Object.create(
        createSpaceCanvasHook({
          socketFactory: () => socket,
          engineFactory: () => engine,
        }),
      ),
      mountContextWithLoading(),
    );

    hook.mounted();
    channel._receivers.error({ reason: "forbidden" });

    expect(hook.loading.querySelector("[data-space-loading-text]").textContent).toBe(
      "Could not open space.",
    );
  });

  it("routes channel delta/snapshot/action events into the engine", () => {
    const engine = {
      start: vi.fn(),
      applyDelta: vi.fn(),
      applySnapshot: vi.fn(),
      receiveAction: vi.fn(),
      destroy: vi.fn(),
    };
    const channel = fakeChannel();
    const socket = fakeSocket(channel);
    const hook = Object.assign(
      Object.create(
        createSpaceCanvasHook({ socketFactory: () => socket, engineFactory: () => engine }),
      ),
      mountContext(),
    );

    hook.mounted();
    channel.handlers.space_delta({ updates: {}, joined: {}, left: [] });
    channel.handlers.space_snapshot({ participants: {} });
    channel.handlers.space_action({ key: "registered:2", kind: "sword", dir: "left" });

    expect(engine.applyDelta).toHaveBeenCalledOnce();
    expect(engine.applySnapshot).toHaveBeenCalledOnce();
    expect(engine.receiveAction).toHaveBeenCalledWith({
      key: "registered:2",
      kind: "sword",
      dir: "left",
    });
  });

  it("tears down the engine, channel and socket on destroyed", () => {
    const engine = {
      start: vi.fn(),
      applyDelta: vi.fn(),
      applySnapshot: vi.fn(),
      receiveAction: vi.fn(),
      destroy: vi.fn(),
    };
    const channel = fakeChannel();
    const socket = fakeSocket(channel);
    const hook = Object.assign(
      Object.create(
        createSpaceCanvasHook({ socketFactory: () => socket, engineFactory: () => engine }),
      ),
      mountContext(),
    );

    hook.mounted();
    hook.destroyed();

    expect(engine.destroy).toHaveBeenCalled();
    expect(channel.leave).toHaveBeenCalled();
    expect(socket.disconnect).toHaveBeenCalled();
  });

  it("predicts a key intent locally and pushes only the accepted step", () => {
    const engine = {
      start: vi.fn(),
      applyDelta: vi.fn(),
      applySnapshot: vi.fn(),
      destroy: vi.fn(),
      predict: vi.fn(),
    };
    const channel = fakeChannel();
    const socket = fakeSocket(channel);
    let intentCb;
    const input = {
      attach: vi.fn(),
      detach: vi.fn(),
    };
    const inputFactory = ({ onIntent }) => {
      intentCb = onIntent;
      return input;
    };

    const hook = Object.assign(
      Object.create(
        createSpaceCanvasHook({
          socketFactory: () => socket,
          engineFactory: () => engine,
          inputFactory,
        }),
      ),
      mountContext(),
    );

    hook.mounted();
    expect(input.attach).toHaveBeenCalled();

    // Accepted (locally-free) step is pushed with its prediction seq.
    engine.predict.mockReturnValueOnce({ moved: true, seq: 7, dx: 1, dy: 0, dir: "right" });
    intentCb({ dx: 1, dy: 0, dir: "right" });
    expect(channel.push).toHaveBeenCalledWith("space_input", { seq: 7, dx: 1, dy: 0 });

    // A locally-blocked step predicts but is not sent.
    channel.push.mockClear();
    engine.predict.mockReturnValueOnce({ moved: false });
    intentCb({ dx: -1, dy: 0, dir: "left" });
    expect(channel.push).not.toHaveBeenCalled();

    hook.destroyed();
    expect(input.detach).toHaveBeenCalled();
  });

  it("plays a local attack and broadcasts a visual space action", () => {
    const engine = {
      start: vi.fn(),
      applyDelta: vi.fn(),
      applySnapshot: vi.fn(),
      destroy: vi.fn(),
      performAction: vi.fn(),
    };
    const channel = fakeChannel();
    const socket = fakeSocket(channel);
    let actionCb;
    const input = {
      attach: vi.fn(),
      detach: vi.fn(),
    };
    const inputFactory = ({ onAction }) => {
      actionCb = onAction;
      return input;
    };

    const hook = Object.assign(
      Object.create(
        createSpaceCanvasHook({
          socketFactory: () => socket,
          engineFactory: () => engine,
          inputFactory,
        }),
      ),
      mountContext(),
    );

    hook.mounted();

    engine.performAction.mockReturnValueOnce({ acted: true, kind: "sword", dir: "down" });
    actionCb("attack");
    expect(channel.push).toHaveBeenCalledWith("space_action", { kind: "sword", dir: "down" });

    channel.push.mockClear();
    engine.performAction.mockReturnValueOnce({ acted: false });
    actionCb("attack");
    expect(channel.push).not.toHaveBeenCalled();

    hook.destroyed();
  });
});
