import { pinGame } from "../../../support/games/pins.js";
import { hexSpiderEndScript, hexSpiderScript } from "../../../support/games/scripts/hex_spider.js";

pinGame("hex_spider", {
  soloOnly: true,
  script: hexSpiderScript,
  endScript: hexSpiderEndScript,
  // The hour's safety clock, and the second before it starts.
  endMs: 61 * 60_000,
});
