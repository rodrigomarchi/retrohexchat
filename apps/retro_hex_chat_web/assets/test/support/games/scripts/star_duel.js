import { sweep } from "./keys.js";

export const starDuelScript = (side) =>
  sweep(
    side,
    { host: ["ArrowUp", "ArrowLeft", "ArrowUp", "ArrowRight"], guest: ["w", "a", "w", "d"] },
    [" "],
  );
