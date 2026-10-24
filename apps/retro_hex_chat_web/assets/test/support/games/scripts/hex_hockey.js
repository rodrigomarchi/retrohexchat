import { ARROWS, sweep } from "./keys.js";

export const hexHockeyScript = (side) => sweep(side, ARROWS.all, [" "]);
