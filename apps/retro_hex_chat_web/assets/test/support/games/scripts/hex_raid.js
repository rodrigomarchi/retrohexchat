import { sweep } from "./keys.js";

export const hexRaidScript = (side) =>
  sweep(
    side,
    { host: ["ArrowLeft", "ArrowUp", "ArrowRight", "ArrowDown"], guest: ["a", "w", "d", "s"] },
    [" "],
  );
