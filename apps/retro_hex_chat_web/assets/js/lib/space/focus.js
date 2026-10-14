/**
 * What the avatar would act on right now: the target the use button (and E
 * or F) would reach from where it stands, so the room can light it up before
 * anyone presses anything. It resolves exactly what `actionRequest("use")`
 * does — a gate or a piece before a seat, and getting up while seated — and
 * says where it is and what pressing would do.
 * @module space/focus
 */

import { interactTarget } from "./interactions.js";
import { seatTarget } from "./seating.js";

/**
 * @typedef {{id: string, key: "interact"|"sit", verb: string, x: number, y: number,
 *   itemId: string|null, outline: boolean}} Focus `key` is the keyboard action
 *   that reaches it (E or F); `verb` is a gate's modal action, a piece's `use`,
 *   or `sit`/`stand`; `outline` whether its art is ringed.
 */

/**
 * @param {import("./map.js").SpaceMap} map
 * @param {object|null} participant the local participant
 * @param {Set<string>} [taken] seats someone else sits on
 * @returns {Focus|null}
 */
export function focusTarget(map, participant, taken = new Set()) {
  if (!map || !participant) return null;

  if (participant.pose !== "sitting") {
    const target = interactTarget(map, participant);
    const item = target ? map.interactable?.(target.id) : null;
    if (item) {
      return {
        id: item.id,
        key: "interact",
        verb: item.use ?? item.modal?.action ?? "use",
        x: item.x,
        y: item.y,
        itemId: item.item_id ?? null,
        outline: true,
      };
    }
  }

  const seat = seatTarget(map, participant, taken);
  const spot = seat ? map.seat?.(seat.id) : null;
  if (!spot) return null;
  return {
    id: spot.id,
    key: "sit",
    verb: seat.action,
    x: spot.x,
    y: spot.y,
    itemId: spot.item_id ?? null,
    // The seat someone sits on is under them; only a free one is lit.
    outline: seat.action === "sit",
  };
}

/** @returns {string} a stable key, so a change of focus is seen once. */
export function focusKey(focus) {
  return focus ? `${focus.id}|${focus.verb}` : "";
}

/**
 * Whether a standing prop is the art of the focused target: a Construct
 * piece's every layer, or the decor standing on a fixed gate's tile.
 * @param {Focus|null} focus
 * @param {{x:number, y:number, item_id?:string}} prop
 */
export function isFocusedProp(focus, prop) {
  if (!focus?.outline) return false;
  if (focus.itemId) return prop.item_id === focus.itemId;
  return prop.x === focus.x && prop.y === focus.y;
}
