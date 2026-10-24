import { pinGame } from "../../../support/games/pins.js";
import { hexHockeyScript } from "../../../support/games/scripts/hex_hockey.js";

pinGame("hex_hockey", {
  script: hexHockeyScript,
  variants: ["hex_hockey_blitz", "hex_hockey_showdown"],
});
