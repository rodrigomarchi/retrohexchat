import { pinGame } from "../../../support/games/pins.js";
import { hexJungleEndScript, hexJungleScript } from "../../../support/games/scripts/hex_jungle.js";

pinGame("hex_jungle", {
  soloOnly: true,
  script: hexJungleScript,
  endScript: hexJungleEndScript,
  // Twenty minutes on the clock, and a second before it starts.
  endMs: 21 * 60_000,
});
