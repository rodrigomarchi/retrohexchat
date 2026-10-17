import { describe, it, expect } from "vitest";
import {
  frontMember,
  groupsToLayOut,
  lastOpenOfSlot,
  opensAtStart,
  planOpenGroup,
} from "../../../js/lib/window_manager/window_groups";

function member(id, overrides = {}) {
  return { id, open: true, minimized: false, placed: true, z: 0, ...overrides };
}

describe("opening a group", () => {
  it("opens every window, laid out afresh, when none is open", () => {
    const members = [member("a", { open: false }), member("b", { open: false })];
    expect(planOpenGroup(members, "chat")).toEqual({ kind: "open_all", ids: ["a", "b"] });
  });

  it("lays out the open windows of a page that just arrived", () => {
    const members = [
      member("a", { placed: false }),
      member("b", { open: false, placed: false }),
      member("c", { placed: false }),
    ];
    expect(planOpenGroup(members, "chat")).toEqual({ kind: "lay_out", ids: ["a", "c"] });
  });

  it("brings forward the window the reader had in front last, closed ones staying closed", () => {
    const members = [
      member("a", { z: 3 }),
      member("b", { z: 9, open: false }),
      member("c", { z: 5 }),
    ];
    expect(planOpenGroup(members, "chat")).toEqual({ kind: "front", id: "c" });
  });

  it("does nothing when one of its windows is already in front", () => {
    expect(planOpenGroup([member("a"), member("b")], "b")).toEqual({ kind: "none" });
  });

  it("does nothing for a group with no windows", () => {
    expect(planOpenGroup([], "chat")).toEqual({ kind: "none" });
  });
});

describe("the window in front of a group", () => {
  it("is the highest one", () => {
    expect(frontMember([member("a", { z: 2 }), member("b", { z: 7 }), member("c", { z: 4 })])).toBe(
      "b",
    );
  });

  it("is nobody's for no windows", () => {
    expect(frontMember([])).toBeNull();
  });
});

describe("the groups owed a layout", () => {
  it("are those with an open window never placed, each once", () => {
    const windows = [
      { group: "site", open: true, placed: false },
      { group: "site", open: true, placed: false },
      { group: "other", open: false, placed: false },
      { group: "placed", open: true, placed: true },
      { group: null, open: true, placed: false },
    ];
    expect(groupsToLayOut(windows)).toEqual(["site"]);
  });
});

describe("whether a window starts open", () => {
  it("follows its group's root when it has one", () => {
    expect(opensAtStart("false", "true")).toBe(false);
    expect(opensAtStart("true", "false")).toBe(true);
  });

  it("follows itself otherwise", () => {
    expect(opensAtStart(undefined, "false")).toBe(false);
    expect(opensAtStart(undefined, undefined)).toBe(true);
  });
});

describe("the last window of a document", () => {
  it("is closed when no window of its slot is open", () => {
    const windows = [
      { slot: "site", open: true },
      { slot: "site", open: false },
      { slot: "help", open: false },
      { slot: null, open: true },
    ];
    expect(lastOpenOfSlot(windows, "help")).toBe(true);
    expect(lastOpenOfSlot(windows, "site")).toBe(false);

    windows[0].open = false;
    expect(lastOpenOfSlot(windows, "site")).toBe(true);
  });
});
