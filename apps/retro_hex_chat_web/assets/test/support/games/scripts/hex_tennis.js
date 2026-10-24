import { ARROWS, sweep } from "./keys.js";

export const hexTennisScript = (side) => sweep(side, ARROWS.all, [" "]);
