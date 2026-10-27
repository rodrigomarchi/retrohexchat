import { pinGame } from "../../../support/games/pins.js";
import {
  hexFreeCellEndScript,
  hexFreeCellScript,
} from "../../../support/games/scripts/hex_freecell.js";

pinGame("hex_freecell", {
  soloOnly: true,
  script: hexFreeCellScript,
  endScript: hexFreeCellEndScript,
  // The hour's safety clock, and the second before it starts.
  endMs: 61 * 60_000,
});
