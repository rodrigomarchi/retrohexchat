/**
 * What an action key asks the server for: the E, F and touch-pad "use"
 * presses resolved against the map and the avatar's facing. The server stays
 * authoritative; this only decides what to request.
 * @module space/action_request
 */

import { interactTarget } from "./interactions.js";
import { seatTarget } from "./seating.js";

/**
 * The request one action key makes, or null when there is nothing to act on.
 * `interact` (E) uses the faced interactable; `sit` (F) sits or stands; `use`
 * — the touch pad's single button — does whichever applies, a gate before a
 * chair, and gets up when already seated.
 * @param {"interact"|"sit"|"use"} action
 * @param {import("./map.js").SpaceMap} map
 * @param {object} participant
 * @param {Set<string>} [taken] seats someone else sits on
 * @returns {{kind: "use"|"sit"|"stand", target_id: string}|null}
 */
export function actionRequest(action, map, participant, taken = new Set()) {
  const use = () => {
    const target = interactTarget(map, participant);
    return target ? { kind: "use", target_id: target.id } : null;
  };
  const seat = () => {
    const target = seatTarget(map, participant, taken);
    return target ? { kind: target.action, target_id: target.id } : null;
  };

  if (action === "interact") return use();
  if (action === "sit") return seat();
  if (action === "use") return participant.pose === "sitting" ? seat() : (use() ?? seat());
  return null;
}
