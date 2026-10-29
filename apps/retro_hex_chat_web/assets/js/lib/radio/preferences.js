/**
 * What the browser keeps for Hex Radio between visits: the starred stations
 * and the volume. A page with storage turned off still plays; it just
 * forgets.
 *
 * @module radio/preferences
 */
import { log } from "../logger.js";

export const FAVORITES_KEY = "retrohex.radio.favorites";
export const VOLUME_KEY = "retrohex.radio.volume";

const MAX_FAVORITES = 50;
const DEFAULT_VOLUME = 80;

function read(storage, key) {
  try {
    return storage()?.getItem(key) ?? null;
  } catch (error) {
    log.debug("[HexRadio] storage could not be read", error);
    return null;
  }
}

function write(storage, key, value) {
  try {
    storage()?.setItem(key, value);
  } catch (error) {
    log.debug("[HexRadio] storage could not be written", error);
  }
}

/** The starred station ids, in the order they were starred. */
export function readFavorites(storage) {
  try {
    const ids = JSON.parse(read(storage, FAVORITES_KEY) ?? "[]");
    return Array.isArray(ids)
      ? ids.filter((id) => typeof id === "string" && id !== "").slice(0, MAX_FAVORITES)
      : [];
  } catch (error) {
    log.debug("[HexRadio] the favorites could not be read", error);
    return [];
  }
}

export function keepFavorites(storage, ids) {
  write(storage, FAVORITES_KEY, JSON.stringify((ids ?? []).slice(0, MAX_FAVORITES)));
}

/** The volume, 0–100. */
export function readVolume(storage) {
  const volume = Number.parseInt(read(storage, VOLUME_KEY) ?? "", 10);
  return Number.isFinite(volume) ? Math.max(0, Math.min(100, volume)) : DEFAULT_VOLUME;
}

export function keepVolume(storage, volume) {
  write(storage, VOLUME_KEY, String(volume));
}
