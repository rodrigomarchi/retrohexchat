import { describe, expect, it } from "vitest";
import { mulberry32 } from "../../../support/games/seeded_random.js";
import { createHockeyAI } from "../../../../js/lib/games/hex_hockey/ai.js";
import {
  createInitialState,
  goalEndsMatch,
  packState,
  resetForFaceoff,
  stepTick,
  unpackState,
} from "../../../../js/lib/games/hex_hockey/physics.js";
import { GAME_MODE, PHASE, SNAPSHOT } from "../../../../js/lib/games/hex_hockey/protocol.js";

const FPS = 60;
const LIMIT_FRAMES = 20 * 60 * FPS;
const COUNTDOWN_FRAMES = 180;
const FACEOFF_GO_FRAMES = 30;
const MATCHES_TIMEOUT_MS = 120_000;

/**
 * A whole match between two hard skaters, the pauses between goals and
 * periods included, as the host plays it: how many minutes it took, whether
 * it ended, and how many goals. Each side's action is acted on once per press.
 * With `guest`, skater two plays the rink a guest's browser sees.
 */
function hardMatch(mode, seed, { guest = false } = {}) {
  const ais = {
    1: createHockeyAI({ difficulty: "hard", rng: mulberry32(seed * 101 + 17) }),
    2: createHockeyAI({ difficulty: "hard", rng: mulberry32(seed * 53 + 29) }),
  };
  const random = mulberry32(seed * 977 + 11);
  const state = { ...createInitialState(mode), phase: PHASE.PLAYING };
  let handled = { local: false, remote: false };
  let held = { local: false, remote: false };
  let wait = 0;
  let goals = 0;
  let frame = 0;
  const restart = () => {
    state.phase = PHASE.COUNTDOWN;
    wait = COUNTDOWN_FRAMES;
  };

  for (; frame < LIMIT_FRAMES && state.phase !== PHASE.FINISHED; frame++) {
    state.eventFlags = 0;
    if (state.phase === PHASE.COUNTDOWN) {
      if (--wait <= 0) {
        state.phase = PHASE.FACE_OFF;
        wait = FACEOFF_GO_FRAMES;
      }
      continue;
    }
    if (state.phase === PHASE.FACE_OFF) {
      if (--wait <= 0) {
        const regular = mode === GAME_MODE.BLITZ ? 1 : 3;
        const sudden = mode !== GAME_MODE.SHOWDOWN && state.period > regular;
        state.phase = sudden ? PHASE.SUDDEN_DEATH : PHASE.PLAYING;
      }
      continue;
    }
    if (state.phase === PHASE.GOAL_CELEBRATION) {
      if (--state.celebrationFrames > 0) continue;
      if (goalEndsMatch(state)) {
        state.phase = PHASE.FINISHED;
        continue;
      }
      restart();
      resetForFaceoff(state, null);
      continue;
    }
    if (state.phase === PHASE.PERIOD_BREAK) {
      if (--state.periodBreakFrames <= 0) {
        restart();
        resetForFaceoff(state, null);
      }
      continue;
    }

    const seen = guest ? unpackState(SNAPSHOT.decode(SNAPSHOT.encode(packState(state)))) : state;
    const one = ais[1].nextInputs({ state, player: 1 });
    const two = ais[2].nextInputs({ state: seen, player: 2 });
    handled = {
      local: handled.local && !(one.action && !held.local),
      remote: handled.remote && !(two.action && !held.remote),
    };
    held = { local: one.action, remote: two.action };
    const tick = stepTick(state, one, two, handled, random);
    handled = tick.handled;
    if (tick.scored) goals++;
    if (tick.stuck || (tick.periodEnded && state.phase === PHASE.FACE_OFF)) restart();
  }
  return { minutes: frame / (60 * FPS), ended: state.phase === PHASE.FINISHED, goals };
}

describe.each([
  ["Hex Hockey", GAME_MODE.CLASSIC, 14],
  ["Blitz", GAME_MODE.BLITZ, 7],
  ["Showdown", GAME_MODE.SHOWDOWN, 12],
])("%s, two hard skaters", (_name, mode, maxMinutes) => {
  it.each([
    ["on the host", false],
    ["with skater two on a guest's browser", true],
  ])(
    "play it to the end %s, the goalies keeping the score a hockey score",
    (_where, guest) => {
      const matches = [1, 2, 3].map((seed) => hardMatch(mode, seed, { guest }));

      expect(matches.every((match) => match.ended)).toBe(true);
      expect(matches.every((match) => match.minutes < maxMinutes)).toBe(true);
      // A few goals a period, not one every few seconds.
      expect(matches.every((match) => match.goals <= 16)).toBe(true);
    },
    MATCHES_TIMEOUT_MS,
  );
});
