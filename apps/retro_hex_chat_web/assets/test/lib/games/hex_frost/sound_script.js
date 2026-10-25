/**
 * Every Hex Frost sound, once; the ambient wind started (twice: the second
 * does nothing), stopped, and started again for dispose to stop.
 */
const ONE_SHOTS = [
  "playJump",
  "playLand",
  "playBlockClaim",
  "playBlockSteal",
  "playBlockUndo",
  "playIglooPiece",
  "playIglooLose",
  "playIglooComplete",
  "playIglooEnter",
  "playSplash",
  "playFishCollect",
  "playEnemyHit",
  "playBearNear",
  "playClamSnap",
  "playTempLow",
  "playTempZero",
  "playCountdown",
  "playCountdownGo",
  "playRoundEnd",
  "playVictory",
  "playGameOver",
];

export const SOUND_SCRIPT = [
  ...ONE_SHOTS.flatMap((method) => [[method], { wait: 800 }]),
  ["startAmbientWind"],
  ["startAmbientWind"],
  { wait: 200 },
  ["stopAmbientWind"],
  { wait: 100 },
  ["startAmbientWind"],
  { wait: 100 },
];
