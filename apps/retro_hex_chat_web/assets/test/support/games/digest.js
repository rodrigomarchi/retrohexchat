import { createHash } from "node:crypto";

/**
 * A short, stable fingerprint of any JSON-serialisable value: two logs with
 * the same digest are the same log.
 * @param {unknown} value
 * @returns {string} 16 hex characters
 */
export function digest(value) {
  return createHash("sha256").update(JSON.stringify(value)).digest("hex").slice(0, 16);
}
