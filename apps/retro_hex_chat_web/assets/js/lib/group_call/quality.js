/**
 * Per-participant call-quality derivation for the conference — pure, no DOM.
 *
 * The hook samples getStats and resolves a report to a participant (which needs
 * the tiles, so that stays in the hook); everything downstream — accumulating a
 * snapshot, differencing it against the previous one, and grading the result —
 * is decided here against plain numbers.
 *
 * The quality labels are kept as their English source strings, unchanged from
 * the hook; translating them is a separate change, not part of moving the code.
 *
 * @module group_call/quality
 */

const SPEAKING_THRESHOLD = 0.03;

/**
 * Grade a participant's link from its recent stats.
 *
 * @param {object} params
 * @param {string} params.connectionState
 * @param {number} params.rttMs
 * @param {number} params.jitterMs
 * @param {number} params.lossPct
 * @param {number} params.freezeDelta
 * @returns {"reconnecting"|"poor"|"fair"|"good"|"excellent"}
 */
export function participantQualityLevel({
  connectionState,
  rttMs,
  jitterMs,
  lossPct,
  freezeDelta,
}) {
  if (["connecting", "disconnected", "failed"].includes(connectionState)) {
    return "reconnecting";
  }

  if (lossPct >= 8 || rttMs >= 400 || jitterMs >= 80) return "poor";
  if (lossPct >= 3 || rttMs >= 250 || jitterMs >= 50 || freezeDelta > 0) return "fair";
  if (lossPct >= 1 || rttMs >= 120 || jitterMs >= 30) return "good";
  return "excellent";
}

/** The human label for a quality level. */
export function participantQualityLabel(level) {
  return (
    {
      excellent: "Excellent",
      good: "Good",
      fair: "Fair",
      poor: "Poor",
      reconnecting: "Reconnecting",
      unknown: "Unknown",
    }[level] || "Unknown"
  );
}

/** The tooltip line for a graded participant. */
export function participantQualityTitle(quality) {
  if (!quality) return "";
  return `${quality.label}: RTT ${quality.rtt_ms} ms, loss ${quality.loss_pct}%, ${quality.bitrate_kbps} kbps, ${quality.fps} fps`;
}

function ensureParticipantStats(snapshot, participantId) {
  const id = String(participantId);

  if (!snapshot.participants.has(id)) {
    snapshot.participants.set(id, {
      participant_id: id,
      bytesReceived: 0,
      packetsLost: 0,
      packetsReceived: 0,
      jitter: 0,
      audioLevel: 0,
      fps: 0,
      freezeCount: 0,
    });
  }

  return snapshot.participants.get(id);
}

/**
 * Accumulate an inbound-rtp stats report set into a per-participant snapshot.
 *
 * @param {Iterable<object>|null|undefined} reports getStats results
 * @param {(report: object) => string|null} resolveParticipantId maps a report
 *   to a participant id (needs the DOM, so the caller provides it)
 * @param {number} now snapshot timestamp
 * @returns {{timestamp: number, participants: Map<string, object>}}
 */
export function collectQualitySnapshot(reports, resolveParticipantId, now) {
  const snapshot = { timestamp: now, participants: new Map() };

  reports?.forEach?.((report) => {
    if (report?.type !== "inbound-rtp") return;

    const kind = report.kind || report.mediaType;
    if (kind !== "audio" && kind !== "video") return;

    const participantId = resolveParticipantId(report);
    if (!participantId) return;

    const current = ensureParticipantStats(snapshot, participantId);
    current.bytesReceived += report.bytesReceived || 0;
    current.packetsLost += report.packetsLost || 0;
    current.packetsReceived += report.packetsReceived || 0;

    if (typeof report.jitter === "number") {
      current.jitter = Math.max(current.jitter, report.jitter);
    }

    if (kind === "audio") {
      current.audioLevel = Math.max(current.audioLevel, report.audioLevel || 0);
    }

    if (kind === "video") {
      current.fps = Math.max(current.fps, report.framesPerSecond || 0);
      current.freezeCount = Math.max(current.freezeCount, report.freezeCount || 0);
    }
  });

  return snapshot;
}

/**
 * Difference a snapshot against the previous one into graded per-participant
 * quality, and pick the active speaker.
 *
 * @param {{timestamp: number, participants: Map<string, object>}} snapshot
 * @param {{timestamp: number, participants: Map<string, object>}|null} previous
 * @param {object} context
 * @param {{rtt_ms?: number}} [context.connectionStats]
 * @param {string} context.connectionState
 * @param {number} context.now
 * @returns {{active_speaker_participant_id: string|null, participants: object[], updated_at_ms: number}}
 */
export function deriveParticipantQuality(
  snapshot,
  previous,
  { connectionStats = {}, connectionState, now },
) {
  const participants = [];
  let activeSpeakerParticipantId = null;
  let loudestAudioLevel = SPEAKING_THRESHOLD;

  for (const [participantId, current] of snapshot.participants) {
    const prev = previous?.participants?.get(participantId) || null;
    const intervalSec = prev
      ? Math.max((snapshot.timestamp - previous.timestamp) / 1000, 0.001)
      : 1;
    const bytesDelta = prev ? Math.max(0, current.bytesReceived - prev.bytesReceived) : 0;
    const lostDelta = prev ? Math.max(0, current.packetsLost - prev.packetsLost) : 0;
    const receivedDelta = prev ? Math.max(0, current.packetsReceived - prev.packetsReceived) : 0;
    const totalPacketDelta = lostDelta + receivedDelta;
    const lossPct =
      totalPacketDelta > 0 ? Math.round((lostDelta / totalPacketDelta) * 1000) / 10 : 0;
    const bitrateKbps = Math.round((bytesDelta * 8) / intervalSec / 1000);
    const jitterMs = Math.round((current.jitter || 0) * 1000);
    const rttMs = connectionStats.rtt_ms || 0;
    const freezeDelta = prev ? Math.max(0, current.freezeCount - prev.freezeCount) : 0;
    const fps = Math.round(current.fps || 0);
    const audioLevel = Math.round((current.audioLevel || 0) * 1000) / 1000;
    const speaking = audioLevel >= SPEAKING_THRESHOLD;
    const level = participantQualityLevel({
      connectionState,
      rttMs,
      jitterMs,
      lossPct,
      freezeDelta,
    });

    if (speaking && audioLevel > loudestAudioLevel) {
      loudestAudioLevel = audioLevel;
      activeSpeakerParticipantId = participantId;
    }

    participants.push({
      participant_id: participantId,
      level,
      label: participantQualityLabel(level),
      speaking,
      rtt_ms: rttMs,
      jitter_ms: jitterMs,
      loss_pct: lossPct,
      bitrate_kbps: bitrateKbps,
      fps,
      freeze_count: current.freezeCount,
      audio_level: audioLevel,
    });
  }

  return {
    active_speaker_participant_id: activeSpeakerParticipantId,
    participants,
    updated_at_ms: now,
  };
}
