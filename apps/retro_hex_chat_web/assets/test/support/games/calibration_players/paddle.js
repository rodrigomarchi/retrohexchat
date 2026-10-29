/**
 * A scripted paddle player for the AI calibration of the bat-and-ball games
 * (Hex Pong, Block Breakers, Hex Warlords): an average person at a paddle.
 * Once per ball coming their way they either miss it — more often the faster
 * it comes — or meet it at a spot along the paddle, which sets the angle of
 * their return. A ball they miss finds the paddle at the far end of the table.
 */

// A ball they could reach is missed 4% of the time at the game's slowest
// speed and 34% at its fastest.
const MISS_SLOW = 0.04;
const MISS_FAST = 0.34;
// Where they meet the ball, as a share of half the paddle: anywhere but the very tips.
const SPREAD = 0.85;

/**
 * The chance the average player misses a ball they could reach.
 * @param {number} speed
 * @param {number} slowest - the game's serve speed
 * @param {number} fastest - the game's top speed
 * @returns {number}
 */
export function missChance(speed, slowest, fastest) {
  const pace = Math.min(1, Math.max(0, (speed - slowest) / (fastest - slowest)));
  return MISS_SLOW + (MISS_FAST - MISS_SLOW) * pace;
}

/**
 * @param {() => number} random - draws in [0, 1)
 * @param {object} paddle - how the game's state reads for this paddle
 * @param {(state: object) => boolean} paddle.coming - the ball heads for it
 * @param {(state: object) => number} paddle.speed - the ball's speed
 * @param {number} paddle.slowest
 * @param {number} paddle.fastest
 * @param {(state: object) => number} paddle.ball - the ball's position along the paddle's axis
 * @param {(state: object) => number|null} paddle.arrival - where on that axis it will reach the paddle
 * @param {(state: object) => number} paddle.at - the paddle's near edge on that axis now
 * @param {number} paddle.length - the paddle's length
 * @param {number} paddle.span - the table's length on that axis
 * @returns {(state: object) => number} the paddle's near edge for this tick
 */
export function averagePaddlePlayer(random, paddle) {
  let meet = null;
  return (state) => {
    if (!paddle.coming(state)) {
      meet = null;
      return paddle.at(state);
    }
    if (meet === null) {
      const miss = random() < missChance(paddle.speed(state), paddle.slowest, paddle.fastest);
      meet = miss ? "miss" : (random() * 2 - 1) * SPREAD;
    }
    if (meet === "miss") {
      const arrival = paddle.arrival(state) ?? paddle.ball(state);
      return arrival < paddle.span / 2 ? paddle.span - paddle.length : 0;
    }
    return paddle.ball(state) - paddle.length / 2 - (meet * paddle.length) / 2;
  };
}
