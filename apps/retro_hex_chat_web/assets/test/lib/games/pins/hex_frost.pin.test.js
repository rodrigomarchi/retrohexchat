import { pinGame } from "../../../support/games/pins.js";
import { hexFrostScript } from "../../../support/games/scripts/hex_frost.js";

pinGame("hex_frost", {
  script: hexFrostScript,
  variants: ["hex_frost_blizzard", "hex_frost_peaceful"],
});
