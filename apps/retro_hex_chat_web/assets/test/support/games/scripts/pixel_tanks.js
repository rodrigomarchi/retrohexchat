import { sweep } from "./keys.js";

export const pixelTanksScript = (side) =>
  sweep(
    side,
    { host: ["ArrowUp", "ArrowLeft", "ArrowUp", "ArrowRight"], guest: ["w", "a", "w", "d"] },
    [" "],
  );
