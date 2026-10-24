import { sweep } from "./keys.js";

export const hexEnduroScript = (side) => [
  ...sweep(side, { host: ["ArrowLeft", "ArrowRight"], guest: ["a", "d"] }),
  ...sweep(side, { host: ["ArrowUp"], guest: ["w"] }),
];
