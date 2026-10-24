import { pinGame } from "../../../support/games/pins.js";
import { hexSkiingScript } from "../../../support/games/scripts/hex_skiing.js";

pinGame("hex_skiing", {
  script: hexSkiingScript,
  variants: ["hex_skiing_escape", "hex_skiing_clean"],
});
