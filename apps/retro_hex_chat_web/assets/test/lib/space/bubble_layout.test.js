import { describe, it, expect } from "vitest";

import {
  wrapBubbleText,
  bubbleDurationMs,
  BUBBLE_MAX_LINES,
} from "../../../js/lib/space/bubble_layout.js";

// A monospace font: every character is 6px wide.
const measure = (s) => s.length * 6;

describe("wrapBubbleText", () => {
  it("keeps a short line on one line", () => {
    expect(wrapBubbleText("hello plaza", measure)).toEqual(["hello plaza"]);
  });

  it("wraps at the bubble width without splitting words", () => {
    const lines = wrapBubbleText("the party is on the north island tonight", measure, {
      maxWidth: 60,
    });

    expect(lines).toEqual(["the party", "is on the", "north", "island…"]);
  });

  it("never draws more than the maximum number of lines, and says it was cut", () => {
    const text = Array.from({ length: 80 }, (_, i) => `word${i}`).join(" ");
    const lines = wrapBubbleText(text, measure);

    expect(lines).toHaveLength(BUBBLE_MAX_LINES);
    expect(lines.at(-1).endsWith("…")).toBe(true);
    for (const line of lines) expect(measure(line)).toBeLessThanOrEqual(150);
  });

  it("breaks a word too long for any line where it overflows", () => {
    const lines = wrapBubbleText("a".repeat(30), measure, { maxWidth: 60 });

    expect(lines).toEqual(["aaaaaaaaaa", "aaaaaaaaaa", "aaaaaaaaaa"]);
  });

  it("collapses runs of whitespace", () => {
    expect(wrapBubbleText("  hi    there  ", measure)).toEqual(["hi there"]);
  });
});

describe("bubbleDurationMs", () => {
  it("gives a short line the usual five seconds", () => {
    expect(bubbleDurationMs("hi")).toBe(5000);
  });

  it("gives a longer line more time, up to a ceiling", () => {
    const medium = bubbleDurationMs(Array(12).fill("word").join(" "));
    expect(medium).toBeGreaterThan(5000);
    expect(bubbleDurationMs(Array(200).fill("word").join(" "))).toBe(10000);
  });
});
