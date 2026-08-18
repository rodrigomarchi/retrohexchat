import { describe, expect, it } from "vitest";

import { INTENT, resolveComposerKey } from "../../../js/lib/chat/composer.js";

const baseState = {
  historySearchActive: false,
  editMode: false,
  dropdownVisible: false,
  hasNavigated: false,
  isTyping: false,
  tooltipVisible: false,
  tabCycleActive: false,
  value: "",
};
const state = (over) => ({ ...baseState, ...over });
const key = (k, mods = {}) => ({ key: k, ...mods });

const pushes = (intents) => intents.filter((i) => i.type === INTENT.PUSH).map((i) => i.event);
const actions = (intents) => intents.filter((i) => i.type === INTENT.ACTION).map((i) => i.name);
const has = (intents, type) => intents.some((i) => i.type === type);

describe("resolveComposerKey — Escape", () => {
  it("closes reverse history search first", () => {
    const intents = resolveComposerKey(key("Escape"), state({ historySearchActive: true }));
    expect(actions(intents)).toContain("closeHistorySearch");
    expect(has(intents, INTENT.STOP_PROPAGATION)).toBe(true);
  });

  it("cancels edit mode next", () => {
    const intents = resolveComposerKey(key("Escape"), state({ editMode: true }));
    expect(pushes(intents)).toContain("cancel_edit");
  });

  it("closes the dropdown, then the tooltip", () => {
    expect(pushes(resolveComposerKey(key("Escape"), state({ dropdownVisible: true })))).toContain(
      "autocomplete_close",
    );
    expect(pushes(resolveComposerKey(key("Escape"), state({ tooltipVisible: true })))).toContain(
      "syntax_tooltip_dismiss",
    );
  });

  it("does nothing when nothing is open", () => {
    expect(resolveComposerKey(key("Escape"), state())).toEqual([]);
  });
});

describe("resolveComposerKey — Enter", () => {
  it("shift+enter is left alone", () => {
    expect(resolveComposerKey(key("Enter", { shiftKey: true }), state())).toEqual([]);
  });

  it("selects the highlighted completion when navigated", () => {
    const intents = resolveComposerKey(
      key("Enter"),
      state({ dropdownVisible: true, hasNavigated: true }),
    );
    expect(pushes(intents)).toContain("autocomplete_select_current");
    expect(actions(intents)).not.toContain("submitForm");
  });

  it("submits, remembering input and stopping typing", () => {
    const intents = resolveComposerKey(key("Enter"), state({ isTyping: true }));
    expect(actions(intents)).toContain("stopTyping");
    expect(actions(intents)).toContain("rememberSubmittedInput");
    expect(actions(intents)).toContain("submitForm");
  });
});

describe("resolveComposerKey — history and arrows", () => {
  it("Ctrl+R toggles reverse search", () => {
    expect(actions(resolveComposerKey(key("r", { ctrlKey: true }), state()))).toContain(
      "toggleHistorySearch",
    );
  });

  it("Ctrl+Arrow drives draft-preserving history", () => {
    expect(actions(resolveComposerKey(key("ArrowUp", { ctrlKey: true }), state()))).toContain(
      "historyUp",
    );
    expect(actions(resolveComposerKey(key("ArrowDown", { ctrlKey: true }), state()))).toContain(
      "historyDown",
    );
  });

  it("ArrowUp navigates the dropdown when open", () => {
    const intents = resolveComposerKey(key("ArrowUp"), state({ dropdownVisible: true }));
    expect(pushes(intents)).toContain("autocomplete_navigate");
  });

  it("ArrowUp on an empty input edits the last message", () => {
    expect(pushes(resolveComposerKey(key("ArrowUp"), state({ value: "" })))).toContain(
      "edit_last_message",
    );
  });

  it("ArrowUp with text navigates history", () => {
    expect(pushes(resolveComposerKey(key("ArrowUp"), state({ value: "hi" })))).toContain(
      "history_navigate",
    );
  });

  it("ArrowDown never edits, always navigates history when the dropdown is closed", () => {
    expect(pushes(resolveComposerKey(key("ArrowDown"), state({ value: "" })))).toContain(
      "history_navigate",
    );
  });
});

describe("resolveComposerKey — Tab", () => {
  it("selects the current completion when the dropdown is open", () => {
    expect(pushes(resolveComposerKey(key("Tab"), state({ dropdownVisible: true })))).toContain(
      "autocomplete_select_current",
    );
  });

  it("cycles through matches when a cycle is active", () => {
    expect(actions(resolveComposerKey(key("Tab"), state({ tabCycleActive: true })))).toContain(
      "tabCycle",
    );
  });

  it("otherwise asks the server to complete", () => {
    const intents = resolveComposerKey(key("Tab"), state({ value: "/jo" }));
    const push = intents.find((i) => i.type === INTENT.PUSH);
    expect(push.event).toBe("tab_complete");
    expect(push.payload).toEqual({ partial: "/jo", is_start: true });
  });
});

describe("resolveComposerKey — IRC formatting", () => {
  it("inserts a format code for a mapped Ctrl+Shift+letter", () => {
    const intents = resolveComposerKey(key("b", { ctrlKey: true, shiftKey: true }), state());
    expect(actions(intents)).toContain("insertAtCursor");
  });

  it("ignores an unmapped Ctrl+Shift key", () => {
    expect(resolveComposerKey(key("q", { ctrlKey: true, shiftKey: true }), state())).toEqual([]);
  });
});
