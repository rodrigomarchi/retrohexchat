/**
 * Applying a markdown formatting action to a text selection — pure, no DOM.
 *
 * The toolbar hook reads the composer's value and selection, calls this, and
 * writes the result back. Wrapping, line-prefixing and ordered-list numbering
 * shared one skeleton across three near-identical methods; that skeleton lives
 * here now, tested against plain strings.
 *
 * @module chat/markdown_format
 */

/** The formatting actions, keyed by the toolbar button's `data-format-code`. */
export const MARKDOWN_FORMATS = {
  "md-heading": { kind: "prefix", prefix: "# ", placeholder: "heading" },
  "md-bold": { kind: "wrap", before: "**", after: "**", placeholder: "text" },
  "md-italic": { kind: "wrap", before: "_", after: "_", placeholder: "text" },
  "md-strike": { kind: "wrap", before: "~~", after: "~~", placeholder: "text" },
  "md-code": { kind: "wrap", before: "`", after: "`", placeholder: "code" },
  "md-code-block": { kind: "wrap", before: "```\n", after: "\n```", placeholder: "code" },
  "md-link": { kind: "wrap", before: "[", after: "](https://)", placeholder: "text" },
  "md-quote": { kind: "prefix", prefix: "> ", placeholder: "quote" },
  "md-list": { kind: "prefix", prefix: "- ", placeholder: "item" },
  "md-ordered-list": { kind: "ordered-list", placeholder: "item" },
};

/**
 * @typedef {{value: string, selectionStart: number, selectionEnd: number}} TextState
 */

/**
 * The text state after applying a markdown format.
 *
 * @param {TextState} state the composer's value and selection
 * @param {object} format one of MARKDOWN_FORMATS
 * @returns {TextState}
 */
export function applyMarkdownFormat({ value, selectionStart, selectionEnd }, format) {
  const start = selectionStart ?? value.length;
  const end = selectionEnd ?? value.length;

  if (format.kind === "prefix") return prefixLines(value, start, end, format);
  if (format.kind === "ordered-list") return numberLines(value, start, end, format);
  return wrapSelection(value, start, end, format);
}

function wrapSelection(value, start, end, format) {
  const selected = value.slice(start, end);
  const body = selected || format.placeholder;
  const replacement = format.before + body + format.after;
  const nextValue = value.slice(0, start) + replacement + value.slice(end);

  if (selected) {
    const caret = start + replacement.length;
    return { value: nextValue, selectionStart: caret, selectionEnd: caret };
  }

  const placeholderStart = start + format.before.length;
  return {
    value: nextValue,
    selectionStart: placeholderStart,
    selectionEnd: placeholderStart + format.placeholder.length,
  };
}

function prefixLines(value, start, end, format) {
  const selected = value.slice(start, end) || format.placeholder;
  const replacement = selected
    .split("\n")
    .map((line) => format.prefix + line)
    .join("\n");

  return {
    value: value.slice(0, start) + replacement + value.slice(end),
    selectionStart: start,
    selectionEnd: start + replacement.length,
  };
}

function numberLines(value, start, end, format) {
  const selected = value.slice(start, end) || format.placeholder;
  const replacement = selected
    .split("\n")
    .map((line, index) => `${index + 1}. ${line}`)
    .join("\n");

  return {
    value: value.slice(0, start) + replacement + value.slice(end),
    selectionStart: start,
    selectionEnd: start + replacement.length,
  };
}
