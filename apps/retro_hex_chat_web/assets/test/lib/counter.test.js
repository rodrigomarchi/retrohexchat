import { getCounterState } from "../../js/lib/counter.js";

describe("getCounterState", () => {
  it("returns normal severity for short text", () => {
    const state = getCounterState(100, 1000);
    expect(state).toEqual({ text: "100/1000", severity: "normal" });
  });

  it("returns warning severity above warning threshold", () => {
    const state = getCounterState(500, 1000);
    expect(state.severity).toBe("warning");
  });

  it("returns danger severity above danger threshold", () => {
    const state = getCounterState(950, 1000);
    expect(state.severity).toBe("danger");
  });

  it("returns normal at exactly warning threshold", () => {
    const state = getCounterState(450, 1000);
    expect(state.severity).toBe("normal");
  });

  it("returns warning at exactly danger threshold", () => {
    // 900 is not > 900, so it's still warning
    const state = getCounterState(900, 1000);
    expect(state.severity).toBe("warning");
  });

  it("formats text as length/max", () => {
    expect(getCounterState(0, 500).text).toBe("0/500");
  });

  it("supports custom thresholds", () => {
    const state = getCounterState(50, 100, { warning: 30, danger: 80 });
    expect(state.severity).toBe("warning");
  });

  it("uses custom danger threshold", () => {
    const state = getCounterState(85, 100, { warning: 30, danger: 80 });
    expect(state.severity).toBe("danger");
  });

  it("returns normal for empty input", () => {
    expect(getCounterState(0, 1000).severity).toBe("normal");
  });
});
