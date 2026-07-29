import { describe, expect, it } from "vitest";

import {
  deviceLabelMetadata,
  suggestDeviceLabel,
} from "../../../js/lib/connection/device_label_suggestion";

describe("suggestDeviceLabel", () => {
  it("uses stable OS and browser names without version noise", () => {
    expect(
      suggestDeviceLabel({
        browser: "Firefox 152.0",
        os: "macOS 10.15.7",
      }),
    ).toBe("Mac Firefox");
  });

  it("distinguishes touch phone-sized devices", () => {
    expect(
      suggestDeviceLabel({
        browser: "Chrome 150.0",
        os: "Android 14",
        screen: "390x844",
        touch: true,
      }),
    ).toBe("Android Phone Chrome");
  });

  it("distinguishes tablet-sized Android devices", () => {
    expect(
      suggestDeviceLabel({
        browser: "Chrome 150.0",
        os: "Android 14",
        screen: "820x1180",
        touch: true,
      }),
    ).toBe("Android Tablet Chrome");
  });

  it("falls back to a generic terminal label", () => {
    expect(suggestDeviceLabel({})).toBe("Trusted Terminal");
  });
});

describe("deviceLabelMetadata", () => {
  it("returns the metadata fields displayed by the connect hook", () => {
    expect(
      deviceLabelMetadata({
        browser: "Firefox 152.0",
        os: "macOS 10.15.7",
        language: "pt-BR",
        screen: "1512x982",
        color_depth: 24,
        touch: false,
        cores: 8,
        timezone: "America/Sao_Paulo",
      }),
    ).toEqual({
      device_type: "Mac",
      browser: "Firefox 152.0",
      os: "macOS 10.15.7",
      language: "pt-BR",
      screen: "1512x982",
      timezone: "America/Sao_Paulo",
      color_depth: "24 bit",
      cores: "8 cores",
      touch: "No touch",
    });
  });
});
