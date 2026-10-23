import { describe, it, expect, vi, afterEach } from "vitest";
import { startMatch } from "../../helpers/game_match.js";
import { loadP2PEngineClass } from "../../../js/lib/games/engine_loader.js";
import { keymap } from "../../../js/lib/game_engine.js";

// Every engine whose keys hold an input (Light Trails steers by command).
const GAMES = [
  "hex_pong",
  "block_breakers",
  "star_duel",
  "hex_warlords",
  "pixel_tanks",
  "hex_raid",
  "hex_boxing",
  "hex_outlaw",
  "hex_invaders",
  "hex_enduro",
  "hex_tennis",
  "hex_skiing",
  "hex_frost",
  "hex_hockey",
];

function key(name) {
  return { key: name, repeat: false, target: null, preventDefault: vi.fn() };
}

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
    match = null;
    vi.unstubAllGlobals();
  });

  it("drive exactly the inputs the game sends", async () => {
    const Engine = await loadP2PEngineClass(gameId);
    expect(new Set(Object.values(Engine.KEYMAP))).toEqual(new Set(Object.keys(Engine.INPUT_BITS)));
  });

  it("hold their input while down and release it on up, keeping it from the page", async () => {
    const Engine = await loadP2PEngineClass(gameId);
    match = startMatch(Engine, gameId);
    const { guest } = match;

    for (const [name, input] of Object.entries(Engine.KEYMAP)) {
      const down = key(name);
      guest._onKeyDown(down);
      expect(guest.localInputs[input]).toBe(true);
      expect(down.preventDefault).toHaveBeenCalled();

      guest._onKeyUp(key(name));
      expect(guest.localInputs[input]).toBe(false);
    }

    const other = key("Enter");
    guest._onKeyDown(other);
    expect(other.preventDefault).not.toHaveBeenCalled();
  });
});
