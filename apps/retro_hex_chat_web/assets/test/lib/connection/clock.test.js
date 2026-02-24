import { describe, it, expect } from "vitest";
import { formatTime, CLOCK_INTERVAL } from "../../../js/lib/connection/clock.js";

describe("clock", () => {
  describe("formatTime", () => {
    it("formats midnight as 00:00", () => {
      const date = new Date(2026, 0, 1, 0, 0, 0);
      expect(formatTime(date)).toBe("00:00");
    });

    it("formats noon as 12:00", () => {
      const date = new Date(2026, 0, 1, 12, 0, 0);
      expect(formatTime(date)).toBe("12:00");
    });

    it("formats single-digit hours with leading zero", () => {
      const date = new Date(2026, 0, 1, 9, 5, 0);
      expect(formatTime(date)).toBe("09:05");
    });

    it("formats afternoon time", () => {
      const date = new Date(2026, 0, 1, 14, 32, 0);
      expect(formatTime(date)).toBe("14:32");
    });

    it("formats end of day", () => {
      const date = new Date(2026, 0, 1, 23, 59, 0);
      expect(formatTime(date)).toBe("23:59");
    });
  });

  describe("constants", () => {
    it("CLOCK_INTERVAL is 30000ms", () => {
      expect(CLOCK_INTERVAL).toBe(30000);
    });
  });
});
