import { describe, expect, it } from "vitest";

import { mediaErrorMessage, missingDeviceWarning } from "../../../js/lib/p2p/device_errors.js";

// t() falls back to the source string when no catalog is loaded, so the
// assertions read the English source — the mapping is what matters here.
describe("mediaErrorMessage", () => {
  it("maps an explicit permission_denied code", () => {
    expect(mediaErrorMessage({ code: "permission_denied" }, { audio: true, video: true })).toMatch(
      /Permission denied/,
    );
  });

  it("maps permission-style DOMException names", () => {
    for (const name of ["NotAllowedError", "SecurityError"]) {
      expect(mediaErrorMessage({ name }, { audio: true, video: true })).toMatch(
        /Permission denied/,
      );
    }
  });

  it("maps not-found names", () => {
    expect(mediaErrorMessage({ name: "NotFoundError" }, { audio: true, video: true })).toMatch(
      /No matching microphone or camera/,
    );
  });

  it("maps overconstrained names", () => {
    expect(
      mediaErrorMessage({ name: "OverconstrainedError" }, { audio: true, video: true }),
    ).toMatch(/Selected device is unavailable/);
  });

  it("maps in-use names", () => {
    expect(mediaErrorMessage({ name: "NotReadableError" }, { audio: true, video: true })).toMatch(
      /already in use/,
    );
  });

  it("says receive-only when nothing is wanted", () => {
    expect(mediaErrorMessage({ name: "Whatever" }, { audio: false, video: false })).toMatch(
      /receive-only/,
    );
  });

  it("falls back to the error message, then a generic line", () => {
    expect(mediaErrorMessage({ message: "custom boom" }, { audio: true, video: false })).toBe(
      "custom boom",
    );
    expect(mediaErrorMessage(null, { audio: true, video: false })).toMatch(
      /Could not access your microphone or camera/,
    );
  });
});

describe("missingDeviceWarning", () => {
  it("is null when every wanted device is present", () => {
    expect(
      missingDeviceWarning({ audio: true, video: true }, { audioinput: [1], videoinput: [1] }),
    ).toBeNull();
  });

  it("warns about both when both are missing", () => {
    expect(
      missingDeviceWarning({ audio: true, video: true }, { audioinput: [], videoinput: [] }),
    ).toMatch(/microphone or camera/);
  });

  it("warns about just the microphone", () => {
    expect(
      missingDeviceWarning({ audio: true, video: true }, { audioinput: [], videoinput: [1] }),
    ).toMatch(/No microphone found/);
  });

  it("warns about just the camera", () => {
    expect(
      missingDeviceWarning({ audio: true, video: true }, { audioinput: [1], videoinput: [] }),
    ).toMatch(/No camera found/);
  });

  it("ignores a device that is not wanted", () => {
    expect(
      missingDeviceWarning({ audio: false, video: true }, { audioinput: [], videoinput: [1] }),
    ).toBeNull();
  });
});
