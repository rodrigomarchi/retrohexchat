import { describe, expect, it } from "vitest";
import { mulberry32 } from "../../../support/games/seeded_random.js";
import { createTennisAI } from "../../../../js/lib/games/hex_tennis/ai.js";
import {
  createInitialState,
  resetForNextPoint,
  shouldChangeover,
  stepRally,
  stepServing,
} from "../../../../js/lib/games/hex_tennis/physics.js";
import { GAME_MODE, PHASE, SNAPSHOT } from "../../../../js/lib/games/hex_tennis/protocol.js";

const FPS = 60;
const PAUSE_FRAMES = 120;
const LIMIT_FRAMES = 20 * 60 * FPS;
const MATCHES_TIMEOUT_MS = 60_000;

/** The court as a guest's browser holds it: the host's snapshot, ball rebuilt. */
function guestView(previous, state) {
  const wire = { ...state, ballX: state.ball.x, ballY: state.ball.y };
  Object.assign(wire, { ballVX: state.ball.vx, ballVY: state.ball.vy });
  wire.ballHeight = state.ball.height;
  const decoded = SNAPSHOT.decode(SNAPSHOT.encode(wire));
  return {
    ...previous,
    ...decoded,
    ball: {
      ...previous.ball,
      x: decoded.ballX,
      y: decoded.ballY,
      vx: decoded.ballVX,
      vy: decoded.ballVY,
      height: decoded.ballHeight,
    },
  };
}

/**
 * A whole match between two hard players, a step at a time as the host plays
 * it, pauses after points and changeovers included: how many minutes it took,
 * whether it ended, and how many of player two's serves to return went
 * unreturned. With `guest`, player two plays the court a guest's browser sees.
 */
function hardMatch(mode, seed, { guest = false } = {}) {
  const ais = {
    1: createTennisAI({ difficulty: "hard", rng: mulberry32(seed * 13 + 1) }),
    2: createTennisAI({ difficulty: "hard", rng: mulberry32(seed * 7 + 5) }),
  };
  const random = mulberry32(seed * 31 + 3);
  let state = { ...createInitialState(mode), phase: PHASE.SERVING };
  let seen = createInitialState(mode);
  let pressed = { local: false, remote: false };
  let pause = 0;
  let aces = 0;
  let frame = 0;

  for (; frame < LIMIT_FRAMES && state.phase !== PHASE.GAME_OVER; frame++) {
    seen = guestView(seen, state);
    const one = ais[1].nextInputs({ state, player: 1 });
    const two = ais[2].nextInputs({ state: guest ? seen : state, player: 2 });
    if (state.phase === PHASE.SERVING) {
      ({ state, pressed } = stepServing(state, one, two, pressed, random));
    } else if (state.phase === PHASE.RALLY) {
      const rally = stepRally(state, one, two);
      state = rally.state;
      if (rally.point) {
        // An ace: a serve of player one's player two never touched.
        if (state.pointWinner === 1 && state.server === 1 && state.rallyCount <= 1) aces++;
        pause = PAUSE_FRAMES;
      }
    } else if (--pause <= 0) {
      if (state.phase === PHASE.POINT && shouldChangeover(state)) {
        state = { ...state, phase: PHASE.CHANGEOVER };
        pause = PAUSE_FRAMES;
      } else {
        state = resetForNextPoint(state);
      }
    }
  }
  return { minutes: frame / (60 * FPS), ended: state.phase === PHASE.GAME_OVER, aces };
}

describe.each([
  ["Hex Tennis", GAME_MODE.CLASSIC, 12],
  ["Quick Match", GAME_MODE.QUICK, 5],
  ["Sudden Death", GAME_MODE.SUDDEN_DEATH, 2],
])("%s, two hard players", (_name, mode, maxMinutes) => {
  it.each([
    ["on the host", false],
    ["with player two on a guest's browser", true],
  ])(
    "play it to the end %s, returning serve",
    (_where, guest) => {
      const matches = [1, 2, 3].map((seed) => hardMatch(mode, seed, { guest }));

      expect(matches.every((match) => match.ended)).toBe(true);
      const minutes = matches.reduce((sum, match) => sum + match.minutes, 0) / matches.length;
      expect(minutes).toBeLessThan(maxMinutes);
      // Hard players return serve: no more than a stray ace a match.
      expect(matches.every((match) => match.aces <= 2)).toBe(true);
    },
    MATCHES_TIMEOUT_MS,
  );
});
