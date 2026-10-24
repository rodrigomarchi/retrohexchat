import { pinGame } from "../../../support/games/pins.js";
import { hexOutlawScript } from "../../../support/games/scripts/hex_outlaw.js";

pinGame("hex_outlaw", {
  script: hexOutlawScript,
  variants: ["hex_outlaw_ricochet", "hex_outlaw_stagecoach", "hex_outlaw_nml"],
});
