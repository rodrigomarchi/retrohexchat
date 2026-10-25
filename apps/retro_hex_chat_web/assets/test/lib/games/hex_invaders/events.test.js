import { describe, it, expect, vi } from "vitest";
import { playEvents } from "../../../../js/lib/games/hex_invaders/index.js";

describe("the sounds of a step's events", () => {
  it("plays each event's sound, in the order they are heard", () => {
    const heard = [];
    const audio = new Proxy({}, { get: (_t, name) => vi.fn(() => heard.push(name)) });
    playEvents(audio, { alienKill: true, ufoKill: true, combo: 2, invaded: 1 });
    expect(heard).toEqual(["playAlienDestroyed", "playUFODestroyed", "playCombo", "playInvaded"]);
  });
});
