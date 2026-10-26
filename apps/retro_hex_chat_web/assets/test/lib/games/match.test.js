import { describe, it, expect, afterEach, vi } from "vitest";
import { BASE_MSG } from "../../../js/lib/games/net_protocol.js";
import { PHASE as HOCKEY } from "../../../js/lib/games/hex_hockey/protocol.js";
import { PHASE as OUTLAW } from "../../../js/lib/games/hex_outlaw/protocol.js";
import { PHASE as RAID } from "../../../js/lib/games/hex_raid/protocol.js";
import { PHASE as STAR_DUEL } from "../../../js/lib/games/star_duel/protocol.js";
import { PHASE as PONG } from "../../../js/lib/games/pong/protocol.js";
import { PHASE as TANKS } from "../../../js/lib/games/pixel_tanks/protocol.js";
import {
  MSG_TYPE as TRAILS_MSG,
  PHASE as TRAILS,
} from "../../../js/lib/games/surround/protocol.js";
import { PHASE as WARLORDS } from "../../../js/lib/games/warlords/protocol.js";
import { playMatch } from "../../support/games/harness.js";
import { TWO_PLAYER_ENGINE_GAME_IDS } from "../../support/games/engines.js";

/*
 * The seams between the two sides of a P2P match, where these games have
 * broken before: a guest that drew only when a snapshot landed, a turn lost
 * with its one datagram, a catch released on the guest's key-up, a canvas
 * frozen the moment play began, a flash that faded with the paint.
 */

let match = null;

afterEach(() => {
  match?.stop();
  match?.restore();
  match = null;
});

async function underway(gameId, phase, options = {}) {
  match = await playMatch({ gameId, mode: "p2p", seed: 2, matchSeed: 5, ...options });
  const reached = match.runUntil(() => match.engines.host.gameState?.phase === phase, 30_000);
  expect(reached, `${gameId} reaches phase ${phase}`).toBe(true);
}

/** Frames each side paints in `ms`: every frame ends with the vignette. */
function paintsIn(ms) {
  const sides = Object.keys(match.canvases);
  for (const side of sides) {
    match.canvases[side].clearLog();
    match.canvases[side].recording = true;
  }
  match.advance(ms);
  return Object.fromEntries(
    sides.map((side) => [
      side,
      match.canvases[side].log.filter(([op]) => op === "createRadialGradient").length,
    ]),
  );
}

const typeOf = (entry) => parseInt(entry.hex.slice(0, 2), 16);

describe("both peers draw", () => {
  it("gives the guest its own frame rate, not the host's send rate", async () => {
    await underway("hex_pong", PONG.PLAYING);
    // The ball held still: no point, no phase change, for the second measured.
    Object.assign(match.engines.host.gameState, { ballVX: 0, ballVY: 0 });
    const paints = paintsIn(1000);
    expect(paints.host).toBeGreaterThan(45);
    expect(paints.guest).toBeGreaterThan(45);
    expect(paints.guest).toBeGreaterThan(paints.host * 0.8);
  });

  it("keeps drawing once play begins in a game that animates its pauses", async () => {
    await underway("pixel_tanks", TANKS.PLAYING);
    expect(paintsIn(500).host).toBeGreaterThan(20);
  });
});

// Light Trails' input is a command, not a held key: no later datagram
// restates a turn.
describe("Light Trails — discrete input", () => {
  it("delivers a turn from the guest to the host", async () => {
    await underway("light_trails", TRAILS.PLAYING);
    match.key("guest", "ArrowUp");
    match.advance(100);
    expect(match.engines.host.p2PendingDir).toBe(0);
  });

  it("survives losing copies of the turn", async () => {
    let lost = 0;
    await underway("light_trails", TRAILS.PLAYING, {
      drop: (data, dir) => {
        if (dir !== "guest>host" || new Uint8Array(data)[0] !== BASE_MSG.INPUT_EDGE) return false;
        if (lost === 2) return false;
        lost += 1;
        return true;
      },
    });
    match.key("guest", "ArrowLeft");
    match.advance(300);
    // Two of the three copies were dropped; the third carries it.
    expect(lost).toBe(2);
    expect(match.engines.host.p2PendingDir).toBe(2);
  });

  it("moves the grid at 10Hz off the 60Hz clock", async () => {
    await underway("light_trails", TRAILS.PLAYING);
    const before = match.record().wire.length;
    match.advance(1000);
    // Every grid move sends one snapshot.
    const moves = match
      .record()
      .wire.slice(before)
      .filter((entry) => entry.dir === "host>guest" && typeOf(entry) === TRAILS_MSG.GAME_STATE);
    expect(moves.length).toBeGreaterThanOrEqual(8);
    expect(moves.length).toBeLessThanOrEqual(12);
  });
});

// The catch is released when the guest lets go of space.
describe("Hex Warlords — release-triggered launch", () => {
  it("lets the guest launch a fireball it caught, on letting go", async () => {
    await underway("hex_warlords", WARLORDS.PLAYING);
    Object.assign(match.engines.host.gameState, { caughtBy: 2, fireballSpeed: 3 });
    match.key("guest", " ", "keydown");
    match.advance(500);
    expect(match.engines.host.gameState.caughtBy).toBe(2);
    match.key("guest", " ", "keyup");
    match.advance(100);
    expect(match.engines.host.gameState.caughtBy).toBe(0);
  });
});

describe("Pixel Tanks — the round-over pause", () => {
  it("lets its particles settle while the round stands still", async () => {
    await underway("pixel_tanks", TANKS.PLAYING);
    Object.assign(match.engines.host.gameState, { roundTimer: 1, score1: 1 });
    match.runUntil(() => match.engines.host.gameState.phase === TANKS.ROUND_OVER, 2000);
    match.engines.host.particles = Array.from({ length: 30 }, () => ({
      x: 100,
      y: 100,
      vx: 1,
      vy: 1,
      life: 20,
    }));
    match.advance(500);
    expect(match.engines.host.particles.length).toBeLessThan(30);
  });
});

// The goal flash counts simulation steps: decaying it on paint as well tied
// it to the display, and a 120Hz panel lost it twice as fast.
describe("Hex Hockey — the goal flash", () => {
  it("fades one step at a time", async () => {
    await underway("hex_hockey", HOCKEY.PLAYING);
    match.engines.host.goalFlash = 60;
    match.advance(Math.round((10 * 1000) / 60));
    expect(match.engines.host.goalFlash).toBe(50);
  });
});

// What a game does when the window loses focus, or the match stops: the key
// releases that will never arrive, and the sounds they would have ended.
describe("losing focus and stopping", () => {
  it("Star Duel stops the thrust's roar when the window loses focus", async () => {
    await underway("star_duel", STAR_DUEL.PLAYING);
    const stopThrust = vi.spyOn(match.engines.host.audio, "stopThrust");
    window.dispatchEvent(new Event("blur"));
    expect(stopThrust).toHaveBeenCalled();
  });

  it("Outlaw lets go of both triggers when the window loses focus", async () => {
    await underway("hex_outlaw", OUTLAW.PLAYING);
    Object.assign(match.engines.host, { localFirePressed: true, remoteFirePressed: true });
    window.dispatchEvent(new Event("blur"));
    expect(match.engines.host).toMatchObject({ localFirePressed: false, remoteFirePressed: false });
  });

  it("Raid forgets held triggers and the peer when it stops", async () => {
    await underway("hex_raid", RAID.FLYING);
    const { host } = match.engines;
    Object.assign(host, { localFirePressed: true, localMinePressed: true });
    host.stop();
    expect(host).toMatchObject({
      localFirePressed: false,
      localMinePressed: false,
      peerReady: false,
    });
  });
});

describe("Light Trails — a command out of range", () => {
  it("is ignored; the next real turn still lands", async () => {
    await underway("light_trails", TRAILS.PLAYING);
    const before = match.engines.host.p2PendingDir;
    match.engines.guest.sendInputEdge(9);
    match.advance(100);
    expect(match.engines.host.p2PendingDir).toBe(before);
    match.engines.guest.sendInputEdge(2);
    match.advance(100);
    expect(match.engines.host.p2PendingDir).toBe(2);
  });
});

// Datagrams a well-behaved peer never sends, but a broken or out-of-date one
// can: the host's own snapshot echoed back, a snapshot cut short. A one-player
// game has no peer.
const ENGINES = TWO_PLAYER_ENGINE_GAME_IDS;

const bytesOf = (hex) => new Uint8Array(hex.match(/../g).map((b) => parseInt(b, 16))).buffer;

describe.each(ENGINES)("%s — a peer's stray datagrams", (gameId) => {
  it("the host ignores a snapshot sent to it", async () => {
    match = await playMatch({ gameId, mode: "p2p", seed: 2, matchSeed: 5 });
    match.advance(500);
    const { host } = match.engines;
    const early = host.gameState.phase;
    const snapshot = match
      .record()
      .wire.filter((entry) => entry.dir === "host>guest" && typeOf(entry) === 0x80)
      .at(-1);
    expect(match.runUntil(() => host.gameState.phase !== early, 30_000)).toBe(true);
    const now = host.gameState.phase;

    match.send("guest", bytesOf(snapshot.hex));
    match.advance(1);

    expect(host.gameState.phase).toBe(now);
  });

  it("the guest ignores a snapshot cut short", async () => {
    match = await playMatch({ gameId, mode: "p2p", seed: 2, matchSeed: 5 });
    match.advance(500);
    const { guest } = match.engines;
    const before = guest.gameState.phase;

    match.send("host", new Uint8Array([0x80]).buffer);

    expect(() => match.advance(1)).not.toThrow();
    expect(guest.gameState.phase).toBe(before);
  });
});
