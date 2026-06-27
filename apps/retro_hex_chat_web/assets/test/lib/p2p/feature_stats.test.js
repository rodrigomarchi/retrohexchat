import { describe, it, expect } from "vitest";
import { collectFeatureSnapshot, deriveFeatureStats } from "../../../js/lib/p2p/media.js";

// Build a getStats() Map from a list of report objects.
function statsMap(reports) {
  const map = new Map();
  reports.forEach((r, i) => map.set(r.id || `r${i}`, r));
  return map;
}

function fakePc(reports) {
  return { getStats: async () => statsMap(reports) };
}

describe("collectFeatureSnapshot", () => {
  it("splits RTP streams by kind and data channels by label", async () => {
    const pc = fakePc([
      {
        type: "candidate-pair",
        state: "succeeded",
        currentRoundTripTime: 0.04,
        availableOutgoingBitrate: 1_200_000,
      },
      {
        type: "inbound-rtp",
        kind: "audio",
        bytesReceived: 1000,
        packetsReceived: 50,
        packetsLost: 1,
        jitter: 0.003,
      },
      { type: "outbound-rtp", kind: "audio", bytesSent: 900 },
      {
        type: "inbound-rtp",
        kind: "video",
        bytesReceived: 5000,
        packetsReceived: 200,
        packetsLost: 2,
        jitter: 0.006,
        framesPerSecond: 30,
        frameWidth: 1280,
        frameHeight: 720,
        freezeCount: 1,
      },
      {
        type: "outbound-rtp",
        kind: "video",
        bytesSent: 4000,
        qualityLimitationReason: "bandwidth",
      },
      {
        type: "data-channel",
        label: "gamedata",
        state: "open",
        bytesSent: 300,
        bytesReceived: 200,
        messagesSent: 10,
        messagesReceived: 8,
      },
      {
        type: "data-channel",
        label: "filetransfer",
        state: "closed",
        bytesSent: 0,
        bytesReceived: 0,
      },
    ]);

    const snap = await collectFeatureSnapshot(pc);

    expect(snap.connection.rtt).toBe(0.04);
    expect(snap.audio.active).toBe(true);
    expect(snap.audio.inBytes).toBe(1000);
    expect(snap.video.width).toBe(1280);
    expect(snap.video.limitation).toBe("bandwidth");
    expect(snap.channels.gamedata.state).toBe("open");
    expect(snap.channels.filetransfer.state).toBe("closed");
  });
});

describe("deriveFeatureStats", () => {
  it("is always complete with zeroed sections when idle", () => {
    const curr = {
      timestamp: 1000,
      connection: { rtt: 0, availableOutgoing: 0 },
      audio: {
        active: false,
        inBytes: 0,
        outBytes: 0,
        packetsLost: 0,
        packetsReceived: 0,
        jitter: 0,
      },
      video: {
        active: false,
        inBytes: 0,
        outBytes: 0,
        packetsLost: 0,
        packetsReceived: 0,
        jitter: 0,
        fps: 0,
        width: 0,
        height: 0,
        freezeCount: 0,
        limitation: "none",
      },
      channels: {},
    };

    const stats = deriveFeatureStats(null, curr);

    expect(stats.connection.rtt_ms).toBe(0);
    expect(stats.audio).toEqual({
      active: false,
      in_kbps: 0,
      out_kbps: 0,
      loss_pct: 0,
      jitter_ms: 0,
    });
    expect(stats.game.state).toBe("closed");
    expect(stats.file.state).toBe("closed");
  });

  it("turns byte counters into per-feature kbps rates over the interval", () => {
    const prev = {
      timestamp: 1000,
      connection: { rtt: 0.04, availableOutgoing: 0 },
      audio: {
        active: true,
        inBytes: 0,
        outBytes: 0,
        packetsLost: 0,
        packetsReceived: 0,
        jitter: 0,
      },
      video: {
        active: true,
        inBytes: 0,
        outBytes: 0,
        packetsLost: 0,
        packetsReceived: 0,
        jitter: 0,
        fps: 30,
        width: 1280,
        height: 720,
        freezeCount: 0,
        limitation: "none",
      },
      channels: {
        gamedata: {
          state: "open",
          bytesSent: 0,
          bytesReceived: 0,
          messagesSent: 0,
          messagesReceived: 0,
        },
      },
    };
    // 1 second later, audio received 12500 bytes → 100 kbps.
    const curr = {
      timestamp: 2000,
      connection: { rtt: 0.04, availableOutgoing: 1_200_000 },
      audio: {
        active: true,
        inBytes: 12_500,
        outBytes: 0,
        packetsLost: 0,
        packetsReceived: 100,
        jitter: 0.002,
      },
      video: {
        active: true,
        inBytes: 0,
        outBytes: 0,
        packetsLost: 0,
        packetsReceived: 0,
        jitter: 0,
        fps: 30,
        width: 1280,
        height: 720,
        freezeCount: 0,
        limitation: "none",
      },
      channels: {
        gamedata: {
          state: "open",
          bytesSent: 1250,
          bytesReceived: 0,
          messagesSent: 5,
          messagesReceived: 3,
        },
      },
    };

    const stats = deriveFeatureStats(prev, curr);

    expect(stats.audio.in_kbps).toBe(100);
    expect(stats.connection.rtt_ms).toBe(40);
    expect(stats.connection.available_kbps).toBe(1200);
    expect(stats.game.active).toBe(true);
    expect(stats.game.sent_kbps).toBe(10);
    expect(stats.game.messages).toBe(8);
  });
});
