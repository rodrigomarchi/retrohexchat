// The games the registry serves, by engine: a game folder holds one engine and
// its modes share it, so a lifecycle test runs once per folder, never per mode.

import REGISTRY from "../../../js/lib/games/registry.json";

/** Every game folder, once, in registry order. */
export const GAME_DIRS = [...new Set(Object.values(REGISTRY).map((game) => game.dir))];

/** One game id per folder: the first registry entry that names it. */
export const ENGINE_GAME_IDS = GAME_DIRS.map((dir) =>
  Object.keys(REGISTRY).find((id) => REGISTRY[id].dir === dir),
);

/** Whether a game id is for one player: solo only, no wire, no guest. */
export const isOnePlayer = (gameId) => REGISTRY[gameId]?.soloOnly === true;

/** The folders of one-player games. */
export const ONE_PLAYER_DIRS = GAME_DIRS.filter((dir) =>
  Object.values(REGISTRY).some((game) => game.dir === dir && game.soloOnly),
);

/** One game id per two-player folder: the lifecycle a channel between two runs. */
export const TWO_PLAYER_ENGINE_GAME_IDS = ENGINE_GAME_IDS.filter((id) => !isOnePlayer(id));
