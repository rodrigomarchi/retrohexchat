import { alternate } from "./keys.js";

/** Hop between the floe rows and walk along them, at different rhythms per side. */
export function hexFrostScript(side) {
  const [up, down, left, right] =
    side === "host" ? ["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight"] : ["w", "s", "a", "d"];
  const offset = side === "host" ? 0 : 350;
  return [
    ...alternate([down, down, up], { from: 4000 + offset, until: 600_000, each: 120, gap: 900 }),
    ...alternate([left, right], { from: 4500 + offset, until: 600_000, each: 600, gap: 700 }),
  ];
}
