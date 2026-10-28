import { describe, expect, it } from "vitest";
import { EVENT, feedback } from "../../../../../js/lib/games/core/card_table/events.js";

describe("the table's feedback", () => {
  it("raises the event of a refused card or a drag put back, and keeps any other action's state", () => {
    const state = { events: EVENT.DRAW, table: {} };
    expect(feedback(state, { type: "refuse" })).toEqual({
      ...state,
      events: EVENT.DRAW | EVENT.REFUSE,
    });
    expect(feedback(state, { type: "return" })).toEqual({
      ...state,
      events: EVENT.DRAW | EVENT.RETURN,
    });
    expect(feedback(state, { type: "nonsense" })).toBe(state);
  });
});
