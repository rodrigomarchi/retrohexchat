import { afterEach, describe, expect, it, vi } from "vitest";

import { createHistorySearch } from "../../../js/lib/chat/history_search.js";

afterEach(() => {
  document.body.innerHTML = "";
});

function setup({ search = () => null } = {}) {
  document.body.innerHTML = `
    <div id="hist-search-panel" class="u-hidden">
      <input class="history-search-input" />
      <div class="history-no-match u-hidden"></div>
    </div>`;
  const input = document.createElement("textarea");
  input.value = "draft";
  document.body.appendChild(input);

  const onClose = vi.fn();
  const resize = vi.fn();
  const hs = createHistorySearch({ input, search, resize, onClose });
  return { hs, input, onClose, resize };
}

const panel = () => document.getElementById("hist-search-panel");
const searchField = () => panel().querySelector(".history-search-input");
const noMatch = () => panel().querySelector(".history-no-match");

describe("createHistorySearch", () => {
  it("opens the panel and remembers the draft", () => {
    const { hs } = setup();
    hs.open();
    expect(hs.active).toBe(true);
    expect(panel().classList.contains("hist-search-panel--open")).toBe(true);
  });

  it("writes a match into the composer and hides no-match", () => {
    const { hs, input, resize } = setup({ search: (q) => (q === "jo" ? "/join" : null) });
    hs.open();
    searchField().value = "jo";
    searchField().dispatchEvent(new Event("input"));

    expect(input.value).toBe("/join");
    expect(resize).toHaveBeenCalled();
    expect(noMatch().classList.contains("u-hidden")).toBe(true);
  });

  it("shows no-match when nothing is found", () => {
    const { hs } = setup({ search: () => null });
    hs.open();
    searchField().value = "zzz";
    searchField().dispatchEvent(new Event("input"));
    expect(noMatch().classList.contains("history-no-match--visible")).toBe(true);
  });

  it("Enter commits the current value", () => {
    const { hs, input, onClose } = setup({ search: () => "/join" });
    hs.open();
    input.value = "/join";
    searchField().dispatchEvent(new KeyboardEvent("keydown", { key: "Enter" }));

    expect(hs.active).toBe(false);
    expect(onClose).toHaveBeenCalledWith("/join");
  });

  it("Escape cancels, restoring the draft", () => {
    const { hs, input, onClose } = setup({ search: () => "/join" });
    hs.open();
    input.value = "/join"; // a match was applied
    searchField().dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }));

    expect(input.value).toBe("draft");
    expect(onClose).toHaveBeenCalledWith("draft");
  });

  it("toggle opens then closes", () => {
    const { hs } = setup();
    hs.toggle();
    expect(hs.active).toBe(true);
    hs.toggle();
    expect(hs.active).toBe(false);
  });

  it("does nothing when the panel is absent", () => {
    document.body.innerHTML = "";
    const input = document.createElement("textarea");
    const hs = createHistorySearch({
      input,
      search: () => null,
      resize: () => {},
      onClose: () => {},
    });
    expect(() => hs.open()).not.toThrow();
    expect(hs.active).toBe(false);
  });
});
