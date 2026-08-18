/**
 * Reading and normalising conference payload and dataset values — pure.
 *
 * The hook receives layout and track payloads in mixed snake_case/camelCase and
 * reads the same shapes back out of `data-*`; these are the small coercions that
 * turn either form into a normalised value, kept in one place so the tile and
 * layout slices can share them.
 *
 * @module group_call/payload
 */

export const LAYOUT_MODES = new Set(["auto", "grid", "focus", "sidebar", "speaker"]);
export const SELF_VIEW_MODES = new Set(["tile", "pip", "hidden"]);

/** True when `object` has `key` as an own property, null-safe. */
export function hasOwn(object, key) {
  return Object.prototype.hasOwnProperty.call(object || {}, key);
}

/** A trimmed non-empty string, or null. */
export function stringOrNull(value) {
  if (value === undefined || value === null || value === "") return null;
  return String(value);
}

/** A list of ids from an array or a comma-separated string, blanks dropped. */
export function idsFromValue(value) {
  if (Array.isArray(value)) {
    return value.map((id) => stringOrNull(id)).filter(Boolean);
  }

  if (typeof value === "string") {
    return value
      .split(",")
      .map((id) => stringOrNull(id.trim()))
      .filter(Boolean);
  }

  return [];
}

/** The first of `keys` present as an own property of `payload`, else undefined. */
export function payloadValue(payload, ...keys) {
  for (const key of keys) {
    if (hasOwn(payload, key)) return payload[key];
  }

  return undefined;
}

/** A layout mode, defaulting to "auto" for anything unrecognised. */
export function normalizeLayoutMode(mode) {
  return LAYOUT_MODES.has(mode) ? mode : "auto";
}

/** A self-view mode, defaulting to "tile" for anything unrecognised. */
export function normalizeSelfView(mode) {
  return SELF_VIEW_MODES.has(mode) ? mode : "tile";
}

/** The tile-density bucket for a visible tile count. */
export function tileDensity(count) {
  if (count >= 10) return "compact";
  if (count >= 5) return "dense";
  return "normal";
}
