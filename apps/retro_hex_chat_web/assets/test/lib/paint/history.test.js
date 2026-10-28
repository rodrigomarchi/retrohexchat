import { describe, expect, it } from "vitest";
import { LIMIT, createHistory, record, redo, undo } from "../../../js/lib/paint/history.js";

describe("the history", () => {
  it("goes back and forward a step, and a new step forgets what was undone", () => {
    let h = record(record(createHistory("a"), "b"), "c");
    h = undo(h);
    expect(h.now).toBe("b");
    expect(redo(h).now).toBe("c");
    h = record(h, "d");
    expect(redo(h).now).toBe("d");
    expect(undo(undo(undo(h))).now).toBe("a");
  });

  it("keeps the same history for the same drawing, and only so many steps back", () => {
    const h = createHistory("a");
    expect(record(h, "a")).toBe(h);
    let long = h;
    for (let i = 0; i < LIMIT + 10; i++) long = record(long, i);
    expect(long.past).toHaveLength(LIMIT);
  });
});
