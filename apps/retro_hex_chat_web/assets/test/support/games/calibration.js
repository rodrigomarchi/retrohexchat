import { describe, expect, it } from "vitest";

/**
 * How often the AI should win against an average player, per difficulty:
 * easy loses most matches, normal is even, hard is tough but beatable.
 */
export const AI_WIN_TARGETS = Object.freeze({ easy: 0.3, normal: 0.5, hard: 0.75 });

/** How far a measured win rate may sit from its target. */
export const AI_WIN_TOLERANCE = 0.1;

const DIFFICULTIES = ["easy", "normal", "hard"];

/**
 * A game's AI calibration: `play` runs one seeded trial at a difficulty and
 * says whether the AI won it. Every difficulty plays `trials` of them; the
 * win rates are printed as a table, must fall within the tolerance of their
 * targets, and must rise from easy to hard.
 *
 * A trial is whatever the game's strength is felt in — a match, a point, a
 * rally — as long as the targets are the AI's chance of taking it.
 * @param {string} game - the name the table is printed under
 * @param {object} options
 * @param {(trial: { difficulty: string, seed: number }) => boolean} options.play
 * @param {number} [options.trials]
 * @param {Record<string, number>} [options.targets] - a game's own targets,
 *   e.g. a co-op partner's, where the difficulty names the player's side
 * @param {number} [options.tolerance]
 * @param {string} [options.label] - what a trial is, for the table
 */
export function calibrate(game, options) {
  const {
    play,
    trials = 200,
    targets = AI_WIN_TARGETS,
    tolerance = AI_WIN_TOLERANCE,
    label = "matches",
  } = options;

  describe(`${game} AI calibration`, () => {
    const rates = {};

    for (const difficulty of DIFFICULTIES) {
      it(`${difficulty}: the AI wins about ${Math.round(targets[difficulty] * 100)}% of ${label}`, () => {
        let wins = 0;
        for (let seed = 1; seed <= trials; seed++) {
          if (play({ difficulty, seed })) wins++;
        }
        rates[difficulty] = wins / trials;
        // The table is what a calibration run is for, so it goes to the terminal.
        process.stdout.write(
          `${game} ${difficulty.padEnd(6)} AI won ${wins}/${trials} ${label} ` +
            `(${(rates[difficulty] * 100).toFixed(1)}%, target ${targets[difficulty] * 100}%)\n`,
        );
        expect(Math.abs(rates[difficulty] - targets[difficulty])).toBeLessThanOrEqual(tolerance);
      });
    }

    it("orders the difficulties the way their targets go", () => {
      const ordered = [...DIFFICULTIES].sort((a, b) => targets[a] - targets[b]);
      for (let i = 1; i < ordered.length; i++) {
        expect(rates[ordered[i]]).toBeGreaterThan(rates[ordered[i - 1]]);
      }
    });
  });
}
