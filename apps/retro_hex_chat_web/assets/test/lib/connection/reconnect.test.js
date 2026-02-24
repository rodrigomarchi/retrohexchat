import { getBackoffDelay, RECONNECT_DEFAULTS } from "../../../js/lib/connection/reconnect.js";

describe("lib/reconnect", () => {
  describe("getBackoffDelay", () => {
    it("returns 1 for attempt 1", () => {
      expect(getBackoffDelay(1)).toBe(1);
    });

    it("returns 2 for attempt 2", () => {
      expect(getBackoffDelay(2)).toBe(2);
    });

    it("returns 4 for attempt 3", () => {
      expect(getBackoffDelay(3)).toBe(4);
    });

    it("returns 8 for attempt 4", () => {
      expect(getBackoffDelay(4)).toBe(8);
    });

    it("caps at default maxDelay (30)", () => {
      expect(getBackoffDelay(20)).toBe(30);
    });

    it("caps at custom maxDelay", () => {
      expect(getBackoffDelay(10, 10)).toBe(10);
    });
  });

  describe("RECONNECT_DEFAULTS", () => {
    it("has maxAttempts", () => {
      expect(RECONNECT_DEFAULTS.maxAttempts).toBe(10);
    });

    it("has maxDelay", () => {
      expect(RECONNECT_DEFAULTS.maxDelay).toBe(30);
    });
  });
});
