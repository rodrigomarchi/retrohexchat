/** Every Block Breakers sound, once, and a block hit on each row. */
export const SOUND_SCRIPT = [
  ["playPaddleHit"],
  { wait: 200 },
  ["playWallBounce"],
  { wait: 200 },
  ...[0, 1, 2, 3, 4].flatMap((row) => [["playBlockHit", row], { wait: 100 }]),
  ["playLifeLost"],
  { wait: 500 },
  ["playCountdown"],
  { wait: 200 },
  ["playWin"],
  { wait: 800 },
  ["playLose"],
];
