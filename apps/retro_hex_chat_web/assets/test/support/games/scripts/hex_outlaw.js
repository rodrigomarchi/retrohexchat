import { ARROWS, sweep } from "./keys.js";

export const hexOutlawScript = (side) => sweep(side, ARROWS.all, [" "]);
