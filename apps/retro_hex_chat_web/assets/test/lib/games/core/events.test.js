import { describe, expect, it } from "vitest";
import { cueSounds, playFlags } from "../../../../js/lib/games/core/events.js";

/** An audio object that writes down what it is asked to play. */
function listener() {
  const heard = [];
  const audio = new Proxy(
    {},
    {
      get:
        (_t, name) =>
        (...args) =>
          heard.push(args.length ? [name, ...args] : name),
    },
  );
  return { audio, heard };
}

/** Feed successive states through the cues; returns what was heard. */
function play(cues, states) {
  const { audio, heard } = listener();
  const game = { audio };
  for (let i = 1; i < states.length; i++) cueSounds(cues, states[i - 1], states[i], game);
  return heard;
}

describe("cueSounds", () => {
  it("plays a phase's sound on entering it, not while it lasts", () => {
    const cues = [{ phase: 1, play: "countdown" }];
    expect(
      play(cues, [{ phase: 0 }, { phase: 1 }, { phase: 1 }, { phase: 2 }, { phase: 1 }]),
    ).toEqual(["playCountdown", "playCountdown"]);
  });

  it("plays when a value changes, and not on a snapshot that repeats it", () => {
    const cues = [{ change: (s) => s.score1 + s.score2, play: "score" }];
    expect(
      play(cues, [
        { score1: 0, score2: 0 },
        { score1: 1, score2: 0 },
        { score1: 1, score2: 0 },
      ]),
    ).toEqual(["playScore"]);
  });

  it("plays when a flag rises, not while it stays up", () => {
    const cues = [{ rise: (s) => s.hit, play: "hit" }];
    expect(
      play(cues, [{ hit: false }, { hit: true }, { hit: true }, { hit: false }, { hit: true }]),
    ).toEqual(["playHit", "playHit"]);
  });

  it("plays the sound of every event bit a snapshot carries, in the order declared", () => {
    const cues = [
      {
        flags: (s) => s.events,
        sounds: [
          [1, "shot"],
          [4, "goal"],
          [2, "bounce"],
        ],
      },
    ];
    expect(play(cues, [{ events: 0 }, { events: 7 }, { events: 2 }])).toEqual([
      "playShot",
      "playGoal",
      "playBounce",
      "playBounce",
    ]);
  });

  it("plays when a condition on the two states holds", () => {
    const cues = [{ when: (s, prev) => s.lives < prev.lives, play: "lifeLost" }];
    expect(play(cues, [{ lives: 3 }, { lives: 2 }, { lives: 2 }])).toEqual(["playLifeLost"]);
  });

  it("hands a cue's play the game and both states, for a sound that needs them", () => {
    const cues = [{ change: (s) => s.score, play: (game, s) => game.audio.playHit(s.points) }];
    expect(play(cues, [{ score: 0 }, { score: 3, points: 3 }])).toEqual([["playHit", 3]]);
  });

  it("plays every cue that fires, in the order the cues are declared", () => {
    const cues = [
      { phase: 2, play: "roundOver" },
      { change: (s) => s.score, play: "point" },
    ];
    expect(
      play(cues, [
        { phase: 1, score: 0 },
        { phase: 2, score: 1 },
      ]),
    ).toEqual(["playRoundOver", "playPoint"]);
  });
});

describe("playFlags", () => {
  it("plays the sound of every bit set, in the table's order, from the same table a cue uses", () => {
    const { audio, heard } = listener();
    playFlags(
      { audio },
      [
        [4, "goal"],
        [1 | 2, "shot"],
      ],
      2 | 4,
    );
    expect(heard).toEqual(["playGoal", "playShot"]);
  });
});
