import { describe, expect, it } from "vitest";
import {
  BANDS,
  MAX_GAIN,
  createEqualizer,
  gainFor,
  preampGain,
} from "../../../js/lib/radio/equalizer.js";

function fakeContext() {
  return {
    createBiquadFilter: () => ({
      type: null,
      frequency: { value: 0 },
      Q: { value: 0 },
      gain: { value: 0 },
      next: null,
      connect(node) {
        this.next = node;
        return node;
      },
    }),
  };
}

describe("gainFor", () => {
  it("keeps a slider within the band's reach", () => {
    expect(gainFor("5")).toBe(5);
    expect(gainFor(40)).toBe(MAX_GAIN);
    expect(gainFor(-40)).toBe(-MAX_GAIN);
    expect(gainFor("nope")).toBe(0);
  });
});

describe("createEqualizer", () => {
  it("chains a filter per band, shelving the ends", () => {
    const equalizer = createEqualizer(fakeContext());
    const filters = [];
    for (let node = equalizer.input; node; node = node.next) filters.push(node);
    expect(filters.map((filter) => filter.frequency.value)).toEqual(BANDS);
    expect(filters[0].type).toBe("lowshelf");
    expect(filters[5].type).toBe("peaking");
    expect(filters.at(-1)).toBe(equalizer.output);
    expect(equalizer.output.type).toBe("highshelf");
  });

  it("raises a band and goes back to flat", () => {
    const equalizer = createEqualizer(fakeContext());
    equalizer.set(0, 9);
    expect(equalizer.input.gain.value).toBe(9);
    equalizer.flat();
    expect(equalizer.input.gain.value).toBe(0);
  });
});

describe("preampGain", () => {
  it("turns decibels into the gain a node multiplies by", () => {
    expect(preampGain(0)).toBe(1);
    expect(preampGain(6)).toBeCloseTo(1.995, 2);
    expect(preampGain(-40)).toBeCloseTo(0.251, 2);
  });
});
