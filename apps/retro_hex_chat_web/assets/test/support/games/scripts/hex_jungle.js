import { hold, tap } from "./keys.js";

/**
 * Head left through the jungle, jumping at a steady rhythm, then turn back:
 * logs, pits and whatever else the first screens hold, and the lives lost
 * to them.
 */
export const hexJungleScript = () => [
  ...hold("ArrowLeft", 1000, 40_000),
  ...tap(" ", { from: 1500, until: 40_000, every: 700 }),
  ...hold("ArrowRight", 41_000, 59_000),
  ...tap(" ", { from: 41_300, until: 59_000, every: 900 }),
];

/**
 * To the end: run right into the first screen's hole and on to the tunnel's
 * wall, where the twenty minutes run out.
 */
export const hexJungleEndScript = () => hold("ArrowRight", 1000, 30_000);
