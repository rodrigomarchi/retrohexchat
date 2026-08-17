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
    expect(supportsSolo("star_duel")).toBe(true);
    expect(supportsSolo("gravity_well")).toBe(true);
    expect(supportsSolo("debris_field")).toBe(true);
    expect(supportsSolo("hex_raid")).toBe(true);
    expect(supportsSolo("hex_raid_pacifist")).toBe(true);
    expect(supportsSolo("hex_raid_blitz")).toBe(true);
    expect(supportsSolo("hex_outlaw")).toBe(true);
    expect(supportsSolo("hex_outlaw_ricochet")).toBe(true);
    expect(supportsSolo("hex_outlaw_stagecoach")).toBe(true);
    expect(supportsSolo("hex_outlaw_nml")).toBe(true);
    expect(supportsSolo("hex_invaders")).toBe(true);
    expect(supportsSolo("hex_invaders_coop")).toBe(true);
    expect(supportsSolo("hex_invaders_blitz")).toBe(true);
    expect(supportsSolo("hex_enduro")).toBe(true);
    expect(supportsSolo("hex_enduro_night")).toBe(true);
    expect(supportsSolo("hex_enduro_sprint")).toBe(true);
    expect(supportsSolo("hex_skiing")).toBe(true);
    expect(supportsSolo("hex_skiing_escape")).toBe(true);
    expect(supportsSolo("hex_skiing_clean")).toBe(true);
    expect(supportsSolo("hex_tennis")).toBe(true);
    expect(supportsSolo("hex_tennis_quick")).toBe(true);
    expect(supportsSolo("hex_tennis_sudden")).toBe(true);
    expect(supportsSolo("hex_hockey")).toBe(true);
    expect(supportsSolo("hex_hockey_blitz")).toBe(true);
    expect(supportsSolo("hex_hockey_showdown")).toBe(true);
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

  it("creates a Hex Outlaw solo engine through the shared factory", async () => {
    const opponentController = {
      nextInputs: () => ({ up: false, down: false, left: false, right: false, fire: false }),
    };
    const engine = await createGameEngine({
      canvas: createCanvas(),
      gameId: "hex_outlaw_ricochet",
      mode: "solo",
      transport: createLocalTransport(),
      difficulty: "hard",
      opponentController,
      onGameEnd: null,
    });

    expect(engine.gameId).toBe("hex_outlaw_ricochet");
    expect(engine.isHost).toBe(true);
    expect(engine.mode).toBe("solo");
    expect(engine.transport.kind).toBe("local");
    expect(engine.difficulty).toBe("hard");
    expect(engine.opponentController).toBe(opponentController);

    engine.stop();
  });

  it("creates a Star Duel family solo engine through the shared factory", async () => {
    const opponentController = {
      nextInputs: () => ({
        rotateLeft: false,
        rotateRight: false,
        thrust: false,
        fire: false,
        warp: false,
      }),
    };
    const engine = await createGameEngine({
      canvas: createCanvas(),
      gameId: "gravity_well",
      mode: "solo",
      transport: createLocalTransport(),
      difficulty: "hard",
      opponentController,
      onGameEnd: null,
    });

    expect(engine.gameId).toBe("gravity_well");
    expect(engine.isHost).toBe(true);
    expect(engine.mode).toBe("solo");
    expect(engine.gameMode).toBe(1);
    expect(engine.transport.kind).toBe("local");
    expect(engine.difficulty).toBe("hard");
    expect(engine.opponentController).toBe(opponentController);

    engine.stop();
  });

  it("creates a Hex Raid family solo engine through the shared factory", async () => {
    const engine = await createGameEngine({
      canvas: createCanvas(),
      gameId: "hex_raid_blitz",
      mode: "solo",
      transport: createLocalTransport(),
      difficulty: "hard",
      onGameEnd: null,
    });

    expect(engine.gameId).toBe("hex_raid_blitz");
    expect(engine.isHost).toBe(true);
    expect(engine.mode).toBe("solo");
    expect(engine.gameMode).toBe(2);
    expect(engine.transport.kind).toBe("local");
    expect(engine.difficulty).toBe("hard");
    expect(engine.opponentController?.nextInputs).toEqual(expect.any(Function));

    engine.stop();
  });

  it("creates a Hex Tennis family solo engine through the shared factory", async () => {
    const opponentController = {
      nextInputs: () => ({
        up: false,
        down: false,
        left: false,
        right: false,
        serve: false,
      }),
    };
    const engine = await createGameEngine({
      canvas: createCanvas(),
      gameId: "hex_tennis_sudden",
      mode: "solo",
      transport: createLocalTransport(),
      difficulty: "hard",
      opponentController,
      onGameEnd: null,
    });

    expect(engine.gameId).toBe("hex_tennis_sudden");
    expect(engine.isHost).toBe(true);
    expect(engine.mode).toBe("solo");
    expect(engine.gameMode).toBe(2);
    expect(engine.transport.kind).toBe("local");
    expect(engine.difficulty).toBe("hard");
    expect(engine.opponentController).toBe(opponentController);

    engine.stop();
  });

  it("creates a Hex Invaders family solo engine through the shared factory", async () => {
    const opponentController = {
      nextInputs: () => ({ left: false, right: false, fire: false }),
    };
    const engine = await createGameEngine({
      canvas: createCanvas(),
      gameId: "hex_invaders_blitz",
      mode: "solo",
      transport: createLocalTransport(),
      difficulty: "hard",
      opponentController,
      onGameEnd: null,
    });

    expect(engine.gameId).toBe("hex_invaders_blitz");
    expect(engine.isHost).toBe(true);
    expect(engine.mode).toBe("solo");
    expect(engine.gameMode).toBe(2);
    expect(engine.transport.kind).toBe("local");
    expect(engine.difficulty).toBe("hard");
    expect(engine.opponentController).toBe(opponentController);

    engine.stop();
  });

  it("creates a Hex Enduro family solo engine through the shared factory", async () => {
    const engine = await createGameEngine({
      canvas: createCanvas(),
      gameId: "hex_enduro_sprint",
      mode: "solo",
      transport: createLocalTransport(),
      difficulty: "hard",
      onGameEnd: null,
    });

    expect(engine.gameId).toBe("hex_enduro_sprint");
    expect(engine.isHost).toBe(true);
    expect(engine.mode).toBe("solo");
    expect(engine.gameMode).toBe(2);
    expect(engine.transport.kind).toBe("local");
    expect(engine.difficulty).toBe("hard");
    expect(engine.opponentController?.nextInputs).toEqual(expect.any(Function));

    engine.stop();
  });

  it("creates a Hex Skiing family solo engine through the shared factory", async () => {
    const engine = await createGameEngine({
      canvas: createCanvas(),
      gameId: "hex_skiing_clean",
      mode: "solo",
      transport: createLocalTransport(),
      difficulty: "hard",
      onGameEnd: null,
    });

    expect(engine.gameId).toBe("hex_skiing_clean");
    expect(engine.isHost).toBe(true);
    expect(engine.mode).toBe("solo");
    expect(engine.gameMode).toBe(2);
    expect(engine.transport.kind).toBe("local");
    expect(engine.difficulty).toBe("hard");
    expect(engine.opponentController?.nextInputs).toEqual(expect.any(Function));

    engine.stop();
  });

  it("creates a Hex Hockey family solo engine through the shared factory", async () => {
    const opponentController = {
      nextInputs: () => ({
        left: false,
        right: false,
        up: false,
        down: false,
        action: false,
      }),
    };
    const engine = await createGameEngine({
      canvas: createCanvas(),
      gameId: "hex_hockey_showdown",
      mode: "solo",
      transport: createLocalTransport(),
      difficulty: "hard",
      opponentController,
      onGameEnd: null,
    });

    expect(engine.gameId).toBe("hex_hockey_showdown");
    expect(engine.isHost).toBe(true);
    expect(engine.mode).toBe("solo");
    expect(engine.gameMode).toBe(2);
    expect(engine.transport.kind).toBe("local");
    expect(engine.difficulty).toBe("hard");
    expect(engine.opponentController).toBe(opponentController);

    engine.stop();
  });
});
