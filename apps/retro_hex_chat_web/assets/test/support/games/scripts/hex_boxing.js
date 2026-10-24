import { alternate, tap } from "./keys.js";

/** Close the distance, circle, and throw punches at a steady rhythm. */
export function hexBoxingScript(side) {
  const [up, down, left, right] =
    side === "host" ? ["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight"] : ["w", "s", "a", "d"];
  const toward = side === "host" ? right : left;
  const away = side === "host" ? left : right;
  const offset = side === "host" ? 0 : 250;
  return [
    ...alternate([toward, up, toward, down, away], {
      from: 4000 + offset,
      until: 600_000,
      each: 500,
      gap: 200,
    }),
    ...tap(" ", { from: 5000 + offset, until: 600_000, every: side === "host" ? 700 : 950 }),
  ];
}
