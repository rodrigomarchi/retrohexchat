import { describe, expect, it } from "vitest";

import {
  actualMediaState,
  hasLiveTrack,
  mediaStateFromDataset,
  needsOnDemandMedia,
} from "../../../js/lib/group_call/media_state.js";

describe("mediaStateFromDataset", () => {
  it("defaults to enabled and reads an explicit false", () => {
    expect(mediaStateFromDataset({})).toEqual({ audio: true, video: true });
    expect(mediaStateFromDataset({ audio: "false" })).toEqual({ audio: false, video: true });
    expect(mediaStateFromDataset({ video: "false" })).toEqual({ audio: true, video: false });
  });
});

describe("hasLiveTrack", () => {
  it("is false for an empty or missing list", () => {
    expect(hasLiveTrack([])).toBe(false);
    expect(hasLiveTrack(null)).toBe(false);
    expect(hasLiveTrack(undefined)).toBe(false);
  });

  it("is true only when a track is not ended", () => {
    expect(hasLiveTrack([{ readyState: "ended" }])).toBe(false);
    expect(hasLiveTrack([{ readyState: "ended" }, { readyState: "live" }])).toBe(true);
  });
});

describe("needsOnDemandMedia", () => {
  it("needs capture when a wanted track is missing", () => {
    expect(needsOnDemandMedia({ audio: true, video: false }, false, false)).toBe(true);
    expect(needsOnDemandMedia({ audio: false, video: true }, false, false)).toBe(true);
  });

  it("does not need capture when wanted tracks are present or unwanted", () => {
    expect(needsOnDemandMedia({ audio: true, video: false }, true, false)).toBe(false);
    expect(needsOnDemandMedia({ audio: false, video: false }, false, false)).toBe(false);
  });
});

describe("actualMediaState", () => {
  it("narrows the desired state to what the tracks provide", () => {
    expect(actualMediaState({ audio: true, video: true }, true, false)).toEqual({
      audio: true,
      video: false,
    });
    expect(actualMediaState({ audio: false, video: true }, true, true)).toEqual({
      audio: false,
      video: true,
    });
  });
});
