import { calibrate } from "../../../support/games/calibration.js";
import { mulberry32 } from "../../../support/games/seeded_random.js";
import {
  createSurroundAI,
  isOpenCell,
  reachableArea,
} from "../../../../js/lib/games/surround/ai.js";
import {
  DELTA,
  OPPOSITE,
  createInitialState,
  moveAndCheck,
} from "../../../../js/lib/games/surround/physics.js";
import { DIR, PHASE, WINS_NEEDED } from "../../../../js/lib/games/surround/protocol.js";

// The average player: sees about 40 open cells ahead of each turn, so it
// avoids a pocket it is about to enter but not one that closes slowly; lets
// one move in ten go by without reacting; and now and then turns for no
// reason, as people do.
const PLAYER = { sight: 40, slipOdds: 0.1, turnOdds: 0.05 };

/** The open cells a turn leads into, as far as the player sees. */
function room(state, { x, y }, turn) {
  const next = { x: x + DELTA[turn].x, y: y + DELTA[turn].y };
  return isOpenCell(state, next) ? reachableArea(state, next, PLAYER.sight) : 0;
}

function averagePlayer(random) {
  return (state) => {
    const { dir } = state.p1;
    if (random() < PLAYER.slipOdds) return dir;
    const choices = [DIR.UP, DIR.DOWN, DIR.LEFT, DIR.RIGHT]
      .filter((turn) => turn !== OPPOSITE[dir])
      .map((turn) => ({ turn, room: room(state, state.p1, turn) }));
    const ahead = choices.find((choice) => choice.turn === dir);
    if (ahead.room >= PLAYER.sight && random() >= PLAYER.turnOdds) return dir;
    const best = Math.max(...choices.map((choice) => choice.room));
    const good = choices.filter((choice) => choice.room >= Math.min(best, PLAYER.sight));
    return good[Math.floor(random() * good.length)].turn;
  };
}

/** A whole match against the average player, first to WINS_NEEDED rounds; whether the AI won. */
function aiWinsMatch(difficulty, seed) {
  const player = averagePlayer(mulberry32(seed));
  const ai = createSurroundAI({ difficulty, rng: mulberry32(seed ^ 0x9e3779b9) });
  const score = { p1: 0, p2: 0 };

  for (let round = 0; score.p1 < WINS_NEEDED && score.p2 < WINS_NEEDED; round++) {
    let state = { ...createInitialState(round), phase: PHASE.PLAYING };
    // The engine has the AI forget at every phase change: a round starts clean.
    ai.forget();
    while (!state.p1Dead && !state.p2Dead) {
      const aiTurn = ai.nextDirection({ state, difficulty, player: 2 });
      state = moveAndCheck(state, player(state), aiTurn);
    }
    if (state.p1Dead && !state.p2Dead) score.p2++;
    if (state.p2Dead && !state.p1Dead) score.p1++;
  }
  return score.p2 >= WINS_NEEDED;
}

// A match runs a few hundred grid moves, and the hard AI counts the whole
// board behind every turn: a hundred matches a difficulty keep the run near
// a minute.
calibrate("surround", {
  trials: 100,
  play: ({ difficulty, seed }) => aiWinsMatch(difficulty, seed),
});
