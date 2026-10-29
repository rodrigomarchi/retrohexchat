import { expect, it } from "vitest";

/**
 * The checks the games' AI tests share: a scripted random function, an
 * opening passed up, a one-frame press, and the bat-and-ball AIs' neutral
 * keys and aim.
 */

/**
 * A random function that gives `draws` in order, then `then` forever, and
 * can say how many draws were taken — for the duels' AI tests.
 * @param {number[]} draws
 * @param {number} then
 * @returns {(() => number) & { taken: () => number }}
 */
export function scriptedRng(draws, then) {
  let next = 0;
  const rng = () => (next < draws.length ? draws[next++] : then);
  rng.taken = () => next;
  return rng;
}

/**
 * An AI whose first opening to fire was passed up does not fire again until
 * its cooldown is out, then fires: `fire()` steps it a frame and says
 * whether it fired.
 * @param {() => boolean} fire
 * @param {number} cooldown
 */
export function expectPassedOpeningWaits(fire, cooldown) {
  const fires = Array.from({ length: cooldown + 1 }, fire);
  expect(fires.slice(0, cooldown)).toEqual(Array(cooldown).fill(false));
  expect(fires[cooldown]).toBe(true);
}

/**
 * An AI's shot (or punch) is a press of one frame: `press()` steps it a frame
 * and says whether the trigger went down — on the first, and not the next.
 * @param {() => boolean} press
 */
export function expectOneFramePress(press) {
  expect(press()).toBe(true);
  expect(press()).toBe(false);
}

/**
 * Checks a bat-and-ball AI presses nothing outside play.
 * @param {object} ai
 * @param {object} state - a state before play
 * @param {object} neutral - the game's inputs with every key up
 */
export function expectNeutralOutsidePlay(ai, state, neutral) {
  expect(ai.nextInputs({ state, player: 2 })).toEqual(neutral);
}

/**
 * Checks a bat-and-ball AI that draws one aim error per approach of the ball:
 * a change in its random draws partway through an approach leaves its aim
 * where it was, and the next approach draws again.
 * @param {object} options
 * @param {(rng: () => number) => object} options.create - the AI, drawing from `rng`
 * @param {object} options.incoming - a state with the ball heading for player two
 * @param {object} options.away - the same with the ball heading off
 * @param {number} options.every - frames between the AI's looks
 * @param {(ai: object) => number} options.aim - where the AI is aiming
 * @param {number} options.intercept - where the ball will meet the paddle
 * @param {number} options.errorPx - the AI's largest aim error
 */
export function expectOneAimPerApproach({
  create,
  incoming,
  away,
  every,
  aim,
  intercept,
  errorPx,
}) {
  let draw = 0.9;
  const ai = create(() => draw);
  const look = (state, frames) => {
    for (let frame = 0; frame < frames; frame++) ai.nextInputs({ state, player: 2 });
  };

  look(incoming, 1);
  draw = 0.1;
  for (let frame = 0; frame < every * 4; frame++) {
    look(incoming, 1);
    expect(aim(ai)).toBeCloseTo(intercept + 0.8 * errorPx);
  }

  look(away, every);
  look(incoming, every);
  expect(aim(ai)).toBeCloseTo(intercept - 0.8 * errorPx);
}

/**
 * Declares that an AI made at one difficulty takes another through its
 * setter.
 * @param {(options: { difficulty: string }) => { setDifficulty: (d: string) => void, difficulty: string }} create
 */
export function itSetsDifficulty(create) {
  it("updates difficulty through the public setter", () => {
    const ai = create({ difficulty: "easy" });

    ai.setDifficulty("hard");

    expect(ai.difficulty).toBe("hard");
  });
}

/**
 * Checks a bat-and-ball AI's `forget`: between its slow looks it keeps
 * aiming where it last looked, and once told to forget it looks again on
 * the next frame.
 * @param {object} options
 * @param {(rng: () => number) => object} options.create - an easy AI, drawing from `rng`
 * @param {object} options.before - a state with the ball heading for player two
 * @param {object} options.after - the same with the ball heading elsewhere
 * @param {(ai: object) => number} options.aim - where the AI is aiming
 */
export function expectFreshLookAfterForget({ create, before, after, aim }) {
  const ai = create(() => 0.5);
  ai.nextInputs({ state: before, player: 2 });
  const first = aim(ai);

  ai.nextInputs({ state: after, player: 2 });
  expect(aim(ai)).toBe(first);

  ai.forget();
  ai.nextInputs({ state: after, player: 2 });
  expect(aim(ai)).not.toBe(first);
}
