import { describe, expect, it } from "vitest";

import { connectionView } from "../../../js/lib/connection/connection_view.js";

describe("connectionView", () => {
  it("shows the disconnected banner and disables the shell", () => {
    const v = connectionView("disconnected");
    expect(v.banner.visible).toBe(true);
    expect(v.banner.variant).toBe("disconnected");
    expect(v.overlay.visible).toBe(false);
    expect(v.shellDisabled).toBe(true);
  });

  it("shows the reconnected banner without disabling the shell", () => {
    const v = connectionView("reconnected");
    expect(v.banner.variant).toBe("reconnected");
    expect(v.shellDisabled).toBe(false);
  });

  it("shows the reconnecting overlay with attempt and countdown", () => {
    const v = connectionView("reconnecting", { attempt: 2, maxAttempts: 5, remaining: 3 });
    expect(v.overlay.visible).toBe(true);
    expect(v.overlay.info).toContain("2");
    expect(v.overlay.info).toContain("5");
    expect(v.overlay.countdown).toContain("3");
    expect(v.overlay.action).toBeTruthy();
    expect(v.shellDisabled).toBe(true);
  });

  it("shows the cancelled overlay", () => {
    const v = connectionView("cancelled");
    expect(v.overlay.visible).toBe(true);
    expect(v.overlay.info).toBe("");
    expect(v.shellDisabled).toBe(true);
  });

  it("shows nothing for connected/connecting", () => {
    for (const state of ["connected", "connecting"]) {
      const v = connectionView(state);
      expect(v.banner.visible).toBe(false);
      expect(v.overlay.visible).toBe(false);
      expect(v.shellDisabled).toBe(false);
    }
  });

  it("disables the shell on failed without a banner or overlay", () => {
    const v = connectionView("failed");
    expect(v.banner.visible).toBe(false);
    expect(v.overlay.visible).toBe(false);
    expect(v.shellDisabled).toBe(true);
  });
});
