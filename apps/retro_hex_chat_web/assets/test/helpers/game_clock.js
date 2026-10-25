import { vi } from "vitest";

/**
 * Fake the page's timers only. The default fake timers also fake
 * requestAnimationFrame, which would run an engine's own frame loop beside
 * the steps a test drives by hand with `advance`.
 */
export function useFakePageTimers() {
  vi.useFakeTimers({
    toFake: ["setTimeout", "clearTimeout", "setInterval", "clearInterval", "Date"],
  });
}

/**
 * Let `ms` of a match go by for an engine whose frames the test drives by
 * hand: the page's timers run, and so do the simulation steps a 60 Hz clock
 * takes in that time — the match's phases count those steps, not the timers.
 * @param {{ _gameLoop: () => void }} engine
 * @param {number} ms
 */
export function advance(engine, ms) {
  vi.advanceTimersByTime(ms);
  const steps = Math.round((ms * 60) / 1000);
  for (let i = 0; i < steps; i++) engine._gameLoop();
}
