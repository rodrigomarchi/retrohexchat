import { pinGame } from "../../../support/games/pins.js";
import { hexBlocksEndScript, hexBlocksScript } from "../../../support/games/scripts/hex_blocks.js";

pinGame("hex_blocks", {
  soloOnly: true,
  script: hexBlocksScript,
  endScript: hexBlocksEndScript,
  // Left alone, the pieces pile up in the middle and top out within minutes.
  endMs: 600_000,
});
