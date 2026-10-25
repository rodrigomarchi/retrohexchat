// @vitest-environment node
import { ESLint } from "eslint";
import { describe, it, expect } from "vitest";

/*
 * What a game may not write, enforced: the core already does each of these
 * once, and a game that does it again starts the next copy.
 */

const eslint = new ESLint();

async function messages(code, filePath) {
  const [result] = await eslint.lintText(code, { filePath });
  return result.messages.map((m) => m.message);
}

const IN_A_GAME = "js/lib/games/pong/physics.js";

describe("a game's own code", () => {
  it.each([
    ["new DataView(buf);", /codec/],
    ["ctx.createOscillator();", /synth/],
    ["setTimeout(() => {}, 100);", /ticks/],
    ["setInterval(() => {}, 100);", /ticks/],
    ["window.setTimeout(() => {}, 100);", /ticks/],
    ["const r = Math.random();", /game\.random/],
    ["class Pong extends GameEngine {}", /defineGame/],
    ['import { GameEngine } from "../../game_engine.js";', /defineGame/],
  ])("rejects %s", async (code, why) => {
    const found = await messages(code, IN_A_GAME);
    expect(
      found.some((m) => why.test(m)),
      found.join(" | "),
    ).toBe(true);
  });

  it("may hand Math.random on as a default, for its pure functions' tests", async () => {
    expect(
      await messages("export const f = (random = Math.random) => random();", IN_A_GAME),
    ).toEqual([]);
  });

  it("may draw decoration from Math.random in its renderer", async () => {
    expect(
      await messages("export const x = () => Math.random();", "js/lib/games/pong/renderer.js"),
    ).toEqual([]);
  });
});

describe("the core", () => {
  it("is where these live", async () => {
    const code = "export const f = (buf) => [new DataView(buf), Math.random(), setTimeout(f, 1)];";
    expect(await messages(code, "js/lib/games/core/rng.js")).toEqual([]);
  });
});
