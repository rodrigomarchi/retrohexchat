import { describe, it, expect, afterEach } from "vitest";
import { loadP2PEngineClass } from "../../../js/lib/games/engine_loader.js";
import { keymap } from "../../../js/lib/game_engine.js";
import { playMatch } from "../../support/games/harness.js";
import { ENGINE_GAME_IDS } from "../../support/games/engines.js";

// Every engine whose keys hold an input (Light Trails steers by command).
const GAMES = ENGINE_GAME_IDS.filter((id) => id !== "light_trails");

describe("keymap", () => {
  it("turns each input's keys into a frozen key-to-input table", () => {
    const map = keymap({ up: ["ArrowUp", "w"], fire: [" "] });
    expect(map).toEqual({ ArrowUp: "up", w: "up", " ": "fire" });
    expect(Object.isFrozen(map)).toBe(true);
  });
});

describe.each(GAMES)("%s keys", (gameId) => {
  let match;

  afterEach(() => {
    match?.stop();
    match?.restore();
    match = null;
  });

  it("drive exactly the inputs the game sends", async () => {
    const Engine = await loadP2PEngineClass(gameId);
    expect(new Set(Object.values(Engine.KEYMAP))).toEqual(new Set(Object.keys(Engine.INPUT_BITS)));
  });

  it("hold their input while down and release it on up, keeping it from the page", async () => {
    const Engine = await loadP2PEngineClass(gameId);
    match = await playMatch({ gameId });
    const { guest } = match.engines;

    for (const [name, input] of Object.entries(Engine.KEYMAP)) {
      expect(match.key("guest", name, "keydown").defaultPrevented).toBe(true);
      expect(guest.localInputs[input]).toBe(true);

      match.key("guest", name, "keyup");
      expect(guest.localInputs[input]).toBe(false);
    }

    expect(match.key("guest", "Enter", "keydown").defaultPrevented).toBe(false);
  });
});
