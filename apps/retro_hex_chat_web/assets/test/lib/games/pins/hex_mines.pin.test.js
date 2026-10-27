import { pinGame } from "../../../support/games/pins.js";
import { hexMinesEndScript, hexMinesScript } from "../../../support/games/scripts/hex_mines.js";

pinGame("hex_mines", {
  soloOnly: true,
  script: hexMinesScript,
  endScript: hexMinesEndScript,
  // The hour's safety clock, and the second before it starts.
  endMs: 61 * 60_000,
});
