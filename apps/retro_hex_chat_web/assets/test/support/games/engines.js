// The games the registry serves, by engine: a game folder holds one engine and
// its modes share it, so a lifecycle test runs once per folder, never per mode.

import REGISTRY from "../../../js/lib/games/registry.json";

/** Every game folder, once, in registry order. */
export const GAME_DIRS = [...new Set(Object.values(REGISTRY).map((game) => game.dir))];

/** One game id per folder: the first registry entry that names it. */
export const ENGINE_GAME_IDS = GAME_DIRS.map((dir) =>
  Object.keys(REGISTRY).find((id) => REGISTRY[id].dir === dir),
);
