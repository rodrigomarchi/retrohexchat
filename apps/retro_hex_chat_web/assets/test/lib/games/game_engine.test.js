import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { GameEngine, keymap } from "../../../js/lib/game_engine.js";

describe("game_engine", () => {
  describe("GameEngine", () => {
    let canvas;
    let channel;
    let engine;
    let ctx;

    beforeEach(() => {
      ctx = {
        fillStyle: "",
        strokeStyle: "",
        lineWidth: 0,
        font: "",
        textAlign: "",
        fillRect: vi.fn(),
        fillText: vi.fn(),
        strokeRect: vi.fn(),
      };

      canvas = {
        width: 640,
        height: 480,
        getContext: vi.fn(() => ctx),
      };

      // Stub getComputedStyle
      vi.spyOn(globalThis, "getComputedStyle").mockReturnValue({
        getPropertyValue: () => "",
      });

      channel = {
        readyState: "open",
        addEventListener: vi.fn(),
        removeEventListener: vi.fn(),
        send: vi.fn(),
      };
    });

    afterEach(() => {
      vi.restoreAllMocks();
      if (engine) {
        engine.stop();
        engine = null;
      }
    });

    it("creates with correct properties", () => {
      engine = new GameEngine(canvas, channel, "hex_pong", true);
      expect(engine.gameId).toBe("hex_pong");
      expect(engine.isHost).toBe(true);
      expect(engine.running).toBe(false);
      expect(engine.animFrame).toBeNull();
    });

    /** Run the engine's animation frames by hand, `ms` apart. */
    function frames() {
      const pending = [];
      vi.spyOn(globalThis, "requestAnimationFrame").mockImplementation((callback) => {
        pending.push(callback);
        return pending.length;
      });
      const cancel = vi.spyOn(globalThis, "cancelAnimationFrame").mockImplementation(() => {});
      let now = 0;
      return {
        cancel,
        run(count, ms = 1000 / 60) {
          for (let i = 0; i < count; i++) {
            now += ms;
            pending.shift()?.(now);
          }
        },
      };
    }

    it("starts listening to its channel, and sends nothing of its own", () => {
      engine = new GameEngine(canvas, channel, "hex_pong", true);
      engine.start();

      expect(engine.running).toBe(true);
      expect(channel.addEventListener).toHaveBeenCalledWith("message", expect.any(Function));
      expect(channel.send).not.toHaveBeenCalled();
    });

    it("stops listening and cancels its animation frame when stopped", () => {
      const clock = frames();
      engine = new GameEngine(canvas, channel, "hex_pong", true);
      engine.start();
      const frame = engine.animFrame;
      engine.stop();

      expect(engine.running).toBe(false);
      expect(channel.removeEventListener).toHaveBeenCalledWith("message", expect.any(Function));
      expect(clock.cancel).toHaveBeenCalledWith(frame);
      expect(engine.animFrame).toBeNull();
    });

    describe("a guest's held keys", () => {
      class Paddle extends GameEngine {
        static INPUT_BITS = { up: 0 };
        static KEYMAP = keymap({ up: ["ArrowUp"] });
      }

      const hold = () =>
        window.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowUp", cancelable: true }));

      afterEach(() => {
        window.dispatchEvent(new KeyboardEvent("keyup", { key: "ArrowUp", cancelable: true }));
      });

      it("go to the host while the channel is open", () => {
        const clock = frames();
        engine = new Paddle(canvas, channel, "hex_pong", false);
        engine.start();
        hold();
        clock.run(5);
        expect(channel.send).toHaveBeenCalled();
      });

      it("are not sent on a closed channel", () => {
        const clock = frames();
        channel.readyState = "closed";
        engine = new Paddle(canvas, channel, "hex_pong", false);
        engine.start();
        hold();
        clock.run(5);
        expect(channel.send).not.toHaveBeenCalled();
      });

      it("survive a channel that throws on send", () => {
        const clock = frames();
        channel.send = vi.fn(() => {
          throw new Error("closed");
        });
        vi.spyOn(console, "error").mockImplementation(() => {});
        engine = new Paddle(canvas, channel, "hex_pong", false);
        engine.start();
        hold();
        expect(() => clock.run(5)).not.toThrow();
        expect(channel.send).toHaveBeenCalled();
      });
    });

    describe("keyboard target", () => {
      class Paddle extends GameEngine {
        static INPUT_BITS = { up: 0 };
        static KEYMAP = keymap({ up: ["ArrowUp"] });
      }

      const press = (target, type) =>
        target.dispatchEvent(new KeyboardEvent(type, { key: "ArrowUp", cancelable: true }));

      it("reads the keyboard from the target it is given, not the window", () => {
        const keyboardTarget = new EventTarget();
        engine = new Paddle(canvas, channel, "hex_pong", true, { keyboardTarget });
        engine.start();

        press(window, "keydown");
        expect(engine.localInputs.up).toBeUndefined();

        press(keyboardTarget, "keydown");
        expect(engine.localInputs.up).toBe(true);

        press(keyboardTarget, "keyup");
        expect(engine.localInputs.up).toBe(false);
      });

      it("stops reading the target once stopped", () => {
        const keyboardTarget = new EventTarget();
        engine = new Paddle(canvas, channel, "hex_pong", true, { keyboardTarget });
        engine.start();
        engine.stop();

        press(keyboardTarget, "keydown");
        expect(engine.localInputs.up).toBeUndefined();
      });

      it("reads the window when no target is given", () => {
        engine = new Paddle(canvas, channel, "hex_pong", true);
        engine.start();

        press(window, "keydown");
        expect(engine.localInputs.up).toBe(true);
        press(window, "keyup");
      });
    });
  });
});
