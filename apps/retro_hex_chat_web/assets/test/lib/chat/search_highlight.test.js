import { afterEach, describe, expect, it, vi } from "vitest";

import {
  createSearchHighlighter,
  filterMentionTargets,
} from "../../../js/lib/chat/search_highlight.js";

if (!Element.prototype.scrollIntoView) Element.prototype.scrollIntoView = () => {};

afterEach(() => {
  document.body.innerHTML = "";
  vi.restoreAllMocks();
});

describe("filterMentionTargets", () => {
  function el(text) {
    const d = document.createElement("div");
    d.textContent = text;
    return d;
  }

  it("returns all elements when no nick is given", () => {
    const els = [el("a"), el("b")];
    expect(filterMentionTargets(els, null)).toHaveLength(2);
  });

  it("keeps only elements mentioning the nick, case-insensitive", () => {
    const els = [el("hi Alice"), el("nothing"), el("ALICE here")];
    const kept = filterMentionTargets(els, "alice");
    expect(kept).toHaveLength(2);
  });
});

describe("createSearchHighlighter", () => {
  function container(html) {
    const node = document.createElement("div");
    node.id = "chat-messages";
    node.innerHTML = html;
    document.body.appendChild(node);
    return node;
  }

  it("counts zero and pushes for an empty query", () => {
    const onCount = vi.fn();
    const h = createSearchHighlighter({ onCount, getContainer: () => container("") });
    h.highlight({ query: "" });
    expect(onCount).toHaveBeenCalledWith({ count: 0 });
  });

  it("reports an invalid regex through the count port", () => {
    const onCount = vi.fn();
    const h = createSearchHighlighter({
      onCount,
      getContainer: () => container('<div class="chat-content">hi</div>'),
      invalidRegexMessage: "bad",
    });
    h.highlight({ query: "(", regex: true });
    expect(onCount).toHaveBeenCalledWith({ count: 0, error: "bad" });
  });

  it("highlights matches and reports the count", () => {
    const onCount = vi.fn();
    const node = container('<div class="chat-content">alpha alpha beta</div>');
    const h = createSearchHighlighter({ onCount, getContainer: () => node });
    h.highlight({ query: "alpha" });
    const last = onCount.mock.calls.at(-1)[0];
    expect(last.count).toBe(2);
    expect(node.querySelectorAll("mark.search-highlight").length).toBe(2);
  });

  it("filters by mention nick before highlighting", () => {
    const onCount = vi.fn();
    const node = container(
      '<div class="chat-content">alice: hi word</div><div class="chat-content">bob: word</div>',
    );
    const h = createSearchHighlighter({ onCount, getContainer: () => node });
    h.highlight({ query: "word", mention_nick: "alice" });
    expect(onCount.mock.calls.at(-1)[0].count).toBe(1);
  });

  it("clear removes highlights", () => {
    const onCount = vi.fn();
    const node = container('<div class="chat-content">alpha</div>');
    const h = createSearchHighlighter({ onCount, getContainer: () => node });
    h.highlight({ query: "alpha" });
    h.clear();
    expect(node.querySelectorAll("mark.search-highlight").length).toBe(0);
  });
});
