import { ARROWS, sweep } from "./keys.js";

export const surroundScript = (side) => sweep(side, ARROWS.all);
