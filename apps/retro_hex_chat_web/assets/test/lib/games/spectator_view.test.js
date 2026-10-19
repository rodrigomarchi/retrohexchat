import { describe, it, expect, vi } from "vitest";
import { createSpectatorView } from "../../../js/lib/games/spectator_view.js";

function element() {
  const el = document.createElement("div");
  el.dataset.token = "tok";
  el.dataset.gameId = "hex_pong";
  el.innerHTML = '<canvas></canvas><div class="game-canvas__stub"></div>';
  return el;
}

describe("spectator view", () => {
  it("builds the game as a spectator and hands it every relayed frame", async () => {
    const el = element();
    let onFrame;
    const wire = { connect: vi.fn(), destroy: vi.fn() };
    const engine = { start: vi.fn(), stop: vi.fn() };
    const engineFactory = vi.fn(async () => engine);

    const view = createSpectatorView(el, {
      engineFactory,
      wireFactory: (options) => {
        onFrame = options.onFrame;
        expect(options.token).toBe("tok");
        return wire;
      },
    });

    await view.mount();

    const args = engineFactory.mock.calls[0][0];
    expect(args.mode).toBe("spectator");
    expect(args.isHost).toBe(false);
    expect(args.gameId).toBe("hex_pong");
    expect(engine.start).toHaveBeenCalled();
    expect(el.querySelector(".game-canvas__stub").classList.contains("u-hidden")).toBe(true);

    const received = vi.fn();
    args.transport.addEventListener("message", received);
    onFrame(new ArrayBuffer(3));
    expect(received).toHaveBeenCalledTimes(1);
    expect(el.dataset.frames).toBe("1");

    view.destroy();
    expect(engine.stop).toHaveBeenCalled();
    expect(wire.destroy).toHaveBeenCalled();
  });
});
