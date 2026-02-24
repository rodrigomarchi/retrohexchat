import { describe, it, expect, vi, beforeEach } from "vitest";
import { BoxingEngine } from "../../../../js/lib/games/hex_boxing/engine.js";
import { PHASE } from "../../../../js/lib/games/hex_boxing/protocol.js";

function createMockCanvas() {
  const ctx = {
    fillRect: vi.fn(),
    strokeRect: vi.fn(),
    fillText: vi.fn(),
    beginPath: vi.fn(),
    arc: vi.fn(),
    fill: vi.fn(),
    stroke: vi.fn(),
    moveTo: vi.fn(),
    lineTo: vi.fn(),
    clearRect: vi.fn(),
    save: vi.fn(),
    restore: vi.fn(),
    fillStyle: "",
    strokeStyle: "",
    lineWidth: 1,
    lineCap: "butt",
    font: "",
    textAlign: "start",
    textBaseline: "alphabetic",
  };
  const canvas = {
    width: 640,
    height: 480,
    getContext: () => ctx,
  };
  // Mock getComputedStyle
  vi.spyOn(window, "getComputedStyle").mockReturnValue({
    getPropertyValue: (prop) => {
      const map = {
        "--game-bg-color": "#0a0808",
        "--game-fg-color": "#39ff14",
        "--game-accent-color": "#00e5ff",
        "--game-muted-color": "#2a1a1a",
        "--game-glow-color": "rgba(57, 255, 20, 0.15)",
        "--game-warning-color": "#ff4444",
        "--game-rope-color": "#aaaaaa",
        "--game-ring-color": "#1a1208",
        "--game-hit-color": "#ffffff",
      };
      return map[prop] || "";
    },
  });
  return canvas;
}

function createMockChannel() {
  return {
    readyState: "open",
    send: vi.fn(),
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
  };
}

describe("BoxingEngine", () => {
  let canvas;
  let channel;

  beforeEach(() => {
    canvas = createMockCanvas();
    channel = createMockChannel();
    vi.spyOn(window, "addEventListener").mockImplementation(() => {});
    vi.spyOn(window, "removeEventListener").mockImplementation(() => {});
  });

  it("creates engine with correct initial state", () => {
    const engine = new BoxingEngine(canvas, channel, "hex_boxing", true, null);
    expect(engine.isHost).toBe(true);
    expect(engine.gameState.phase).toBe(PHASE.WAITING);
    expect(engine.gameState.score1).toBe(0);
    expect(engine.gameState.score2).toBe(0);
  });

  it("host starts and renders initial state", () => {
    const engine = new BoxingEngine(canvas, channel, "hex_boxing", true, null);
    engine.start();
    // Should not send GAME_READY (that's peer only)
    expect(channel.send).not.toHaveBeenCalled();
    engine.stop();
  });

  it("peer sends GAME_READY on start", () => {
    const engine = new BoxingEngine(canvas, channel, "hex_boxing", false, null);
    engine.start();
    expect(channel.send).toHaveBeenCalledTimes(1);
    engine.stop();
  });

  it("stop cleans up", () => {
    const engine = new BoxingEngine(canvas, channel, "hex_boxing", true, null);
    engine.start();
    engine.stop();
    expect(engine.running).toBe(false);
  });

  it("_mapKey maps arrow keys correctly", () => {
    const engine = new BoxingEngine(canvas, channel, "hex_boxing", true, null);
    expect(engine._mapKey("ArrowUp")).toBe(0); // UP
    expect(engine._mapKey("ArrowDown")).toBe(1); // DOWN
    expect(engine._mapKey("ArrowLeft")).toBe(2); // LEFT
    expect(engine._mapKey("ArrowRight")).toBe(3); // RIGHT
    expect(engine._mapKey(" ")).toBe(4); // PUNCH
    expect(engine._mapKey("Shift")).toBe(4); // PUNCH
  });

  it("_mapKey maps WASD keys correctly", () => {
    const engine = new BoxingEngine(canvas, channel, "hex_boxing", true, null);
    expect(engine._mapKey("w")).toBe(0);
    expect(engine._mapKey("s")).toBe(1);
    expect(engine._mapKey("a")).toBe(2);
    expect(engine._mapKey("d")).toBe(3);
  });

  it("_mapKey returns null for unmapped keys", () => {
    const engine = new BoxingEngine(canvas, channel, "hex_boxing", true, null);
    expect(engine._mapKey("q")).toBeNull();
    expect(engine._mapKey("z")).toBeNull();
  });

  it("_dirFromInputs computes direction from booleans", () => {
    const engine = new BoxingEngine(canvas, channel, "hex_boxing", true, null);
    expect(
      engine._dirFromInputs({ up: false, down: false, left: false, right: true, punch: false }),
    ).toBe(0);
    expect(
      engine._dirFromInputs({ up: false, down: false, left: true, right: false, punch: false }),
    ).toBe(4);
    expect(
      engine._dirFromInputs({ up: true, down: false, left: false, right: false, punch: false }),
    ).toBe(6);
    expect(
      engine._dirFromInputs({ up: false, down: true, left: false, right: false, punch: false }),
    ).toBe(2);
    expect(
      engine._dirFromInputs({ up: true, down: false, left: false, right: true, punch: false }),
    ).toBe(7);
    expect(
      engine._dirFromInputs({ up: false, down: false, left: false, right: false, punch: false }),
    ).toBe(-1);
  });

  it("_safeSend handles closed channel gracefully", () => {
    const closedChannel = { ...createMockChannel(), readyState: "closed" };
    const engine = new BoxingEngine(canvas, closedChannel, "hex_boxing", true, null);
    // Should not throw
    engine._safeSend(new ArrayBuffer(10));
    expect(closedChannel.send).not.toHaveBeenCalled();
  });

  it("_handleBlur resets all local inputs", () => {
    const engine = new BoxingEngine(canvas, channel, "hex_boxing", true, null);
    engine.localInputs = { up: true, down: true, left: true, right: true, punch: true };
    engine._handleBlur();
    expect(engine.localInputs.up).toBe(false);
    expect(engine.localInputs.down).toBe(false);
    expect(engine.localInputs.left).toBe(false);
    expect(engine.localInputs.right).toBe(false);
    expect(engine.localInputs.punch).toBe(false);
  });

  it("_handleBlur on peer sends key releases", () => {
    const engine = new BoxingEngine(canvas, channel, "hex_boxing", false, null);
    engine.localInputs = { up: true, down: true, left: true, right: true, punch: true };
    engine._handleBlur();
    // 5 key releases sent
    expect(channel.send).toHaveBeenCalledTimes(5);
  });

  it("_handleBlur on host does not send key releases", () => {
    const engine = new BoxingEngine(canvas, channel, "hex_boxing", true, null);
    engine.localInputs = { up: true, down: true, left: true, right: true, punch: true };
    engine._handleBlur();
    expect(channel.send).not.toHaveBeenCalled();
  });

  it("_mapKey maps uppercase WASD keys", () => {
    const engine = new BoxingEngine(canvas, channel, "hex_boxing", true, null);
    expect(engine._mapKey("W")).toBe(0);
    expect(engine._mapKey("S")).toBe(1);
    expect(engine._mapKey("A")).toBe(2);
    expect(engine._mapKey("D")).toBe(3);
  });

  it("_dirFromInputs handles opposing directions (cancel out)", () => {
    const engine = new BoxingEngine(canvas, channel, "hex_boxing", true, null);
    // Both left and right → right takes priority (code checks right first)
    expect(
      engine._dirFromInputs({ up: false, down: false, left: true, right: true, punch: false }),
    ).toBe(-1);
    // Both up and down → cancels
    expect(
      engine._dirFromInputs({ up: true, down: true, left: false, right: false, punch: false }),
    ).toBe(-1);
  });

  it("_dirFromInputs returns all 8 diagonal directions", () => {
    const engine = new BoxingEngine(canvas, channel, "hex_boxing", true, null);
    // up-left
    expect(
      engine._dirFromInputs({ up: true, down: false, left: true, right: false, punch: false }),
    ).toBe(5);
    // down-left
    expect(
      engine._dirFromInputs({ up: false, down: true, left: true, right: false, punch: false }),
    ).toBe(3);
    // down-right
    expect(
      engine._dirFromInputs({ up: false, down: true, left: false, right: true, punch: false }),
    ).toBe(1);
  });

  it("stop is safe to call multiple times", () => {
    const engine = new BoxingEngine(canvas, channel, "hex_boxing", true, null);
    engine.start();
    engine.stop();
    // Second stop should not throw
    expect(() => engine.stop()).not.toThrow();
  });
});
