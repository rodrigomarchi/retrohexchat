import { pinGame } from "../../../support/games/pins.js";
import { hexInvadersScript } from "../../../support/games/scripts/hex_invaders.js";

pinGame("hex_invaders", {
  script: hexInvadersScript,
  variants: ["hex_invaders_coop", "hex_invaders_blitz"],
});
