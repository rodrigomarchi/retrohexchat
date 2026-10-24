import { describe, it, expect, vi } from "vitest";
import { MSG, dispatcher } from "../../../../js/lib/games/core/messages.js";
import { BASE_MSG } from "../../../../js/lib/games/net_protocol.js";

const message = (...values) => new Uint8Array(values).buffer;

describe("messages", () => {
  it("keeps the type bytes every game already sends", () => {
    expect(MSG).toEqual({
      GAME_STATE: 0x80,
      GAME_START: 0x82,
      GAME_END: 0x83,
      GAME_READY: 0x84,
      INPUT_STATE: BASE_MSG.INPUT_STATE,
      INPUT_EDGE: BASE_MSG.INPUT_EDGE,
    });
  });

  describe("dispatcher", () => {
    it("hands a message to the handler for its type", () => {
      const onState = vi.fn();
      const onEnd = vi.fn();
      const dispatch = dispatcher({ [MSG.GAME_STATE]: onState, [MSG.GAME_END]: onEnd });
      const buf = message(MSG.GAME_END, 1);

      expect(dispatch(buf)).toBe(true);
      expect(onEnd).toHaveBeenCalledWith(buf);
      expect(onState).not.toHaveBeenCalled();
    });

    it("ignores a type nobody handles, an empty buffer and anything not binary", () => {
      const dispatch = dispatcher({ [MSG.GAME_STATE]: vi.fn() });
      expect(dispatch(message(0x99))).toBe(false);
      expect(dispatch(new ArrayBuffer(0))).toBe(false);
      expect(dispatch("text")).toBe(false);
    });
  });
});
