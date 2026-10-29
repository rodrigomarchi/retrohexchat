import { describe, expect, it } from "vitest";
import {
  BAR_COUNT,
  curvePoints,
  fallPeaks,
  scopePoints,
  simulatedBars,
  spectrumBars,
} from "../../../js/lib/hex_device/visualizer.js";

describe("spectrumBars", () => {
  it("folds the bins into bars of 0 to 1", () => {
    const bars = spectrumBars(new Uint8Array(1024).fill(255), BAR_COUNT);
    expect(bars).toHaveLength(BAR_COUNT);
    for (const bar of bars) expect(bar).toBeCloseTo(1);
  });

  it("puts the low bins in the first bars", () => {
    const data = new Uint8Array(1024);
    data.fill(255, 0, 4);
    const bars = spectrumBars(data, BAR_COUNT);
    expect(bars[0]).toBeGreaterThan(0.9);
    expect(bars[BAR_COUNT - 1]).toBe(0);
  });

  it("is silence for no data", () => {
    expect(spectrumBars(new Uint8Array(0), 4)).toEqual([0, 0, 0, 0]);
  });
});

describe("simulatedBars", () => {
  it("moves within the display and changes with time", () => {
    const now = simulatedBars(1000);
    const later = simulatedBars(1400);
    expect(now).toHaveLength(BAR_COUNT);
    for (const bar of [...now, ...later]) {
      expect(bar).toBeGreaterThan(0);
      expect(bar).toBeLessThanOrEqual(1);
    }
    expect(now).not.toEqual(later);
  });
});

describe("fallPeaks", () => {
  it("holds a peak above a falling bar and lets it fall slowly", () => {
    const peaks = fallPeaks([0.9, 0.1], [0.2, 0.5]);
    expect(peaks[0]).toBeCloseTo(0.888);
    expect(peaks[1]).toBe(0.5);
  });
});

describe("scopePoints", () => {
  it("spreads the wave across the box", () => {
    const points = scopePoints(Uint8Array.from([0, 128, 255]), 100, 50);
    expect(points[0]).toEqual([0, 0]);
    expect(points[2][0]).toBe(100);
    expect(points[2][1]).toBe(50);
  });
});

describe("curvePoints", () => {
  it("puts a flat equalizer through the middle and a raised band above it", () => {
    const flat = curvePoints(new Array(10).fill(0), 90, 20);
    expect(flat[0]).toEqual([0, 10]);
    expect(flat[9]).toEqual([90, 10]);
    const raised = curvePoints([12, 0, -12], 20, 20);
    expect(raised[0][1]).toBe(1);
    expect(raised[2][1]).toBe(19);
  });
});
