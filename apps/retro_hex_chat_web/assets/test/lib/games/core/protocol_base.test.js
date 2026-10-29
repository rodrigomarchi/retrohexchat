import { describe, expect, it } from "vitest";
import {
  MSG_TYPE,
  ROUNDS_GAME_END,
  ROUND_STANDING_FIELDS,
  SEEDED_MATCH_HEADER,
  missileFields,
  phases,
} from "../../../../js/lib/games/core/protocol_base.js";
import { schema } from "../../../../js/lib/games/core/codec.js";
import { roundTrip } from "../../../support/games/protocol_tests.js";

describe("phases", () => {
  it("numbers WAITING 0, COUNTDOWN 1 and the game's own from 2, in order", () => {
    expect(phases("PLAYING", "FINISHED")).toEqual({
      WAITING: 0,
      COUNTDOWN: 1,
      PLAYING: 2,
      FINISHED: 3,
    });
  });
});

describe("the shared wire pieces", () => {
  it("ROUNDS_GAME_END carries the points, the winner and the rounds each side took", () => {
    const end = { score1: 4, score2: 2, winner: 1, roundWins1: 2, roundWins2: 1 };
    expect(ROUNDS_GAME_END.type).toBe(MSG_TYPE.GAME_END);
    expect(roundTrip(ROUNDS_GAME_END, end)).toEqual(end);
  });

  it("a snapshot of ROUND_STANDING_FIELDS reads back where the match stands", () => {
    const standing = {
      score1: 3,
      score2: 1,
      phase: 2,
      countdown: 0,
      round: 2,
      roundWins1: 1,
      roundWins2: 0,
    };
    expect(roundTrip(schema(MSG_TYPE.GAME_STATE, ROUND_STANDING_FIELDS), standing)).toEqual(
      standing,
    );
  });

  it("missileFields write a missile under its prefix, its position rounded", () => {
    const wire = schema(MSG_TYPE.GAME_STATE, missileFields("m2"));
    expect(roundTrip(wire, { m2X: 10.6, m2Y: 20, m2Active: true })).toEqual({
      m2X: 11,
      m2Y: 20,
      m2Active: true,
    });
  });

  it("SEEDED_MATCH_HEADER carries the phase, mode, round, countdown and a 32-bit seed", () => {
    const header = { phase: 2, mode: 1, round: 3, countdown: 0, seed: 0xfedcba98 };
    expect(roundTrip(schema(MSG_TYPE.GAME_STATE, SEEDED_MATCH_HEADER), header)).toEqual(header);
  });
});
