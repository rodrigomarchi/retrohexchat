import { describe, expect, it } from "vitest";
import { TableAI, normalizeDifficulty } from "../../../../js/lib/games/core/ai.js";

const TABLE = { easy: { speed: 1 }, normal: { speed: 2 }, hard: { speed: 3 } };
const normalize = (difficulty) => normalizeDifficulty(difficulty, TABLE);

describe("TableAI", () => {
  it("starts at the difficulty it is made with, normal when it names none it knows", () => {
    expect(new TableAI({ difficulty: "hard" }, normalize, TABLE).difficulty).toBe("hard");
    expect(new TableAI({ difficulty: "legend" }, normalize, TABLE).difficulty).toBe("normal");
  });

  it("plays a turn by the row of the request's difficulty, which becomes its own", () => {
    const ai = new TableAI({ difficulty: "easy" }, normalize, TABLE);
    expect(ai.rowFor({})).toBe(TABLE.easy);
    expect(ai.rowFor({ difficulty: "hard" })).toBe(TABLE.hard);
    expect(ai.difficulty).toBe("hard");
    expect(ai.difficultyFor({})).toBe("hard");
  });

  it("switches through setDifficulty, which a subclass can extend", () => {
    const switched = [];
    class Watched extends TableAI {
      setDifficulty(difficulty) {
        super.setDifficulty(difficulty);
        switched.push(this.difficulty);
      }
    }
    const ai = new Watched({ difficulty: "easy" }, normalize, TABLE);
    ai.rowFor({ difficulty: "normal" });
    ai.rowFor({ difficulty: "normal" });
    expect(switched).toEqual(["normal"]);
  });

  it("counts each turn and reads the request: player two unless it names player one", () => {
    const ai = new TableAI({}, normalize, TABLE);
    const state = { phase: 1 };
    expect(ai.startTurn({ state })).toEqual({ state, player: 2 });
    expect(ai.startTurn({ state, player: 1 })).toEqual({ state, player: 1 });
    expect(ai.frame).toBe(2);
  });

  it("draws from the random function it is handed, or its own seed's stream", () => {
    const rng = () => 0.25;
    expect(new TableAI({ rng }, normalize, TABLE).rng).toBe(rng);
    const seeded = new TableAI({}, normalize, TABLE, 42).rng;
    expect(seeded()).toBe(new TableAI({}, normalize, TABLE, 42).rng());
  });
});
