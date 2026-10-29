import { describe, it, expect } from "vitest";

/**
 * The axis a paddle game's paddles slide along, which is also the axis its
 * ball bounces off the side walls on: the key names, edge names and the
 * physics constants that measure it.
 * @typedef {object} PaddleAxis
 * @property {"X" | "Y"} pos suffix of the paddle and ball fields on this axis
 * @property {string} back key that moves a paddle toward the low end
 * @property {string} forward key that moves a paddle toward the high end
 * @property {string} backEdge name of the low edge
 * @property {string} forwardEdge name of the high edge
 * @property {string} centered how a centred paddle is described
 * @property {"CANVAS_W" | "CANVAS_H"} span constant with the canvas length on this axis
 * @property {"PADDLE_W" | "PADDLE_H"} length constant with the paddle length on this axis
 */

/** Pong: paddles move up and down, the ball bounces off the top and bottom. */
export const VERTICAL_AXIS = {
  pos: "Y",
  back: "up",
  forward: "down",
  backEdge: "top",
  forwardEdge: "bottom",
  centered: "vertically",
  span: "CANVAS_H",
  length: "PADDLE_H",
};

/** Block Breakers: paddles move left and right, the ball bounces off the sides. */
export const HORIZONTAL_AXIS = {
  pos: "X",
  back: "left",
  forward: "right",
  backEdge: "left",
  forwardEdge: "right",
  centered: "horizontally",
  span: "CANVAS_W",
  length: "PADDLE_W",
};

/**
 * A paddle game under test: its physics module, its phases and its axis.
 * @typedef {object} PaddleGame
 * @property {Record<string, any>} physics the game's physics module
 * @property {Record<string, string>} PHASE the game's phase names
 * @property {PaddleAxis} axis
 */

/**
 * The input for one paddle, with the back and forward keys held or not.
 * @param {PaddleAxis} axis
 * @param {boolean} back
 * @param {boolean} forward
 * @returns {Record<string, boolean>}
 */
export function paddleKeys(axis, back, forward) {
  return { [axis.back]: back, [axis.forward]: forward };
}

/**
 * A fresh state of `game` in the PLAYING phase with `overrides` applied.
 * @param {PaddleGame} game
 * @param {object} [overrides]
 */
export function playingState({ physics, PHASE }, overrides = {}) {
  return { ...physics.createInitialState(), phase: PHASE.PLAYING, ...overrides };
}

/**
 * Declares, inside the caller's `createInitialState` describe, the tests both
 * paddle games share: the ball at rest in the centre, both paddles centred on
 * their axis, the WAITING phase and a countdown of 3.
 * @param {PaddleGame} game
 */
export function initialStateTests({ physics, PHASE, axis }) {
  const { createInitialState, CANVAS_W, CANVAS_H } = physics;

  it("creates state with ball at center", () => {
    const state = createInitialState();
    expect(state.ballX).toBe(CANVAS_W / 2);
    expect(state.ballY).toBe(CANVAS_H / 2);
  });

  it("creates state with zero ball velocity", () => {
    const state = createInitialState();
    expect(state.ballVX).toBe(0);
    expect(state.ballVY).toBe(0);
  });

  it(`creates state with paddles centered ${axis.centered}`, () => {
    const state = createInitialState();
    const expected = (physics[axis.span] - physics[axis.length]) / 2;
    expect(state[`paddle1${axis.pos}`]).toBe(expected);
    expect(state[`paddle2${axis.pos}`]).toBe(expected);
  });

  it("starts in WAITING phase", () => {
    expect(createInitialState().phase).toBe(PHASE.WAITING);
  });

  it("starts with countdown at 3", () => {
    expect(createInitialState().countdown).toBe(3);
  });
}

/**
 * Declares the `updatePaddle` describe: a paddle moves by PADDLE_SPEED along
 * its axis, holds still with no keys or both keys, clamps to both edges, and
 * paddle 2 moves without touching paddle 1.
 * @param {PaddleGame} game
 */
export function updatePaddleTests({ physics, axis }) {
  const { createInitialState, updatePaddle, PADDLE_SPEED } = physics;
  const p1 = `paddle1${axis.pos}`;
  const p2 = `paddle2${axis.pos}`;
  const max = physics[axis.span] - physics[axis.length];

  describe("updatePaddle", () => {
    /**
     * Paddle 1 of `state` after one step with the given keys held.
     * @param {object} state
     * @param {boolean} back
     * @param {boolean} forward
     */
    const moved = (state, back, forward) =>
      updatePaddle(state, 1, paddleKeys(axis, back, forward))[p1];

    it(`moves paddle ${axis.back}`, () => {
      const state = createInitialState();
      expect(moved(state, true, false)).toBe(state[p1] - PADDLE_SPEED);
    });

    it(`moves paddle ${axis.forward}`, () => {
      const state = createInitialState();
      expect(moved(state, false, true)).toBe(state[p1] + PADDLE_SPEED);
    });

    it("does not move paddle with no input", () => {
      const state = createInitialState();
      expect(moved(state, false, false)).toBe(state[p1]);
    });

    it(`cancels out with both ${axis.back} and ${axis.forward}`, () => {
      const state = createInitialState();
      expect(moved(state, true, true)).toBe(state[p1]);
    });

    it(`clamps paddle to ${axis.backEdge} edge`, () => {
      const state = { ...createInitialState(), [p1]: 2 };
      expect(moved(state, true, false)).toBe(0);
    });

    it(`clamps paddle to ${axis.forwardEdge} edge`, () => {
      const state = { ...createInitialState(), [p1]: max - 2 };
      expect(moved(state, false, true)).toBe(max);
    });

    it("updates paddle 2 independently", () => {
      const state = createInitialState();
      const result = updatePaddle(state, 2, paddleKeys(axis, true, false));
      expect(result[p2]).toBe(state[p2] - PADDLE_SPEED);
      expect(result[p1]).toBe(state[p1]);
    });
  });
}

/**
 * Declares the `updateBall` describe: the ball moves by its velocity only
 * while playing.
 * @param {PaddleGame} game
 */
export function updateBallTests(game) {
  const { createInitialState, updateBall } = game.physics;

  describe("updateBall", () => {
    it("moves ball by velocity when playing", () => {
      const state = playingState(game, { ballVX: 3, ballVY: -2 });
      const result = updateBall(state);
      expect(result.ballX).toBe(state.ballX + 3);
      expect(result.ballY).toBe(state.ballY - 2);
    });

    it("does not move ball when not playing", () => {
      const state = { ...createInitialState(), ballVX: 3, ballVY: 2 };
      const result = updateBall(state);
      expect(result.ballX).toBe(state.ballX);
      expect(result.ballY).toBe(state.ballY);
    });
  });
}

/**
 * Declares the `checkWallBounce` describe: the ball turns back off both side
 * walls of the game's axis and flags the bounce, keeps its velocity in the
 * middle, and is left alone while not playing.
 * @param {PaddleGame} game
 */
export function wallBounceTests(game) {
  const { createInitialState, checkWallBounce } = game.physics;
  const { axis } = game;
  const pos = `ball${axis.pos}`;
  const vel = `ballV${axis.pos}`;
  const span = game.physics[axis.span];

  describe("checkWallBounce", () => {
    /**
     * The bounce check on a playing ball at `at` moving at `speed`.
     * @param {number} at
     * @param {number} speed
     */
    const bounce = (at, speed) => checkWallBounce(playingState(game, { [pos]: at, [vel]: speed }));

    it(`bounces ball off ${axis.backEdge} wall`, () => {
      const result = bounce(2, -5);
      expect(result[vel]).toBeGreaterThan(0);
      expect(result.wallBounced).toBe(true);
    });

    it(`bounces ball off ${axis.forwardEdge} wall`, () => {
      const result = bounce(span - 2, 5);
      expect(result[vel]).toBeLessThan(0);
      expect(result.wallBounced).toBe(true);
    });

    it("does not bounce when ball is in middle", () => {
      const result = bounce(span / 2, 3);
      expect(result[vel]).toBe(3);
      expect(result.wallBounced).toBeFalsy();
    });

    it("does nothing when not playing", () => {
      const result = checkWallBounce({ ...createInitialState(), [pos]: 0, [vel]: -5 });
      expect(result[vel]).toBe(-5);
    });
  });
}

/**
 * Declares, inside the caller's `serveBall` describe, the tests both games
 * share: the serve starts from the centre, in PLAYING, at the initial speed.
 * @param {PaddleGame} game
 * @param {object} base fields every served state starts from
 */
export function serveBallTests({ physics, PHASE }, base) {
  const { createInitialState, serveBall, CANVAS_W, CANVAS_H, INITIAL_BALL_SPEED } = physics;

  /**
   * The state served from a fresh one with `base` and `overrides` applied.
   * @param {object} [overrides]
   */
  const served = (overrides = {}) => serveBall({ ...createInitialState(), ...base, ...overrides });

  it("places ball at center", () => {
    const result = served();
    expect(result.ballX).toBe(CANVAS_W / 2);
    expect(result.ballY).toBe(CANVAS_H / 2);
  });

  it("sets phase to PLAYING", () => {
    expect(served({ phase: PHASE.SERVING }).phase).toBe(PHASE.PLAYING);
  });

  it("resets ball speed to initial", () => {
    expect(served({ ballSpeed: 10 }).ballSpeed).toBe(INITIAL_BALL_SPEED);
  });

  it("has non-zero velocity", () => {
    const result = served();
    const speed = Math.sqrt(result.ballVX ** 2 + result.ballVY ** 2);
    expect(speed).toBeCloseTo(INITIAL_BALL_SPEED, 1);
  });
}

/**
 * Declares, inside the caller's describe for a particle burst, the tests both
 * games share: `count` particles, all at the given point, each with a
 * velocity and full life.
 * @param {(x: number, y: number) => object[]} createParticles
 * @param {number} count
 */
export function particleBurstTests(createParticles, count) {
  it(`creates ${count} particles`, () => {
    expect(createParticles(320, 240)).toHaveLength(count);
  });

  it("particles start at given position", () => {
    for (const p of createParticles(100, 200)) {
      expect(p.x).toBe(100);
      expect(p.y).toBe(200);
    }
  });

  it("particles have velocity and life", () => {
    for (const p of createParticles(0, 0)) {
      expect(typeof p.vx).toBe("number");
      expect(typeof p.vy).toBe("number");
      expect(p.life).toBe(1.0);
    }
  });
}

/**
 * Declares the `updateParticles` describe: particles move by their velocity,
 * lose life and speed, and a particle with `dyingLife` left is removed.
 * @param {PaddleGame} game
 * @param {number} dyingLife a life that runs out within one step
 */
export function updateParticlesTests({ physics }, dyingLife) {
  const { updateParticles } = physics;

  describe("updateParticles", () => {
    /**
     * One particle after one step.
     * @param {object} particle
     */
    const step = (particle) =>
      updateParticles([{ x: 0, y: 0, vx: 0, vy: 0, life: 1.0, ...particle }]);

    it("moves particles by velocity", () => {
      const [p] = step({ x: 10, y: 20, vx: 2, vy: -1 });
      expect(p.x).toBeCloseTo(12);
      expect(p.y).toBeCloseTo(19);
    });

    it("decays life", () => {
      expect(step({})[0].life).toBeLessThan(1.0);
    });

    it("removes dead particles", () => {
      expect(step({ life: dyingLife })).toHaveLength(0);
    });

    it("applies drag to velocity", () => {
      const [p] = step({ vx: 10, vy: 10 });
      expect(Math.abs(p.vx)).toBeLessThan(10);
      expect(Math.abs(p.vy)).toBeLessThan(10);
    });
  });
}

/**
 * Declares the `stepTick` test where player 1 holds back, player 2 holds
 * forward and the ball moves by `(ballVX, ballVY)` with nothing to report.
 * @param {PaddleGame} game
 * @param {{ ballVX: number, ballVY: number, events: object }} tick the ball's
 *   velocity and the quiet events the game reports
 */
export function stepTickMovesTest(game, { ballVX, ballVY, events: quiet }) {
  const { axis } = game;
  const { stepTick, PADDLE_SPEED } = game.physics;

  it("moves both paddles by their keys and the ball by its velocity", () => {
    const s = playingState(game, { ballVX, ballVY });
    const { state, events } = stepTick(
      s,
      paddleKeys(axis, true, false),
      paddleKeys(axis, false, true),
    );

    expect(state[`paddle1${axis.pos}`]).toBe(s[`paddle1${axis.pos}`] - PADDLE_SPEED);
    expect(state[`paddle2${axis.pos}`]).toBe(s[`paddle2${axis.pos}`] + PADDLE_SPEED);
    expect(state.ballX).toBe(s.ballX + ballVX);
    expect(state.ballY).toBe(s.ballY + ballVY);
    expect(events).toEqual(quiet);
  });
}

/**
 * A trigger pressed and then held, through a duel's `stepTick`: the frame of
 * the press, and the next one from `rearm(first.state)` — that frame's state
 * with the shot or punch spent, so only the held key decides whether
 * another goes.
 * @param {(state: object, pressed: object) => { state: object, pressed: object }} step - one frame
 * @param {object} start
 * @param {object} released - the press memory with no key down
 * @param {(state: object) => object} rearm
 * @returns {{ first: object, held: object }}
 */
export function pressAndHold(step, start, released, rearm) {
  const first = step(start, released);
  const held = step(rearm(first.state), first.pressed);
  return { first, held };
}

/**
 * A player's held inputs with every one of `names` let go.
 * @param {...string} names
 * @returns {Record<string, false>}
 */
export function released(...names) {
  return Object.fromEntries(names.map((name) => [name, false]));
}
