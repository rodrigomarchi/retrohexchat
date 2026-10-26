/**
 * Every Hex Jungle sound, once; the log buzz started (twice: the second does
 * nothing), stopped, and started again for dispose to stop.
 */
export const SOUND_SCRIPT = [
  ["playJump"],
  { wait: 200 },
  ["playVine"],
  { wait: 2000 },
  ["playTreasure"],
  { wait: 400 },
  ["playHole"],
  { wait: 500 },
  ["playDeath"],
  { wait: 2500 },
  ["playWall"],
  { wait: 200 },
  ["playFinale"],
  { wait: 600 },
  ["startLogBuzz"],
  ["startLogBuzz"],
  { wait: 300 },
  ["stopLogBuzz"],
  { wait: 100 },
  ["startLogBuzz"],
];
