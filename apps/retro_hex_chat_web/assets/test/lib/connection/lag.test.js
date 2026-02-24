import { describe, it, expect } from "vitest";
import {
  calculateLag,
  classifyLag,
  PING_INTERVAL,
  PING_TIMEOUT,
} from "../../../js/lib/connection/lag.js";

describe("lag", () => {
  describe("calculateLag", () => {
    it("returns the difference between now and clientTime", () => {
      expect(calculateLag(1000, 1045)).toBe(45);
    });

    it("returns 0 when times are equal", () => {
      expect(calculateLag(5000, 5000)).toBe(0);
    });

    it("handles large values", () => {
      const now = Date.now();
      expect(calculateLag(now - 250, now)).toBe(250);
    });
  });

  describe("classifyLag", () => {
    it("returns normal for 0ms", () => {
      expect(classifyLag(0)).toBe("normal");
    });

    it("returns normal for 199ms", () => {
      expect(classifyLag(199)).toBe("normal");
    });

    it("returns warning for 200ms", () => {
      expect(classifyLag(200)).toBe("warning");
    });

    it("returns warning for 499ms", () => {
      expect(classifyLag(499)).toBe("warning");
    });

    it("returns critical for 500ms", () => {
      expect(classifyLag(500)).toBe("critical");
    });

    it("returns critical for 1000ms", () => {
      expect(classifyLag(1000)).toBe("critical");
    });

    it("returns timeout for null", () => {
      expect(classifyLag(null)).toBe("timeout");
    });

    it("returns timeout for undefined", () => {
      expect(classifyLag(undefined)).toBe("timeout");
    });
  });

  describe("constants", () => {
    it("PING_INTERVAL is 30000ms", () => {
      expect(PING_INTERVAL).toBe(30000);
    });

    it("PING_TIMEOUT is 10000ms", () => {
      expect(PING_TIMEOUT).toBe(10000);
    });
  });
});
