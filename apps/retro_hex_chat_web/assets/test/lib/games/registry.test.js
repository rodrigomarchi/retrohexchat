import { readdirSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, it, expect } from "vitest";
import REGISTRY from "../../../js/lib/games/registry.json";
import {
  createGameEngine,
  loadP2PEngineClass,
  supportsSolo,
} from "../../../js/lib/games/engine_loader.js";
import { createLocalTransport } from "../../../js/lib/games/transport.js";

const GAMES_DIR = join(dirname(fileURLToPath(import.meta.url)), "../../../js/lib/games");
const ENTRIES = Object.entries(REGISTRY);

function canvas() {
  const c = document.createElement("canvas");
  c.width = 640;
  c.height = 480;
  c.getContext = () => ({});
  return c;
}

describe("the games registry", () => {
  it("names every game folder, and only game folders", () => {
    const folders = readdirSync(GAMES_DIR, { withFileTypes: true })
      .filter((d) => d.isDirectory() && existsSync(join(GAMES_DIR, d.name, "index.js")))
      .map((d) => d.name)
      .sort();
    expect([...new Set(ENTRIES.map(([, game]) => game.dir))].sort()).toEqual(folders);
  });

  it.each([...new Set(ENTRIES.map(([, game]) => game.dir))])(
    "has characterization pins for %s",
    (dir) => {
      // A game without pins has nothing to prove a refactor of it changed nothing.
      const pins = join(GAMES_DIR, "../../../test/lib/games/pins", `${dir}.pin.test.js`);
      expect(existsSync(pins), `${dir}.pin.test.js`).toBe(true);
    },
  );

  it.each(ENTRIES)("loads %s from its folder's definition", async (id, { dir }) => {
    const EngineClass = await loadP2PEngineClass(id);
    expect(EngineClass).toBe((await import(`../../../js/lib/games/${dir}/index.js`)).default);
  });

  it.each(ENTRIES)("offers %s solo as the registry says", (id, { solo }) => {
    expect(supportsSolo(id)).toBe(solo);
  });

  it.each(ENTRIES.filter(([, game]) => game.soloOnly))(
    "plays %s, a one-player game, solo and without an opponent",
    async (id) => {
      expect(supportsSolo(id)).toBe(true);
      const engine = await createGameEngine({
        canvas: canvas(),
        gameId: id,
        mode: "solo",
        transport: createLocalTransport(),
        engineOptions: { seed: 7 },
      });
      expect(engine.opponentController ?? null).toBeNull();
      engine.stop();
    },
  );

  it.each(ENTRIES.filter(([, game]) => game.solo && !game.soloOnly))(
    "gives a solo %s an opponent of its own",
    async (id) => {
      const engine = await createGameEngine({
        canvas: canvas(),
        gameId: id,
        mode: "solo",
        transport: createLocalTransport(),
        engineOptions: { seed: 7 },
      });
      expect(engine.opponentController).toBeTruthy();
      engine.stop();
    },
  );
});
