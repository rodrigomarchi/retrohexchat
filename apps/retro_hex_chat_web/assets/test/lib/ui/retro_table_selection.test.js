import { describe, expect, it } from "vitest";

import {
  nextRowIndex,
  nextSelection,
  pruneSelection,
  toTSV,
} from "../../../js/lib/ui/retro_table_selection.js";

describe("nextRowIndex", () => {
  it("returns null for an empty listing", () => {
    expect(nextRowIndex("ArrowDown", -1, 0, 10)).toBeNull();
  });

  it("returns null for a key that is not navigation", () => {
    expect(nextRowIndex("x", 0, 5, 10)).toBeNull();
  });

  it("moves down and up by one, clamped to the ends", () => {
    expect(nextRowIndex("ArrowDown", 0, 5, 10)).toBe(1);
    expect(nextRowIndex("ArrowDown", 4, 5, 10)).toBe(4);
    expect(nextRowIndex("ArrowUp", 2, 5, 10)).toBe(1);
    expect(nextRowIndex("ArrowUp", 0, 5, 10)).toBe(0);
  });

  it("treats no cursor as the first row", () => {
    expect(nextRowIndex("ArrowDown", -1, 5, 10)).toBe(1);
  });

  it("pages by rowsPerPage, clamped", () => {
    expect(nextRowIndex("PageDown", 0, 100, 20)).toBe(20);
    expect(nextRowIndex("PageDown", 90, 100, 20)).toBe(99);
    expect(nextRowIndex("PageUp", 30, 100, 20)).toBe(10);
    expect(nextRowIndex("PageUp", 5, 100, 20)).toBe(0);
  });

  it("jumps home and end", () => {
    expect(nextRowIndex("Home", 40, 100, 20)).toBe(0);
    expect(nextRowIndex("End", 40, 100, 20)).toBe(99);
  });
});

describe("nextSelection", () => {
  const rowIds = ["a", "b", "c", "d", "e"];

  it("returns null for a row that is not present", () => {
    const result = nextSelection({
      rowIds,
      selection: new Set(),
      anchor: null,
      rowId: "z",
      extend: false,
      toggle: false,
    });
    expect(result).toBeNull();
  });

  it("plain move selects only the target and re-anchors", () => {
    const result = nextSelection({
      rowIds,
      selection: new Set(["a", "b"]),
      anchor: "a",
      rowId: "d",
      extend: false,
      toggle: false,
    });
    expect([...result.selection]).toEqual(["d"]);
    expect(result.anchor).toBe("d");
    expect(result.cursor).toBe("d");
  });

  it("shift extends the range from the anchor", () => {
    const result = nextSelection({
      rowIds,
      selection: new Set(["b"]),
      anchor: "b",
      rowId: "d",
      extend: true,
      toggle: false,
    });
    expect([...result.selection]).toEqual(["b", "c", "d"]);
    expect(result.anchor).toBe("b");
  });

  it("shift extends upward too", () => {
    const result = nextSelection({
      rowIds,
      selection: new Set(["d"]),
      anchor: "d",
      rowId: "b",
      extend: true,
      toggle: false,
    });
    expect([...result.selection].sort()).toEqual(["b", "c", "d"]);
  });

  it("shift without an anchor falls back to a plain move", () => {
    const result = nextSelection({
      rowIds,
      selection: new Set(),
      anchor: null,
      rowId: "c",
      extend: true,
      toggle: false,
    });
    expect([...result.selection]).toEqual(["c"]);
  });

  it("toggle adds an unselected row and keeps the rest", () => {
    const result = nextSelection({
      rowIds,
      selection: new Set(["a"]),
      anchor: "a",
      rowId: "c",
      extend: false,
      toggle: true,
    });
    expect([...result.selection].sort()).toEqual(["a", "c"]);
    expect(result.anchor).toBe("c");
  });

  it("toggle removes a selected row", () => {
    const result = nextSelection({
      rowIds,
      selection: new Set(["a", "c"]),
      anchor: "c",
      rowId: "c",
      extend: false,
      toggle: true,
    });
    expect([...result.selection]).toEqual(["a"]);
  });

  it("does not mutate the input selection", () => {
    const selection = new Set(["a"]);
    nextSelection({ rowIds, selection, anchor: "a", rowId: "c", extend: false, toggle: true });
    expect([...selection]).toEqual(["a"]);
  });
});

describe("pruneSelection", () => {
  it("keeps only ids still present", () => {
    const next = pruneSelection(new Set(["a", "b", "c"]), new Set(["a", "c"]));
    expect([...next].sort()).toEqual(["a", "c"]);
  });

  it("returns a new set", () => {
    const selection = new Set(["a"]);
    const next = pruneSelection(selection, new Set(["a"]));
    expect(next).not.toBe(selection);
  });
});

describe("toTSV", () => {
  it("joins headings and rows with tabs and newlines", () => {
    const text = toTSV(
      ["Name", "Owner"],
      [
        ["a.txt", "alice"],
        ["b.txt", "bob"],
      ],
    );
    expect(text).toBe("Name\tOwner\na.txt\talice\nb.txt\tbob");
  });

  it("emits only the heading line when nothing is selected", () => {
    expect(toTSV(["Name"], [])).toBe("Name");
  });
});
