import { ARROWS, sweep } from "./keys.js";

export const hexInvadersScript = (side) => sweep(side, ARROWS.horizontal, [" "]);
