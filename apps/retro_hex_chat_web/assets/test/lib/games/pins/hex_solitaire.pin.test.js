import { pinGame } from "../../../support/games/pins.js";
import {
  hexSolitaireEndScript,
  hexSolitaireScript,
} from "../../../support/games/scripts/hex_solitaire.js";

pinGame("hex_solitaire", {
  soloOnly: true,
  script: hexSolitaireScript,
  endScript: hexSolitaireEndScript,
  // The hour's safety clock, and the second before it starts.
  endMs: 61 * 60_000,
});
