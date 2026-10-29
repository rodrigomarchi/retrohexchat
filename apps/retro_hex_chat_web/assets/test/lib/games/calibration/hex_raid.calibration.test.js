import { calibrate } from "../../../support/games/calibration.js";
import { playRaidMatch } from "../../../support/games/calibration_players/hex_raid.js";

// A trial is one River Duel match against the average player; the AI wins
// it by ending with the higher score. A match lasts about half a minute and
// its result swings on a bridge or two, so it takes many of them to settle.
calibrate("hex_raid", {
  trials: 600,
  play: ({ difficulty, seed }) => playRaidMatch({ difficulty, seed }).winner === 2,
});
