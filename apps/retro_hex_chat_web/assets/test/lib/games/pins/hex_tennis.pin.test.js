import { pinGame } from "../../../support/games/pins.js";
import { hexTennisScript } from "../../../support/games/scripts/hex_tennis.js";

pinGame("hex_tennis", {
  script: hexTennisScript,
  variants: ["hex_tennis_quick", "hex_tennis_sudden"],
});
