import { describe, it, expect } from "vitest";
import { parseBrowser, parseOS, getClientInfo } from "../../../js/lib/connection/client_info";

describe("parseBrowser", () => {
  it("parses Chrome", () => {
    const ua =
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.6099.130 Safari/537.36";
    expect(parseBrowser(ua)).toBe("Chrome 120.0");
  });

  it("parses Firefox", () => {
    const ua = "Mozilla/5.0 (X11; Linux x86_64; rv:121.0) Gecko/20100101 Firefox/121.0";
    expect(parseBrowser(ua)).toBe("Firefox 121.0");
  });

  it("parses Safari", () => {
    const ua =
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_2) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15";
    expect(parseBrowser(ua)).toBe("Safari 17.2");
  });

  it("parses Edge", () => {
    const ua =
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.2210.91";
    expect(parseBrowser(ua)).toBe("Edge 120.0");
  });

  it("parses Opera", () => {
    const ua =
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 OPR/106.0.4998.70";
    expect(parseBrowser(ua)).toBe("Opera 106.0");
  });

  it("returns null for unknown UA", () => {
    expect(parseBrowser("SomeUnknownBot/1.0")).toBeNull();
  });

  it("returns null for null input", () => {
    expect(parseBrowser(null)).toBeNull();
  });

  it("returns null for empty string", () => {
    expect(parseBrowser("")).toBeNull();
  });
});

describe("parseOS", () => {
  it("parses macOS", () => {
    const ua = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_2_1) AppleWebKit/605.1.15";
    expect(parseOS(ua)).toBe("macOS 14.2.1");
  });

  it("parses Windows 10+", () => {
    const ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36";
    expect(parseOS(ua)).toBe("Windows 10+");
  });

  it("parses Windows 7", () => {
    const ua = "Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36";
    expect(parseOS(ua)).toBe("Windows 7");
  });

  it("parses Linux", () => {
    const ua = "Mozilla/5.0 (X11; Linux x86_64; rv:121.0) Gecko/20100101 Firefox/121.0";
    expect(parseOS(ua)).toBe("Linux");
  });

  it("parses Android", () => {
    const ua = "Mozilla/5.0 (Linux; Android 14; SM-S911B) AppleWebKit/537.36";
    expect(parseOS(ua)).toBe("Android 14");
  });

  it("parses iOS", () => {
    const ua = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15";
    expect(parseOS(ua)).toBe("iOS 17.2");
  });

  it("returns null for unknown UA", () => {
    expect(parseOS("SomeUnknownBot/1.0")).toBeNull();
  });

  it("returns null for null input", () => {
    expect(parseOS(null)).toBeNull();
  });
});

describe("getClientInfo", () => {
  it("returns an object with all expected keys", () => {
    const info = getClientInfo();
    expect(info).toHaveProperty("browser");
    expect(info).toHaveProperty("os");
    expect(info).toHaveProperty("language");
    expect(info).toHaveProperty("screen");
    expect(info).toHaveProperty("color_depth");
    expect(info).toHaveProperty("touch");
    expect(info).toHaveProperty("cores");
    expect(info).toHaveProperty("timezone");
  });

  it("returns a string for screen resolution", () => {
    const info = getClientInfo();
    expect(info.screen).toMatch(/^\d+x\d+$/);
  });

  it("returns a boolean for touch", () => {
    const info = getClientInfo();
    expect(typeof info.touch).toBe("boolean");
  });
});
