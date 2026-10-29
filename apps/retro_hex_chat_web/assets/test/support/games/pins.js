import { mkdirSync, writeFileSync } from "node:fs";
import path from "node:path";
import { describe, it, expect } from "vitest";
import { digest } from "./digest.js";
import { matchPerTest, recordedMatch } from "./harness.js";
import { voices } from "./voices.js";

/**
 * Characterization pins for one game: what it does today, recorded from
 * outside in four matches, so a refactor can prove it changed nothing.
 *
 * 1. solo — against the AI, until the match ends or `soloMs` pass;
 * 2. p2p — both sides following the game's key script for `p2pMs`;
 * 3. lossy — the same, losing the first ready announcements and one snapshot
 *    in seven;
 * 4. disconnect — the channel drops mid-match;
 * 5. to the end — against the hard AI, with the player idle, until the AI
 *    wins (up to `endMs`), for the game and each variant: the rounds, the
 *    match's end and its report, which the timed matches seldom reach.
 *
 * Each match is stored as a readable summary (phases, results, counts) and
 * digests of the full logs. When a digest changes, run with
 * `GAME_PINS_DUMP=<dir>` before and after the change to diff the full logs.
 *
 * @param {string} gameId
 * @param {object} options
 * @param {(side: "host"|"guest") => Array<object>} options.script - key presses
 *   for one side, `{ at, key, down }`
 * @param {number} [options.soloMs] - the longest a solo match runs
 * @param {number} [options.p2pMs] - how long the P2P matches run
 * @param {number} [options.disconnectAtMs]
 * @param {number} [options.endMs] - the longest a match to the end runs
 * @param {string[]} [options.variants] - other ids this engine plays (a mode of
 *   the same game); each gets its own solo match
 * @param {boolean} [options.soloOnly] - a one-player game: no AI, no wire, so
 *   its pins are the solo match on the key script, one to the end, and the
 *   same match twice
 * @param {(side: "host") => Array<object>} [options.endScript] - for a
 *   one-player game, the keys of the match played to the end
 */
export function pinGame(
  gameId,
  {
    script,
    soloMs = 60_000,
    p2pMs = 30_000,
    disconnectAtMs = 15_000,
    endMs = 600_000,
    variants = [],
    soloOnly = false,
    endScript = () => [],
  },
) {
  if (soloOnly) {
    pinOnePlayer(gameId, { script, soloMs, endMs, endScript });
    return;
  }

  const both = () => [
    ...script("host").map((press) => ({ ...press, side: "host" })),
    ...script("guest").map((press) => ({ ...press, side: "guest" })),
  ];

  describe(`${gameId} pins`, { timeout: PIN_TIMEOUT_MS }, () => {
    const play = matchPerTest();

    it("solo against the AI", async () => {
      await pinPlayedOut(play, { gameId, mode: "solo", seed: 1 }, soloMs, "solo");
    });

    for (const variant of variants) {
      it(`solo against the AI: ${variant}`, async () => {
        await pinPlayedOut(play, { gameId: variant, mode: "solo", seed: 1 }, soloMs, "solo");
      });
    }

    for (const id of [gameId, ...variants]) {
      it(`solo to the end: ${id}`, async () => {
        const options = { gameId: id, mode: "solo", seed: 1, matchSeed: 3, difficulty: "hard" };
        await pinPlayedOut(play, options, endMs, "end");
      });
    }

    it("P2P following the key script", async () => {
      const match = await play({ gameId, mode: "p2p", seed: 2, script: both() });
      match.advance(p2pMs);
      const record = match.record();
      dump(gameId, "p2p", record);

      expect(summarize(record)).toMatchSnapshot();
    });

    it("P2P over a channel that loses datagrams", async () => {
      const match = await play({ gameId, mode: "p2p", seed: 2, script: both(), drop: lossy() });
      match.advance(p2pMs);
      const record = match.record();
      dump(gameId, "lossy", record);

      expect(summarize(record)).toMatchSnapshot();
    });

    it("the channel drops mid-match", async () => {
      const match = await play({ gameId, mode: "p2p", seed: 2, script: both() });
      match.advance(disconnectAtMs);
      match.close();
      match.advance(1000);
      const record = match.record();
      match.stop();
      dump(gameId, "disconnect", record);

      expect({
        results: record.results,
        lastPhases: lastPhaseBySide(record.phases),
        state: record.state,
        leakedTimers: match.leaked,
      }).toMatchSnapshot();
    });

    itRecordsTheSameTwice({ gameId, mode: "p2p", seed: 3, script: both() });
  });
}

/** The pins of a one-player game: what it does alone, on its keys. */
function pinOnePlayer(gameId, { script, soloMs, endMs, endScript }) {
  const host = (presses) => presses.map((press) => ({ ...press, side: "host" }));

  describe(`${gameId} pins`, { timeout: PIN_TIMEOUT_MS }, () => {
    const play = matchPerTest();

    it("solo following the key script", async () => {
      const options = { gameId, mode: "solo", seed: 1, script: host(script("host")) };
      await pinPlayedOut(play, options, soloMs, "solo");
    });

    it(`solo to the end: ${gameId}`, async () => {
      const options = { gameId, mode: "solo", seed: 1, script: host(endScript("host")) };
      await pinPlayedOut(play, options, endMs, "end");
    });

    itRecordsTheSameTwice({ gameId, mode: "solo", seed: 3, script: host(script("host")) });
  });
}

/** The same match, played twice for ten seconds, recorded the same way. */
function itRecordsTheSameTwice(options) {
  it("records the same match the same way twice", async () => {
    const record = () => recordedMatch(options, 10_000);

    expect(digest(await record())).toBe(digest(await record()));
  });
}

/**
 * A match played until it is over or `limit` ms pass, its summary pinned and
 * its full record dumped as `scenario`.
 */
async function pinPlayedOut(play, options, limit, scenario) {
  const match = await play(options);
  const ended = match.runUntil(() => match.over(), limit);
  const record = match.record();
  dump(options.gameId, scenario, record);

  expect({ ended, ...summarize(record) }).toMatchSnapshot();
}

/**
 * A pin plays minutes of game in seconds, and `make ci` runs it beside other
 * suites; the default five seconds is too tight for the longest matches.
 */
const PIN_TIMEOUT_MS = 120_000;

/** Lose the first three ready announcements and every seventh snapshot. */
function lossy() {
  let readyLost = 0;
  let snapshots = 0;
  return (data, dir) => {
    const type = new Uint8Array(data)[0];
    if (dir === "guest>host" && type === 0x84 && readyLost < 3) {
      readyLost += 1;
      return true;
    }
    if (dir === "host>guest" && type === 0x80) {
      snapshots += 1;
      return snapshots % 7 === 0;
    }
    return false;
  };
}

/** The readable part of a record, plus a digest of each full log. */
export function summarize(record) {
  return {
    phases: record.phases,
    results: record.results,
    state: record.state,
    wire: summarizeWire(record.wire),
    sounds: Object.fromEntries(
      Object.entries(record.sounds).map(([side, log]) => [
        side,
        // What the sounds play, not the calls that built them (see voices.js).
        { voices: countVoices(log), digest: digest(voices(log)) },
      ]),
    ),
    draws: record.draws,
  };
}

function summarizeWire(wire) {
  const byDir = {};
  for (const { dir, hex, dropped } of wire) {
    const entry = (byDir[dir] ??= { datagrams: 0, bytes: 0, dropped: 0, types: {} });
    entry.datagrams += 1;
    entry.bytes += hex.length / 2;
    if (dropped) entry.dropped += 1;
    const type = hex.slice(0, 2);
    entry.types[type] = (entry.types[type] ?? 0) + 1;
  }
  return { byDir, digest: digest(wire), first: wire.slice(0, 6) };
}

/** How many oscillators, buffers and noise sources a side started. */
function countVoices(log) {
  const counts = {};
  for (const [, op] of log) {
    if (typeof op === "string" && op.startsWith("create")) counts[op] = (counts[op] ?? 0) + 1;
  }
  return counts;
}

function lastPhaseBySide(phases) {
  const last = {};
  for (const { side, phase } of phases) last[side] = phase;
  return last;
}

function dump(gameId, scenario, record) {
  const dir = process.env.GAME_PINS_DUMP;
  if (!dir) return;
  mkdirSync(dir, { recursive: true });
  writeFileSync(path.join(dir, `${gameId}-${scenario}.json`), JSON.stringify(record, null, 1));
}
