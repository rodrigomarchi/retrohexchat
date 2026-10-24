import { pinGame } from "../../../support/games/pins.js";
import { hexRaidScript } from "../../../support/games/scripts/hex_raid.js";

pinGame("hex_raid", { script: hexRaidScript, variants: ["hex_raid_pacifist", "hex_raid_blitz"] });
