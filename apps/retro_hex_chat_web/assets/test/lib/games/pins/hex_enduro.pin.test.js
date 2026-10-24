import { pinGame } from "../../../support/games/pins.js";
import { hexEnduroScript } from "../../../support/games/scripts/hex_enduro.js";

pinGame("hex_enduro", {
  script: hexEnduroScript,
  variants: ["hex_enduro_night", "hex_enduro_sprint"],
});
