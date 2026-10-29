/**
 * Time as the Hex devices' displays show it.
 *
 * @module hex_device/clock
 */

/** Elapsed time: `m:ss`, or `h:mm:ss` past an hour. */
export function formatElapsed(ms) {
  const total = Math.max(0, Math.floor(ms / 1000));
  const hours = Math.floor(total / 3600);
  const minutes = Math.floor((total % 3600) / 60);
  const seconds = String(total % 60).padStart(2, "0");
  return hours > 0
    ? `${hours}:${String(minutes).padStart(2, "0")}:${seconds}`
    : `${minutes}:${seconds}`;
}

/** A length the display does not know yet — a stream, or a file still loading — as `--:--`. */
export function formatLength(seconds) {
  return Number.isFinite(seconds) && seconds > 0 ? formatElapsed(seconds * 1000) : "--:--";
}
