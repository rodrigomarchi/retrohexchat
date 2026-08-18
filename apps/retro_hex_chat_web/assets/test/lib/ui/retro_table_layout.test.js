import { describe, expect, it } from "vitest";

import {
  MIN_COLUMN_WIDTH,
  columnSignature,
  distributeWidths,
  nextHiddenColumns,
} from "../../../js/lib/ui/retro_table_layout.js";

describe("columnSignature", () => {
  it("joins column keys with a separator", () => {
    expect(columnSignature(["name", "owner", "size"])).toBe("name|owner|size");
  });

  it("distinguishes different column sets", () => {
    expect(columnSignature(["a", "b"])).not.toBe(columnSignature(["a", "c"]));
  });

  it("is empty for no columns", () => {
    expect(columnSignature([])).toBe("");
  });
});

describe("distributeWidths", () => {
  it("returns [] when there is nothing laid out", () => {
    expect(distributeWidths([], 0)).toEqual([]);
    expect(distributeWidths([0, 0], 0)).toEqual([]);
  });

  it("adds up to exactly the laid-out total", () => {
    const widths = distributeWidths([100, 100, 100], 301);
    expect(widths.reduce((sum, w) => sum + w, 0)).toBe(301);
  });

  it("rounds the running edge, not each width, so collapsed borders don't drift", () => {
    // Three equal columns in a 301px table: 100.33 each would drift to 300 if
    // rounded independently; edge-rounding lands 100, 101, 100 = 301.
    expect(distributeWidths([100, 100, 100], 301)).toEqual([100, 101, 100]);
  });

  it("scales proportionally to the laid-out total", () => {
    const widths = distributeWidths([50, 150], 400);
    expect(widths).toEqual([100, 300]);
  });

  it("never returns a column narrower than the minimum", () => {
    const widths = distributeWidths([1, 1000], 1010);
    expect(Math.min(...widths)).toBeGreaterThanOrEqual(MIN_COLUMN_WIDTH);
  });

  it("falls back to the measured total when no laid-out width is given", () => {
    expect(distributeWidths([100, 100], 0)).toEqual([100, 100]);
  });
});

describe("nextHiddenColumns", () => {
  it("hides a visible column", () => {
    const next = nextHiddenColumns(new Set(), "owner", 3);
    expect(next.has("owner")).toBe(true);
  });

  it("shows a hidden column", () => {
    const next = nextHiddenColumns(new Set(["owner"]), "owner", 2);
    expect(next.has("owner")).toBe(false);
  });

  it("refuses to hide the last visible column, returning the same set", () => {
    const hidden = new Set(["a", "b"]);
    const next = nextHiddenColumns(hidden, "c", 1);
    expect(next).toBe(hidden);
  });

  it("does not mutate the input set", () => {
    const hidden = new Set();
    nextHiddenColumns(hidden, "owner", 3);
    expect(hidden.size).toBe(0);
  });
});
