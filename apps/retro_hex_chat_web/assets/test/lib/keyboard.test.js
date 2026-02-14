import { classifyInputKey } from "../../js/lib/keyboard.js";

describe("classifyInputKey", () => {
  it("classifies ArrowUp as history_up", () => {
    expect(classifyInputKey("ArrowUp")).toBe("history_up");
  });

  it("classifies ArrowDown as history_down", () => {
    expect(classifyInputKey("ArrowDown")).toBe("history_down");
  });

  it("classifies Tab as tab_complete", () => {
    expect(classifyInputKey("Tab")).toBe("tab_complete");
  });

  it("returns null for Enter", () => {
    expect(classifyInputKey("Enter")).toBeNull();
  });

  it("returns null for regular characters", () => {
    expect(classifyInputKey("a")).toBeNull();
    expect(classifyInputKey("1")).toBeNull();
  });

  it("returns null for Escape", () => {
    expect(classifyInputKey("Escape")).toBeNull();
  });

  it("returns null for modifier keys", () => {
    expect(classifyInputKey("Shift")).toBeNull();
    expect(classifyInputKey("Control")).toBeNull();
  });
});
