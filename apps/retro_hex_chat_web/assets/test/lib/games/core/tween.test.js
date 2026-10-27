import { describe, it, expect } from "vitest";
import {
  bounce,
  easeOutBack,
  easeOutCubic,
  lerp,
  progress,
  tweenPoint,
} from "../../../../js/lib/games/core/tween.js";

const samples = Array.from({ length: 101 }, (_, i) => i / 100);

describe("the easing curves", () => {
  it("start at 0 and end at 1", () => {
    for (const ease of [easeOutCubic, easeOutBack, bounce]) {
      expect(ease(0)).toBeCloseTo(0, 10);
      expect(ease(1)).toBeCloseTo(1, 10);
    }
  });

  it("ease out without ever going back: the cubic", () => {
    const values = samples.map(easeOutCubic);
    expect(values.every((v, i) => i === 0 || v >= values[i - 1])).toBe(true);
    // Most of the way there in the first half: a flight that lands softly.
    expect(easeOutCubic(0.5)).toBeGreaterThan(0.8);
  });

  it("step past the end and settle back: the back curve", () => {
    const values = samples.map(easeOutBack);
    expect(Math.max(...values)).toBeGreaterThan(1);
    expect(values.at(-1)).toBeCloseTo(1, 10);
  });

  it("touch the ground more than once before resting: the bounce", () => {
    const grounded = samples.filter((t) => t > 0 && bounce(t) > 0.97).length;
    const values = samples.map(bounce);
    const dips = values.filter(
      (v, i) => i > 0 && i < values.length - 1 && v < values[i - 1] && v <= values[i + 1],
    ).length;
    expect(grounded).toBeGreaterThan(0);
    expect(dips).toBeGreaterThanOrEqual(2);
    expect(values.every((v) => v >= 0 && v <= 1)).toBe(true);
  });
});

describe("lerp", () => {
  it("runs from one value to the other", () => {
    expect([lerp(10, 20, 0), lerp(10, 20, 0.5), lerp(10, 20, 1)]).toEqual([10, 15, 20]);
  });
});

describe("progress", () => {
  it("is 0 before the start, 1 after the end, and in between on the way", () => {
    expect(progress(100, 10, 90)).toBe(0);
    expect(progress(100, 10, 100)).toBe(0);
    expect(progress(100, 10, 105)).toBe(0.5);
    expect(progress(100, 10, 110)).toBe(1);
    expect(progress(100, 10, 500)).toBe(1);
  });

  it("is already over for something that takes no time", () => {
    expect(progress(100, 0, 100)).toBe(1);
  });
});

describe("tweenPoint", () => {
  it("answers whole pixels, so pixel art never lands between two", () => {
    for (const t of samples) {
      const { x, y } = tweenPoint({ x: 3, y: 7 }, { x: 250, y: 131 }, t, easeOutBack);
      expect(Number.isInteger(x) && Number.isInteger(y)).toBe(true);
    }
    expect(tweenPoint({ x: 3, y: 7 }, { x: 250, y: 131 }, 1)).toEqual({ x: 250, y: 131 });
    expect(tweenPoint({ x: 3, y: 7 }, { x: 250, y: 131 }, 0)).toEqual({ x: 3, y: 7 });
  });
});
