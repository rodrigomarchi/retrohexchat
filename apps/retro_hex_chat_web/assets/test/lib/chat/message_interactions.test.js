import { describe, it, expect } from "vitest";
import {
  truncatePreview,
  formatEditTimestamp,
  shouldTriggerEditMode,
} from "../../../js/lib/chat/message_interactions";

describe("truncatePreview", () => {
  it("returns text unchanged when under max length", () => {
    expect(truncatePreview("Hello world", 100)).toBe("Hello world");
  });

  it("truncates and adds ellipsis when over max length", () => {
    const long = "a".repeat(150);
    const result = truncatePreview(long, 100);
    expect(result.length).toBe(100);
    expect(result.endsWith("...")).toBe(true);
  });

  it("handles exactly max length", () => {
    const exact = "a".repeat(100);
    expect(truncatePreview(exact, 100)).toBe(exact);
  });

  it("handles empty string", () => {
    expect(truncatePreview("", 100)).toBe("");
  });

  it("defaults to 100 max length", () => {
    const long = "a".repeat(150);
    const result = truncatePreview(long);
    expect(result.length).toBe(100);
  });
});

describe("formatEditTimestamp", () => {
  it("formats datetime as HH:MM DD/MM/YYYY in local time", () => {
    // Use a date constructed with local time components to avoid TZ sensitivity
    const dt = new Date(2026, 1, 16, 14, 30, 0); // Feb 16, 2026 14:30 local
    expect(formatEditTimestamp(dt)).toBe("14:30 16/02/2026");
  });

  it("pads single-digit hours and minutes", () => {
    const dt = new Date(2026, 0, 5, 8, 5, 0); // Jan 5, 2026 08:05 local
    expect(formatEditTimestamp(dt)).toBe("08:05 05/01/2026");
  });
});

describe("shouldTriggerEditMode", () => {
  it("returns true when input is empty", () => {
    expect(shouldTriggerEditMode("")).toBe(true);
  });

  it("returns false when input is not empty", () => {
    expect(shouldTriggerEditMode("some text")).toBe(false);
  });

  it("returns false for whitespace-only input", () => {
    expect(shouldTriggerEditMode("  ")).toBe(false);
  });
});
