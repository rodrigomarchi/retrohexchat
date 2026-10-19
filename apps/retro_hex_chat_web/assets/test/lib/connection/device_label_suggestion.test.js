import { describe, expect, it } from "vitest";

import { suggestDeviceLabel } from "../../../js/lib/connection/device_label_suggestion";

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
