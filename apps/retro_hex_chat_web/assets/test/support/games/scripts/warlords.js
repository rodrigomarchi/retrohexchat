import { ARROWS, sweep } from "./keys.js";

export const warlordsScript = (side) => sweep(side, ARROWS.vertical, [" "]);
