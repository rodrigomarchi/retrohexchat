import { describe, expect, it } from "vitest";

import { withDevice, captureConstraints } from "../../../js/lib/p2p/device_constraints.js";

describe("withDevice", () => {
  it("returns the base unchanged when no device is given", () => {
    const base = { echoCancellation: true };
    expect(withDevice(base, null)).toBe(base);
    expect(withDevice(base, "")).toBe(base);
  });

  it("pins the exact device id when one is given", () => {
    const result = withDevice({ echoCancellation: true }, "mic-1");
    expect(result).toEqual({ echoCancellation: true, deviceId: { exact: "mic-1" } });
  });

  it("does not mutate the base", () => {
    const base = { echoCancellation: true };
    withDevice(base, "mic-1");
    expect(base).toEqual({ echoCancellation: true });
  });
});

describe("captureConstraints", () => {
  it("is false for a disabled track", () => {
    const c = captureConstraints({ audio: false, video: false }, {});
    expect(c.audio).toBe(false);
    expect(c.video).toBe(false);
  });

  it("produces a constraint object for an enabled track", () => {
    const c = captureConstraints({ audio: true, video: false }, {});
    expect(c.audio).toBeTypeOf("object");
    expect(c.video).toBe(false);
  });

  it("pins enabled tracks to their chosen devices", () => {
    const c = captureConstraints(
      { audio: true, video: true },
      { audioInputId: "mic-1", videoInputId: "cam-2" },
    );
    expect(c.audio.deviceId).toEqual({ exact: "mic-1" });
    expect(c.video.deviceId).toEqual({ exact: "cam-2" });
  });

  it("leaves a device unpinned when its id is absent", () => {
    const c = captureConstraints({ audio: true, video: false }, {});
    expect(c.audio.deviceId).toBeUndefined();
  });
});
