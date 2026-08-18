import { describe, expect, it } from "vitest";

import {
  collectQualitySnapshot,
  deriveParticipantQuality,
  participantQualityLabel,
  participantQualityLevel,
  participantQualityTitle,
} from "../../../js/lib/group_call/quality.js";

describe("participantQualityLevel", () => {
  it("is reconnecting for a non-connected state regardless of stats", () => {
    for (const connectionState of ["connecting", "disconnected", "failed"]) {
      expect(
        participantQualityLevel({
          connectionState,
          rttMs: 0,
          jitterMs: 0,
          lossPct: 0,
          freezeDelta: 0,
        }),
      ).toBe("reconnecting");
    }
  });

  it("grades poor / fair / good / excellent by the worst metric", () => {
    const at = (over) =>
      participantQualityLevel({
        connectionState: "connected",
        rttMs: 0,
        jitterMs: 0,
        lossPct: 0,
        freezeDelta: 0,
        ...over,
      });
    expect(at({ lossPct: 8 })).toBe("poor");
    expect(at({ rttMs: 400 })).toBe("poor");
    expect(at({ lossPct: 3 })).toBe("fair");
    expect(at({ freezeDelta: 1 })).toBe("fair");
    expect(at({ rttMs: 120 })).toBe("good");
    expect(at({})).toBe("excellent");
  });
});

describe("participantQualityLabel", () => {
  it("maps known levels and falls back to Unknown", () => {
    expect(participantQualityLabel("excellent")).toBe("Excellent");
    expect(participantQualityLabel("reconnecting")).toBe("Reconnecting");
    expect(participantQualityLabel("bogus")).toBe("Unknown");
  });
});

describe("participantQualityTitle", () => {
  it("is empty without a quality", () => {
    expect(participantQualityTitle(null)).toBe("");
  });

  it("formats the metrics line", () => {
    const title = participantQualityTitle({
      label: "Good",
      rtt_ms: 90,
      loss_pct: 1.2,
      bitrate_kbps: 800,
      fps: 30,
    });
    expect(title).toBe("Good: RTT 90 ms, loss 1.2%, 800 kbps, 30 fps");
  });
});

describe("collectQualitySnapshot", () => {
  const resolve = (report) => report.pid || null;

  it("keeps only inbound-rtp audio/video reports", () => {
    const snap = collectQualitySnapshot(
      [
        { type: "outbound-rtp", kind: "audio", pid: "p1" },
        { type: "inbound-rtp", kind: "data", pid: "p1" },
        { type: "inbound-rtp", kind: "audio", pid: "p1", bytesReceived: 10 },
      ],
      resolve,
      1000,
    );
    expect(snap.timestamp).toBe(1000);
    expect(snap.participants.get("p1").bytesReceived).toBe(10);
  });

  it("skips reports that resolve to no participant", () => {
    const snap = collectQualitySnapshot([{ type: "inbound-rtp", kind: "audio" }], () => null, 1);
    expect(snap.participants.size).toBe(0);
  });

  it("accumulates audio and video metrics per participant", () => {
    const snap = collectQualitySnapshot(
      [
        { type: "inbound-rtp", kind: "audio", pid: "p1", audioLevel: 0.5, jitter: 0.01 },
        { type: "inbound-rtp", kind: "video", pid: "p1", framesPerSecond: 30, freezeCount: 2 },
      ],
      resolve,
      1,
    );
    const p = snap.participants.get("p1");
    expect(p.audioLevel).toBe(0.5);
    expect(p.fps).toBe(30);
    expect(p.freezeCount).toBe(2);
  });
});

describe("deriveParticipantQuality", () => {
  it("differences byte and packet counts against the previous snapshot", () => {
    const prev = {
      timestamp: 0,
      participants: new Map([
        [
          "p1",
          {
            bytesReceived: 0,
            packetsLost: 0,
            packetsReceived: 100,
            jitter: 0,
            audioLevel: 0,
            fps: 0,
            freezeCount: 0,
          },
        ],
      ]),
    };
    const snapshot = {
      timestamp: 1000,
      participants: new Map([
        [
          "p1",
          {
            bytesReceived: 125000,
            packetsLost: 5,
            packetsReceived: 195,
            jitter: 0,
            audioLevel: 0,
            fps: 30,
            freezeCount: 0,
          },
        ],
      ]),
    };
    const result = deriveParticipantQuality(snapshot, prev, {
      connectionState: "connected",
      now: 42,
    });
    const p = result.participants[0];
    expect(p.bitrate_kbps).toBe(1000);
    expect(p.loss_pct).toBe(5);
    expect(result.updated_at_ms).toBe(42);
  });

  it("picks the loudest speaker above the threshold as active", () => {
    const snapshot = {
      timestamp: 1,
      participants: new Map([
        [
          "quiet",
          {
            bytesReceived: 0,
            packetsLost: 0,
            packetsReceived: 0,
            jitter: 0,
            audioLevel: 0.01,
            fps: 0,
            freezeCount: 0,
          },
        ],
        [
          "loud",
          {
            bytesReceived: 0,
            packetsLost: 0,
            packetsReceived: 0,
            jitter: 0,
            audioLevel: 0.4,
            fps: 0,
            freezeCount: 0,
          },
        ],
      ]),
    };
    const result = deriveParticipantQuality(snapshot, null, {
      connectionState: "connected",
      now: 0,
    });
    expect(result.active_speaker_participant_id).toBe("loud");
  });

  it("has no active speaker when everyone is below the threshold", () => {
    const snapshot = {
      timestamp: 1,
      participants: new Map([
        [
          "p1",
          {
            bytesReceived: 0,
            packetsLost: 0,
            packetsReceived: 0,
            jitter: 0,
            audioLevel: 0.01,
            fps: 0,
            freezeCount: 0,
          },
        ],
      ]),
    };
    const result = deriveParticipantQuality(snapshot, null, {
      connectionState: "connected",
      now: 0,
    });
    expect(result.active_speaker_participant_id).toBeNull();
  });
});
