import { describe, it, expect } from "vitest";
import { GameEngine } from "../../../js/lib/game_engine.js";
import {
  createGameEngine,
  loadP2PEngineClass,
  loadSoloEngineClass,
  supportsSolo,
} from "../../../js/lib/games/engine_loader.js";
import { GAME_MODE } from "../../../js/lib/games/pixel_tanks/protocol.js";
import { createLocalTransport } from "../../../js/lib/games/transport.js";

function createCanvas() {
  const canvas = document.createElement("canvas");
  canvas.width = 640;
  canvas.height = 480;
  canvas.getContext = () => ({});
  return canvas;
}

/**
 * A solo engine of each family, made through the factory: an opponent given
 * is kept, otherwise the game makes its own AI; `plays` is the difficulty the
 * engine ends up with.
 */
const SOLO_ENGINES = [
  {
    name: "Hex Pong",
    gameId: "hex_pong",
    opponentController: { nextInputs: () => ({ up: false, down: false }) },
  },
  {
    name: "Light Trails",
    gameId: "light_trails",
    difficulty: "easy",
    opponentController: { nextDirection: () => 2 },
  },
  {
    name: "Hex Outlaw",
    gameId: "hex_outlaw_ricochet",
    opponentController: {
      nextInputs: () => ({ up: false, down: false, left: false, right: false, fire: false }),
    },
  },
  {
    name: "Star Duel family",
    gameId: "gravity_well",
    gameMode: 1,
    opponentController: {
      nextInputs: () => ({
        rotateLeft: false,
        rotateRight: false,
        thrust: false,
        fire: false,
        warp: false,
      }),
    },
  },
  { name: "Hex Raid family", gameId: "hex_raid_blitz", gameMode: 2 },
  { name: "Hex Boxing", gameId: "hex_boxing" },
  { name: "Pixel Tanks", gameId: "pixel_tanks", gameMode: GAME_MODE.RICOCHET },
  // The AI is the player's partner: a hard game gets the weakest one
  { name: "Block Breakers", gameId: "block_breakers", plays: "easy" },
  { name: "Hex Warlords", gameId: "hex_warlords" },
  {
    name: "Hex Tennis family",
    gameId: "hex_tennis_sudden",
    gameMode: 2,
    opponentController: {
      nextInputs: () => ({ up: false, down: false, left: false, right: false, serve: false }),
    },
  },
  {
    name: "Hex Invaders family",
    gameId: "hex_invaders_blitz",
    gameMode: 2,
    opponentController: { nextInputs: () => ({ left: false, right: false, fire: false }) },
  },
  { name: "Hex Enduro family", gameId: "hex_enduro_sprint", gameMode: 2 },
  { name: "Hex Skiing family", gameId: "hex_skiing_clean", gameMode: 2 },
  { name: "Hex Frost family", gameId: "hex_frost_peaceful", gameMode: 2 },
  { name: "Hex Hockey family", gameId: "hex_hockey_showdown", gameMode: 2 },
];

describe("engine loader", () => {
  it("loads the P2P Hex Pong engine by catalog id", async () => {
    const EngineClass = await loadP2PEngineClass("hex_pong");
    expect(EngineClass).toBe((await import("../../../js/lib/games/pong/index.js")).default);
  });

  it("keeps the existing P2P stub fallback for unknown ids", async () => {
    await expect(loadP2PEngineClass("unknown_game")).resolves.toBe(GameEngine);
  });

  it("exposes solo support only for engines with a solo runtime", async () => {
    expect(supportsSolo("hex_pong")).toBe(true);
    expect(supportsSolo("light_trails")).toBe(true);
    expect(supportsSolo("pixel_tanks")).toBe(true);
    expect(supportsSolo("star_duel")).toBe(true);
    expect(supportsSolo("gravity_well")).toBe(true);
    expect(supportsSolo("debris_field")).toBe(true);
    expect(supportsSolo("block_breakers")).toBe(true);
    expect(supportsSolo("hex_warlords")).toBe(true);
    expect(supportsSolo("hex_raid")).toBe(true);
    expect(supportsSolo("hex_raid_pacifist")).toBe(true);
    expect(supportsSolo("hex_raid_blitz")).toBe(true);
    expect(supportsSolo("hex_boxing")).toBe(true);
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
    expect(supportsSolo("hex_frost")).toBe(true);
    expect(supportsSolo("hex_frost_blizzard")).toBe(true);
    expect(supportsSolo("hex_frost_peaceful")).toBe(true);
    expect(supportsSolo("hex_tennis")).toBe(true);
    expect(supportsSolo("hex_tennis_quick")).toBe(true);
    expect(supportsSolo("hex_tennis_sudden")).toBe(true);
    expect(supportsSolo("hex_hockey")).toBe(true);
    expect(supportsSolo("hex_hockey_blitz")).toBe(true);
    expect(supportsSolo("hex_hockey_showdown")).toBe(true);
    expect(supportsSolo("unknown_game")).toBe(false);
    await expect(loadSoloEngineClass("unknown_game")).rejects.toThrow(/solo/i);
  });

  it.each(SOLO_ENGINES)(
    "creates a $name solo engine through the shared factory",
    async ({ gameId, opponentController, gameMode, difficulty = "hard", plays = difficulty }) => {
      const engine = await createGameEngine({
        canvas: createCanvas(),
        gameId,
        mode: "solo",
        transport: createLocalTransport(),
        difficulty,
        ...(opponentController ? { opponentController } : {}),
        onGameEnd: null,
      });

      expect(engine.gameId).toBe(gameId);
      expect(engine.isHost).toBe(true);
      expect(engine.mode).toBe("solo");
      if (gameMode !== undefined) expect(engine.gameMode).toBe(gameMode);
      expect(engine.transport.kind).toBe("local");
      expect(engine.difficulty).toBe(plays);
      if (opponentController) {
        expect(engine.opponentController).toBe(opponentController);
      } else {
        expect(engine.opponentController?.nextInputs).toEqual(expect.any(Function));
      }

      engine.stop();
    },
  );
});
