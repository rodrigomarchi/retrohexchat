import { ARROWS, sweep } from "./keys.js";

export const breakoutScript = (side) => sweep(side, ARROWS.horizontal);
