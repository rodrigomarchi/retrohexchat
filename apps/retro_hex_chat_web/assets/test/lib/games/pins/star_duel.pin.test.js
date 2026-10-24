import { pinGame } from "../../../support/games/pins.js";
import { starDuelScript } from "../../../support/games/scripts/star_duel.js";

pinGame("star_duel", { script: starDuelScript, variants: ["gravity_well", "debris_field"] });
