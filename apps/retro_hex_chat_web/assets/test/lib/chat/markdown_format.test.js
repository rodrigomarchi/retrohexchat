import { describe, expect, it } from "vitest";

import { MARKDOWN_FORMATS, applyMarkdownFormat } from "../../../js/lib/chat/markdown_format.js";

const state = (value, start = value.length, end = start) => ({
  value,
  selectionStart: start,
  selectionEnd: end,
});

describe("applyMarkdownFormat — wrap", () => {
  const bold = MARKDOWN_FORMATS["md-bold"];

  it("wraps a selection and puts the caret after it", () => {
    const result = applyMarkdownFormat(state("hello world", 0, 5), bold);
    expect(result.value).toBe("**hello** world");
    expect(result.selectionStart).toBe(9);
    expect(result.selectionEnd).toBe(9);
  });

  it("inserts the placeholder and selects it when nothing is selected", () => {
    const result = applyMarkdownFormat(state("", 0, 0), bold);
    expect(result.value).toBe("**text**");
    expect(result.value.slice(result.selectionStart, result.selectionEnd)).toBe("text");
  });

  it("uses distinct before/after for links", () => {
    const result = applyMarkdownFormat(state("site", 0, 4), MARKDOWN_FORMATS["md-link"]);
    expect(result.value).toBe("[site](https://)");
  });
});

describe("applyMarkdownFormat — prefix", () => {
  it("prefixes every selected line", () => {
    const result = applyMarkdownFormat(state("a\nb", 0, 3), MARKDOWN_FORMATS["md-quote"]);
    expect(result.value).toBe("> a\n> b");
    expect(result.selectionStart).toBe(0);
    expect(result.selectionEnd).toBe(result.value.length);
  });

  it("uses the placeholder when nothing is selected", () => {
    const result = applyMarkdownFormat(state("", 0, 0), MARKDOWN_FORMATS["md-heading"]);
    expect(result.value).toBe("# heading");
  });
});

describe("applyMarkdownFormat — ordered list", () => {
  it("numbers each selected line from one", () => {
    const result = applyMarkdownFormat(
      state("first\nsecond\nthird", 0, 18),
      MARKDOWN_FORMATS["md-ordered-list"],
    );
    expect(result.value).toBe("1. first\n2. second\n3. third");
  });
});

describe("applyMarkdownFormat — selection fallback", () => {
  it("treats a null selection as the end of the value", () => {
    const result = applyMarkdownFormat(
      { value: "abc", selectionStart: null, selectionEnd: null },
      MARKDOWN_FORMATS["md-bold"],
    );
    expect(result.value).toBe("abc**text**");
  });
});
