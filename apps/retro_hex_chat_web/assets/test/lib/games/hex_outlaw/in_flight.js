import { BULLET_SPEED_X } from "../../../../js/lib/games/hex_outlaw/physics.js";

/**
 * Bullet `b` in flight from (x, y): level and toward the rival unless `vx`
 * and `vy` say otherwise, not yet bounced unless `bounced` says so.
 */
export function inFlight(
  b,
  { x, y, vx = b === "b1" ? BULLET_SPEED_X : -BULLET_SPEED_X, vy = 0, bounced = false },
) {
  return {
    [`${b}x`]: x,
    [`${b}y`]: y,
    [`${b}vx`]: vx,
    [`${b}vy`]: vy,
    [`${b}active`]: true,
    [`${b}bounced`]: bounced,
  };
}
