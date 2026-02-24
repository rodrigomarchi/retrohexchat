import { parseMultiLinePaste } from "../../../js/lib/chat/paste.js";

describe("parseMultiLinePaste", () => {
  it("returns lines array for multi-line text", () => {
    const result = parseMultiLinePaste("hello\nworld");
    expect(result).toEqual(["hello", "world"]);
  });

  it("returns null for single-line text", () => {
    expect(parseMultiLinePaste("just one line")).toBeNull();
  });

  it("returns null for empty string", () => {
    expect(parseMultiLinePaste("")).toBeNull();
  });

  it("filters out blank lines", () => {
    const result = parseMultiLinePaste("hello\n\n\nworld");
    expect(result).toEqual(["hello", "world"]);
  });

  it("filters out whitespace-only lines", () => {
    const result = parseMultiLinePaste("hello\n   \n\t\nworld");
    expect(result).toEqual(["hello", "world"]);
  });

  it("returns null when all lines except one are empty", () => {
    expect(parseMultiLinePaste("hello\n\n\n")).toBeNull();
  });

  it("handles three or more lines", () => {
    const result = parseMultiLinePaste("a\nb\nc");
    expect(result).toEqual(["a", "b", "c"]);
  });

  it("handles Windows-style line endings", () => {
    // \r\n splits on \n, leaving \r attached — filter trims it
    const result = parseMultiLinePaste("hello\r\nworld");
    expect(result).toHaveLength(2);
  });
});
