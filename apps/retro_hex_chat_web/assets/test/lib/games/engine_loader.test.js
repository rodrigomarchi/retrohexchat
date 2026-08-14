import { describe, it, expect } from "vitest";
import { GameEngine } from "../../../js/lib/game_engine.js";
import {
  createGameEngine,
  loadP2PEngineClass,
  loadSoloEngineClass,
  supportsSolo,
} from "../../../js/lib/games/engine_loader.js";
import { createLocalTransport } from "../../../js/lib/games/transport.js";

function createCanvas() {
  const canvas = document.createElement("canvas");
  canvas.width = 640;
  canvas.height = 480;
  canvas.getContext = () => ({});
  return canvas;
}

describe("engine loader", () => {
  it("loads the P2P Hex Pong engine by catalog id", async () => {
    const EngineClass = await loadP2PEngineClass("hex_pong");
    expect(EngineClass.name).toBe("PongEngine");
  });

  it("keeps the existing P2P stub fallback for unknown ids", async () => {
    await expect(loadP2PEngineClass("unknown_game")).resolves.toBe(GameEngine);
  });

  it("exposes solo support only for engines with a solo runtime", async () => {
    expect(supportsSolo("hex_pong")).toBe(true);
    expect(supportsSolo("light_trails")).toBe(true);
    expect(supportsSolo("block_breakers")).toBe(false);
    await expect(loadSoloEngineClass("block_breakers")).rejects.toThrow(/solo/i);
  });

  it("creates engines through a mode-aware factory", async () => {
    const opponentController = { nextInputs: () => ({ up: false, down: false }) };
    const engine = await createGameEngine({
      canvas: createCanvas(),
      gameId: "hex_pong",
      mode: "solo",
      transport: createLocalTransport(),
      difficulty: "hard",
      opponentController,
      onGameEnd: null,
    });

    expect(engine.gameId).toBe("hex_pong");
    expect(engine.isHost).toBe(true);
    expect(engine.mode).toBe("solo");
    expect(engine.transport.kind).toBe("local");
    expect(engine.difficulty).toBe("hard");
    expect(engine.opponentController).toBe(opponentController);

    engine.stop();
  });

  it("creates a Light Trails solo engine through the shared factory", async () => {
    const opponentController = { nextDirection: () => 2 };
    const engine = await createGameEngine({
      canvas: createCanvas(),
      gameId: "light_trails",
      mode: "solo",
      transport: createLocalTransport(),
      difficulty: "easy",
      opponentController,
      onGameEnd: null,
    });

    expect(engine.gameId).toBe("light_trails");
    expect(engine.isHost).toBe(true);
    expect(engine.mode).toBe("solo");
    expect(engine.transport.kind).toBe("local");
    expect(engine.difficulty).toBe("easy");
    expect(engine.opponentController).toBe(opponentController);

    engine.stop();
  });
});
