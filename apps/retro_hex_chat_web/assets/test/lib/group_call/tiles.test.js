import { describe, expect, it } from "vitest";

import {
  localEmptyState,
  localEmptyStateCopy,
  participantTileMedia,
} from "../../../js/lib/group_call/tiles.js";

describe("localEmptyState", () => {
  it("is screen-share whenever a screen is active", () => {
    expect(
      localEmptyState({ screenShareActive: true, audioEnabled: false, videoEnabled: false }),
    ).toBe("screen-share");
  });

  it("is receive-only when both audio and video are off", () => {
    expect(
      localEmptyState({ screenShareActive: false, audioEnabled: false, videoEnabled: false }),
    ).toBe("receive-only");
  });

  it("is camera-off when only video is off", () => {
    expect(
      localEmptyState({ screenShareActive: false, audioEnabled: true, videoEnabled: false }),
    ).toBe("camera-off");
  });

  it("is starting otherwise", () => {
    expect(
      localEmptyState({ screenShareActive: false, audioEnabled: true, videoEnabled: true }),
    ).toBe("starting");
  });
});

describe("localEmptyStateCopy", () => {
  it("has a title and detail for each known state", () => {
    for (const state of ["screen-share", "receive-only", "camera-off", "starting", "anything"]) {
      const copy = localEmptyStateCopy(state);
      expect(copy.title).toBeTruthy();
      expect(copy.detail).toBeTruthy();
    }
  });

  it("distinguishes the states", () => {
    expect(localEmptyStateCopy("screen-share").title).not.toBe(
      localEmptyStateCopy("camera-off").title,
    );
  });
});

describe("participantTileMedia", () => {
  it("defaults missing media flags to on", () => {
    const m = participantTileMedia({ nickname: "Ana" });
    expect(m.audio).toBe(true);
    expect(m.video).toBe(true);
    expect(m.screen).toBe(false);
    expect(m.name).toBe("Ana");
    expect(m.label).toBe("Focus Ana");
  });

  it("reads explicit false flags", () => {
    const m = participantTileMedia({
      nickname: "Ana",
      media_state: { audio: false, video: false },
    });
    expect(m.audio).toBe(false);
    expect(m.video).toBe(false);
  });

  it("treats a screen media flag as a shared screen", () => {
    const m = participantTileMedia({ nickname: "Ana", media_state: { screen: true } });
    expect(m.screen).toBe(true);
    expect(m.name).toContain("Ana");
    expect(m.label).toBe("Focus Ana's shared screen");
  });

  it("treats a screen track source as a shared screen", () => {
    const m = participantTileMedia({ nickname: "Ana" }, "screen");
    expect(m.screen).toBe(true);
  });

  it("falls back to a generic name when there is no nickname", () => {
    const m = participantTileMedia({});
    expect(m.name).toBeTruthy();
    expect(m.label).toContain("Focus");
  });
});
