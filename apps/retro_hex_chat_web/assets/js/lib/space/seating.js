/**
 * Resolving a seat action from the avatar's position. If already sitting, the
 * action is to stand; otherwise it finds a seat on the faced tile or an
 * adjacent one to sit on. The server remains authoritative — this only decides
 * what to request.
 * @module space/seating
 */

import { frontTile, isAdjacent } from "./interactions.js";

/**
 * @param {import("./map.js").SpaceMap} map
 * @param {{x:number,y:number,dir:string,pose:string,seatId:string|null}} participant
 * @returns {{action:"sit"|"stand", id:string}|null}
 */
export function seatTarget(map, participant) {
  if (participant.pose === "sitting" && participant.seatId) {
    return { action: "stand", id: participant.seatId };
  }

  const seats = map.seats ? map.seats() : [];
  if (!seats.length) return null;

  const front = frontTile(participant);
  const faced = seats.find((seat) => seat.x === front.x && seat.y === front.y);
  const chosen = faced ?? seats.find((seat) => isAdjacent(participant, seat));
  if (!chosen) return null;

  return { action: "sit", id: chosen.id };
}
