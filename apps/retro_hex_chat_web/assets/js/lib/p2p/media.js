import { t, jt } from "../i18n.js";
/**
 * Media management for audio/video calls — pure logic, no DOM or LiveView dependencies.
 * @module media
 */

/**
 * Quality level labels.
 */
export const QUALITY_LABELS = {
  excellent: t("Excellent"),
  good: t("Good"),
  fair: t("Fair"),
  poor: t("Poor"),
};

export const DEFAULT_MEDIA_PROFILE = "stable";
export const SCREEN_MEDIA_PROFILE = "screen";

export const MEDIA_PROFILES = {
  stable: {
    audio: {
      echoCancellation: true,
      noiseSuppression: true,
      autoGainControl: true,
      channelCount: { ideal: 1 },
    },
    camera: {
      width: { ideal: 640 },
      height: { ideal: 360 },
      frameRate: { ideal: 15, max: 15 },
      facingMode: "user",
    },
    send: {
      audioBitrate: 40_000,
      videoBitrate: 400_000,
      maxFramerate: 15,
    },
    hints: {
      audio: "speech",
      video: "motion",
    },
  },
  low: {
    camera: {
      width: { ideal: 480 },
      height: { ideal: 270 },
      frameRate: { ideal: 15, max: 15 },
      facingMode: "user",
    },
    send: {
      audioBitrate: 32_000,
      videoBitrate: 250_000,
      maxFramerate: 15,
    },
  },
  high: {
    camera: {
      width: { ideal: 640 },
      height: { ideal: 360 },
      frameRate: { ideal: 24, max: 30 },
      facingMode: "user",
    },
    send: {
      audioBitrate: 64_000,
      videoBitrate: 700_000,
      maxFramerate: 30,
    },
  },
  screen: {
    display: {
      width: { max: 1280 },
      height: { max: 720 },
      frameRate: { ideal: 5, max: 10 },
    },
    send: {
      videoBitrate: 800_000,
      maxFramerate: 10,
    },
    hints: {
      video: "detail",
    },
  },
};

/**
 * Bitrate presets retained for internal events. User-facing quality switching is
 * currently hidden; calls start with the stable profile automatically.
 */
export const BITRATE_PRESETS = {
  high: { video: 700_000, audio: 64_000 },
  medium: { video: 400_000, audio: 40_000 },
  low: { video: 250_000, audio: 32_000 },
};

// --- Media Acquisition ---

function mediaProfile(profileName = DEFAULT_MEDIA_PROFILE) {
  return MEDIA_PROFILES[profileName] || MEDIA_PROFILES[DEFAULT_MEDIA_PROFILE];
}

function cloneConstraintValue(value) {
  if (!value || typeof value !== "object") return value;
  if (Array.isArray(value)) return value.map(cloneConstraintValue);

  return Object.fromEntries(
    Object.entries(value).map(([key, child]) => [key, cloneConstraintValue(child)]),
  );
}

function cloneConstraints(constraints) {
  return cloneConstraintValue(constraints);
}

/**
 * Stable audio constraints for voice calls.
 * @returns {MediaTrackConstraints}
 */
export function getAudioConstraints(deviceId = "", profileName = DEFAULT_MEDIA_PROFILE) {
  const profile = mediaProfile(profileName);
  const constraints = {
    ...cloneConstraints(MEDIA_PROFILES.stable.audio),
    ...cloneConstraints(profile.audio || {}),
  };
  return deviceId ? { ...constraints, deviceId: { exact: deviceId } } : constraints;
}

/**
 * Stable camera constraints for calls.
 * @returns {MediaTrackConstraints}
 */
export function getVideoConstraints(deviceId = "", profileName = DEFAULT_MEDIA_PROFILE) {
  const profile = mediaProfile(profileName);
  const constraints = cloneConstraints(profile.camera || MEDIA_PROFILES.stable.camera);
  return deviceId ? { ...constraints, deviceId: { exact: deviceId } } : constraints;
}

/**
 * Stable display capture constraints for screen sharing.
 * @returns {DisplayMediaStreamOptions}
 */
export function getScreenShareConstraints(profileName = SCREEN_MEDIA_PROFILE) {
  const profile = mediaProfile(profileName);
  return {
    video: cloneConstraints(profile.display || MEDIA_PROFILES.screen.display),
    audio: false,
  };
}

/**
 * Categorize a getUserMedia error into a user-friendly message.
 * @param {Error} error
 * @param {MediaStreamConstraints} constraints
 * @returns {{ code: string, message: string }}
 */
export function categorizeMediaError(error, constraints = {}) {
  const needsVideo = Boolean(constraints.video);
  const needsAudio = Boolean(constraints.audio);

  switch (error.name) {
    case "NotAllowedError":
      return {
        code: "permission_denied",
        message: needsVideo
          ? t("Camera permission denied. Enable camera permission in your browser and try again.")
          : t(
              "Microphone permission denied. Enable microphone permission in your browser and try again.",
            ),
      };
    case "NotReadableError":
      return {
        code: "not_readable",
        message:
          needsAudio && !needsVideo
            ? t(
                "Microphone in use by another application. Try closing other programs using the microphone.",
              )
            : t(
                "Camera in use by another application. Try closing other programs using the camera.",
              ),
      };
    case "NotFoundError":
      return {
        code: "not_found",
        message: needsAudio && !needsVideo ? t("No microphone found.") : t("No camera found."),
      };
    default:
      return {
        code: "unknown",
        message: jt`Error accessing media: ${error.message}`,
      };
  }
}

/**
 * Request user media with error categorization.
 * @param {MediaStreamConstraints} constraints
 * @returns {Promise<MediaStream>}
 */
export async function acquireMedia(constraints) {
  try {
    const stream = await navigator.mediaDevices.getUserMedia(constraints);
    applyTrackHints(stream);
    return stream;
  } catch (error) {
    throw categorizeMediaError(error, constraints);
  }
}

/**
 * Request a display capture stream for screen sharing.
 * @param {DisplayMediaStreamOptions} constraints
 * @returns {Promise<MediaStream>}
 */
export async function acquireDisplayMedia(constraints = getScreenShareConstraints()) {
  if (!navigator.mediaDevices?.getDisplayMedia) {
    throw {
      code: "screen_unsupported",
      message: t("Screen sharing is not supported by this browser."),
    };
  }

  try {
    const stream = await navigator.mediaDevices.getDisplayMedia(constraints);
    applyTrackHints(stream, SCREEN_MEDIA_PROFILE);
    return stream;
  } catch (error) {
    if (error?.name === "OverconstrainedError" && constraints?.video !== true) {
      try {
        const stream = await navigator.mediaDevices.getDisplayMedia({ video: true, audio: false });
        applyTrackHints(stream, SCREEN_MEDIA_PROFILE);
        return stream;
      } catch {
        // Fall through to the user-facing error below.
      }
    }

    throw {
      code: "screen_denied",
      message: t("Screen sharing was cancelled or denied."),
    };
  }
}

// --- Track Management ---

/**
 * Add all tracks from a stream to the peer connection.
 * @param {RTCPeerConnection} pc
 * @param {MediaStream} stream
 * @returns {RTCRtpSender[]}
 */
export function addMediaTracks(pc, stream) {
  applyTrackHints(stream);
  return stream.getTracks().map((track) => pc.addTrack(track, stream));
}

/**
 * Remove tracks from the peer connection.
 * @param {RTCPeerConnection} pc
 * @param {RTCRtpSender[]} senders
 */
export function removeMediaTracks(pc, senders) {
  senders.forEach((sender) => pc.removeTrack(sender));
}

/**
 * Enable or disable a track by kind.
 * @param {MediaStream} stream
 * @param {"audio"|"video"} kind
 * @param {boolean} enabled
 * @returns {boolean} new enabled state
 */
export function toggleTrack(stream, kind, enabled) {
  const tracks = kind === "audio" ? stream.getAudioTracks() : stream.getVideoTracks();
  tracks.forEach((track) => {
    track.enabled = enabled;
  });
  return enabled;
}

/**
 * Replace a track on an RTP sender.
 * @param {RTCRtpSender} sender
 * @param {MediaStreamTrack} newTrack
 * @returns {Promise<void>}
 */
export async function replaceTrack(sender, newTrack) {
  await sender.replaceTrack(newTrack);
}

/**
 * Stop all tracks in a stream.
 * @param {MediaStream} stream
 */
export function stopAllTracks(stream) {
  stream.getTracks().forEach((track) => track.stop());
}

// --- Call Timer ---

/**
 * Format elapsed time as HH:MM:SS.
 * @param {number} startTime - Date.now() when call started
 * @returns {string}
 */
export function formatDuration(startTime) {
  const elapsed = Math.floor((Date.now() - startTime) / 1000);
  const hours = Math.floor(elapsed / 3600);
  const minutes = Math.floor((elapsed % 3600) / 60);
  const seconds = elapsed % 60;
  return [hours, minutes, seconds].map((n) => String(n).padStart(2, "0")).join(":");
}

// --- Device Management ---

/**
 * Enumerate available media devices grouped by kind.
 * @returns {Promise<{audioinput: MediaDeviceInfo[], audiooutput: MediaDeviceInfo[], videoinput: MediaDeviceInfo[]}>}
 */
export async function enumerateDevices() {
  const devices = await navigator.mediaDevices.enumerateDevices();
  return {
    audioinput: devices.filter((d) => d.kind === "audioinput"),
    audiooutput: devices.filter((d) => d.kind === "audiooutput"),
    videoinput: devices.filter((d) => d.kind === "videoinput"),
  };
}

/**
 * Switch to a different microphone without interrupting the call.
 * @param {MediaStream} stream
 * @param {RTCRtpSender[]} senders
 * @param {string} deviceId
 * @returns {Promise<MediaStream>}
 */
export async function switchAudioInput(stream, senders, deviceId) {
  const newStream = await navigator.mediaDevices.getUserMedia({
    audio: getAudioConstraints(deviceId),
  });
  applyTrackHints(newStream);
  const newTrack = newStream.getAudioTracks()[0];
  const audioSender = senders.find((s) => s.track && s.track.kind === "audio");
  if (audioSender) {
    await replaceTrack(audioSender, newTrack);
    await applySenderProfile(audioSender);
  }
  // Stop old audio track
  stream.getAudioTracks().forEach((t) => t.stop());
  stream.getAudioTracks().forEach((t) => stream.removeTrack(t));
  stream.addTrack(newTrack);
  return stream;
}

/**
 * Switch to a different camera without interrupting the call.
 * @param {MediaStream} stream
 * @param {RTCRtpSender[]} senders
 * @param {string} deviceId
 * @returns {Promise<MediaStream>}
 */
export async function switchVideoInput(stream, senders, deviceId) {
  const newStream = await navigator.mediaDevices.getUserMedia({
    video: getVideoConstraints(deviceId),
  });
  applyTrackHints(newStream);
  const newTrack = newStream.getVideoTracks()[0];
  const videoSender = senders.find((s) => s.track && s.track.kind === "video");
  if (videoSender) {
    await replaceTrack(videoSender, newTrack);
    await applySenderProfile(videoSender);
  }
  stream.getVideoTracks().forEach((t) => t.stop());
  stream.getVideoTracks().forEach((t) => stream.removeTrack(t));
  stream.addTrack(newTrack);
  return stream;
}

/**
 * Check if setSinkId is supported for audio output selection.
 * @returns {boolean}
 */
export function supportsSetSinkId() {
  return typeof HTMLMediaElement !== "undefined" && "setSinkId" in HTMLMediaElement.prototype;
}

/**
 * Set audio output device on an element.
 * @param {HTMLMediaElement} element
 * @param {string} deviceId
 * @returns {Promise<boolean>}
 */
export async function setSinkId(element, deviceId) {
  if (!supportsSetSinkId()) {
    return false;
  }
  await element.setSinkId(deviceId);
  return true;
}

const MEDIA_VERIFY_DELAY_MS = 1800;
const MEDIA_VERIFY_RETRY_DELAY_MS = 900;

function hasVideoTracks(stream) {
  return (stream?.getVideoTracks?.() || []).length > 0;
}

function isRealMediaElement(element) {
  return typeof HTMLMediaElement === "undefined" || element instanceof HTMLMediaElement;
}

function liveVideoTracks(stream) {
  return (stream?.getVideoTracks?.() || []).filter((track) => track.readyState !== "ended");
}

function mediaElementToken() {
  return `${Date.now()}:${Math.random().toString(36).slice(2)}`;
}

function clearMediaElementVerifyTimer(element) {
  if (element?._rhcMediaVerifyTimer) {
    clearTimeout(element._rhcMediaVerifyTimer);
    element._rhcMediaVerifyTimer = null;
  }
}

function isCurrentMediaAttachment(element, token, stream) {
  return element?._rhcMediaAttachmentToken === token && element.srcObject === stream;
}

function videoStallReason(element, stream) {
  const tracks = liveVideoTracks(stream);

  if (tracks.length === 0) return null;
  if (tracks.some((track) => track.muted === true)) return "track-muted";

  const readyState = typeof element.readyState === "number" ? element.readyState : 0;
  const hasCurrentData =
    typeof HTMLMediaElement === "undefined" ||
    readyState >= (HTMLMediaElement.HAVE_CURRENT_DATA || 2);
  const hasDimensions = Number(element.videoWidth || 0) > 0 || Number(element.videoHeight || 0) > 0;

  if (!hasCurrentData) return "not-ready";
  if (!hasDimensions) return "no-video-dimensions";

  return null;
}

function startMediaElementPlayback(element, token, stream, options = {}) {
  if (!element || !isCurrentMediaAttachment(element, token, stream)) return;
  if (typeof element.play !== "function") return;

  try {
    const result = element.play();

    if (result && typeof result.catch === "function") {
      result.catch((error) => {
        if (!isCurrentMediaAttachment(element, token, stream)) return;
        options.onPlaybackError?.(error);
      });
    }
  } catch (error) {
    if (!isCurrentMediaAttachment(element, token, stream)) return;
    options.onPlaybackError?.(error);
  }
}

function scheduleMediaElementVerification(
  element,
  token,
  stream,
  options = {},
  delayMs,
  attempt = 0,
) {
  if (!hasVideoTracks(stream) || options.verifyVideo === false) return;
  if (!isRealMediaElement(element)) return;

  clearMediaElementVerifyTimer(element);
  element._rhcMediaVerifyTimer = setTimeout(() => {
    element._rhcMediaVerifyTimer = null;

    if (!isCurrentMediaAttachment(element, token, stream)) return;

    const reason = videoStallReason(element, stream);
    if (!reason) return;

    options.onVideoStalled?.({ reason, element, stream });

    if (options.reattachOnStall === false) return;

    element.srcObject = null;
    element.srcObject = stream;
    startMediaElementPlayback(element, token, stream, options);

    if (attempt < 1) {
      scheduleMediaElementVerification(
        element,
        token,
        stream,
        options,
        MEDIA_VERIFY_RETRY_DELAY_MS,
        attempt + 1,
      );
    }
  }, delayMs);
  element._rhcMediaVerifyTimer.unref?.();
}

/**
 * Attach a MediaStream to a media element and defensively start playback.
 *
 * Browser media elements can stay visually black when a stream is attached while
 * permission prompts, LiveView patches, or autoplay policies are still settling.
 * This helper centralizes the DOM contract used by P2P and group calls: assign
 * the stream, request playback, and reattach once if a video track is live but
 * the element still has no renderable frame after a short grace period.
 *
 * @param {HTMLMediaElement} element
 * @param {MediaStream | null} stream
 * @param {object} options
 * @returns {{ attached: boolean, changed: boolean }}
 */
export function attachMediaStream(element, stream, options = {}) {
  if (!element) return { attached: false, changed: false };

  if (typeof options.muted === "boolean") element.muted = options.muted;
  if (options.autoplay !== false) element.autoplay = true;
  if (options.playsInline !== false) {
    element.playsInline = true;
    element.setAttribute?.("playsinline", "");
  }

  if (!stream) {
    clearMediaElementVerifyTimer(element);
    const changed = element.srcObject !== null;
    element._rhcMediaAttachmentToken = mediaElementToken();
    element._rhcMediaAttachedStream = null;
    element.srcObject = null;
    return { attached: true, changed };
  }

  const changed = element.srcObject !== stream;
  const existingToken = element._rhcMediaAttachmentToken;

  if (!changed && element._rhcMediaAttachedStream === stream && existingToken) {
    queueMicrotask(() => {
      startMediaElementPlayback(element, existingToken, stream, options);
    });
    return { attached: true, changed: false };
  }

  clearMediaElementVerifyTimer(element);
  const token = mediaElementToken();
  element._rhcMediaAttachmentToken = token;
  element._rhcMediaAttachedStream = stream;

  if (changed) {
    element.srcObject = stream;
  }

  queueMicrotask(() => {
    startMediaElementPlayback(element, token, stream, options);
    scheduleMediaElementVerification(element, token, stream, options, MEDIA_VERIFY_DELAY_MS);
  });

  return { attached: true, changed };
}

// --- Quality Monitoring ---

/**
 * Poll connection statistics and return a quality snapshot.
 * @param {RTCPeerConnection} pc
 * @returns {Promise<{roundTripTime: number, packetLoss: number, jitter: number, timestamp: number}>}
 */
export async function getQualitySnapshot(pc) {
  const stats = await pc.getStats();
  let roundTripTime = 0;
  let packetLoss = 0;
  let jitter = 0;

  stats.forEach((report) => {
    if (report.type === "candidate-pair" && report.state === "succeeded") {
      roundTripTime = report.currentRoundTripTime || 0;
    }
    if (report.type === "inbound-rtp" && report.kind === "audio") {
      const lost = report.packetsLost || 0;
      const received = report.packetsReceived || 0;
      const total = lost + received;
      packetLoss = total > 0 ? (lost / total) * 100 : 0;
      jitter = report.jitter || 0;
    }
  });

  return { roundTripTime, packetLoss, jitter, timestamp: Date.now() };
}

/**
 * Map a quality snapshot to a quality level.
 * @param {{roundTripTime: number, packetLoss: number}} snapshot
 * @returns {"excellent"|"good"|"fair"|"poor"}
 */
export function mapQualityLevel(snapshot) {
  const { packetLoss, roundTripTime } = snapshot;
  if (packetLoss < 1 && roundTripTime < 0.1) return "excellent";
  if (packetLoss < 3 && roundTripTime < 0.2) return "good";
  if (packetLoss < 8 && roundTripTime < 0.4) return "fair";
  return "poor";
}

/**
 * Collect a detailed connection stats snapshot from getStats().
 *
 * Most fields are cumulative counters (bytes, packets) and must be turned into
 * rates via deriveStats() using a previous snapshot. RTT, jitter and the video
 * dimensions are instantaneous gauges.
 * @param {RTCPeerConnection} pc
 * @returns {Promise<object>} raw snapshot
 */
export async function getStatsSnapshot(pc) {
  const stats = await pc.getStats();
  const snap = {
    timestamp: Date.now(),
    roundTripTime: 0, // seconds (candidate-pair)
    jitter: 0, // seconds (worst inbound stream)
    availableOutgoingBitrate: 0, // bps
    packetsLost: 0, // cumulative
    packetsReceived: 0, // cumulative
    bytesReceived: 0, // cumulative
    bytesSent: 0, // cumulative
    framesPerSecond: 0, // inbound video gauge
    frameWidth: 0,
    frameHeight: 0,
    freezeCount: 0, // cumulative
    qualityLimitationReason: "none", // outbound video: cpu | bandwidth | none | other
    hasVideo: false,
  };

  stats.forEach((report) => {
    if (report.type === "candidate-pair" && report.state === "succeeded") {
      snap.roundTripTime = report.currentRoundTripTime || snap.roundTripTime;
      snap.availableOutgoingBitrate =
        report.availableOutgoingBitrate || snap.availableOutgoingBitrate;
    }

    if (report.type === "inbound-rtp") {
      snap.packetsLost += report.packetsLost || 0;
      snap.packetsReceived += report.packetsReceived || 0;
      snap.bytesReceived += report.bytesReceived || 0;
      if (typeof report.jitter === "number") {
        snap.jitter = Math.max(snap.jitter, report.jitter);
      }
      if (report.kind === "video") {
        snap.hasVideo = true;
        snap.framesPerSecond = report.framesPerSecond || snap.framesPerSecond;
        snap.frameWidth = report.frameWidth || snap.frameWidth;
        snap.frameHeight = report.frameHeight || snap.frameHeight;
        snap.freezeCount = report.freezeCount || snap.freezeCount;
      }
    }

    if (report.type === "outbound-rtp") {
      snap.bytesSent += report.bytesSent || 0;
      if (report.kind === "video" && report.qualityLimitationReason) {
        snap.qualityLimitationReason = report.qualityLimitationReason;
      }
    }
  });

  return snap;
}

/**
 * Estimate a MOS (Mean Opinion Score, 1-5) from latency, jitter and packet loss
 * using the ITU-T E-model R-factor approximation. Higher is better.
 * @param {{rttMs: number, jitterMs: number, lossPct: number}} m
 * @returns {number} MOS clamped to [1, 5], one decimal
 */
export function computeMos({ rttMs, jitterMs, lossPct }) {
  // Effective latency folds in jitter (counted twice) and a fixed delay budget.
  const effectiveLatency = rttMs + jitterMs * 2 + 10;

  let r =
    effectiveLatency < 160 ? 93.2 - effectiveLatency / 40 : 93.2 - effectiveLatency / 120 - 10;

  // Each 1% of packet loss costs ~2.5 R-factor points.
  r -= lossPct * 2.5;
  r = Math.max(0, Math.min(100, r));

  const mos = 1 + 0.035 * r + r * (r - 60) * (100 - r) * 0.000007;
  return Math.max(1, Math.min(5, Math.round(mos * 10) / 10));
}

/**
 * Map a MOS value to a quality level.
 * @param {number} mos
 * @returns {"excellent"|"good"|"fair"|"poor"}
 */
export function mosToLevel(mos) {
  if (mos >= 4.2) return "excellent";
  if (mos >= 4.0) return "good";
  if (mos >= 3.5) return "fair";
  return "poor";
}

/**
 * Turn two raw snapshots into human-facing metrics for the network panel.
 * Counters become rates over the elapsed interval; the first sample (no prev)
 * yields zeroed rates but valid gauges.
 * @param {object|null} prev
 * @param {object} curr
 * @returns {object} derived, display-ready metrics
 */
export function deriveStats(prev, curr) {
  const rttMs = Math.round((curr.roundTripTime || 0) * 1000);
  const jitterMs = Math.round((curr.jitter || 0) * 1000);

  let inboundKbps = 0;
  let outboundKbps = 0;
  let lossPct = 0;

  if (prev) {
    const intervalSec = Math.max((curr.timestamp - prev.timestamp) / 1000, 0.001);
    inboundKbps = Math.max(
      0,
      Math.round(((curr.bytesReceived - prev.bytesReceived) * 8) / intervalSec / 1000),
    );
    outboundKbps = Math.max(
      0,
      Math.round(((curr.bytesSent - prev.bytesSent) * 8) / intervalSec / 1000),
    );
    const lostDelta = Math.max(0, curr.packetsLost - prev.packetsLost);
    const recvDelta = Math.max(0, curr.packetsReceived - prev.packetsReceived);
    const totalDelta = lostDelta + recvDelta;
    lossPct = totalDelta > 0 ? Math.round((lostDelta / totalDelta) * 1000) / 10 : 0;
  }

  const mos = computeMos({ rttMs, jitterMs, lossPct });
  const level = mosToLevel(mos);

  return {
    level,
    label: QUALITY_LABELS[level],
    mos,
    rtt_ms: rttMs,
    jitter_ms: jitterMs,
    loss_pct: lossPct,
    inbound_kbps: inboundKbps,
    outbound_kbps: outboundKbps,
    available_kbps: Math.round((curr.availableOutgoingBitrate || 0) / 1000),
    fps: Math.round(curr.framesPerSecond || 0),
    frame_width: curr.frameWidth || 0,
    frame_height: curr.frameHeight || 0,
    freeze_count: curr.freezeCount || 0,
    limitation: curr.qualityLimitationReason || "none",
    has_video: Boolean(curr.hasVideo),
  };
}

// --- Per-feature stats (always-on lobby telemetry) ---

/**
 * Collect a raw stats snapshot broken down per feature: the transport, audio and
 * video RTP streams (each by kind), and every data channel by label (gamedata,
 * filetransfer). Unlike getStatsSnapshot() this never aggregates streams together
 * so the statistics window can show isolated metrics for each feature.
 * @param {RTCPeerConnection} pc
 * @returns {Promise<object>} raw per-feature snapshot
 */
export async function collectFeatureSnapshot(pc) {
  const stats = await pc.getStats();

  return collectFeatureSnapshotFromReports(stats);
}

/**
 * Build the per-feature snapshot from an already collected RTCStatsReport.
 *
 * This lets feature hooks reuse one getStats() read for multiple summaries
 * without adding extra work to the browser hot path.
 * @param {RTCStatsReport|Map<string, object>} stats
 * @returns {object} raw per-feature snapshot
 */
export function collectFeatureSnapshotFromReports(stats) {
  const snap = {
    timestamp: Date.now(),
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
    channels: {}, // keyed by label
  };

  stats.forEach((report) => {
    if (report.type === "candidate-pair" && report.state === "succeeded") {
      snap.connection.rtt = report.currentRoundTripTime || snap.connection.rtt;
      snap.connection.availableOutgoing =
        report.availableOutgoingBitrate || snap.connection.availableOutgoing;
    }

    if (report.type === "inbound-rtp" && (report.kind === "audio" || report.kind === "video")) {
      const k = snap[report.kind];
      k.active = true;
      k.inBytes += report.bytesReceived || 0;
      k.packetsLost += report.packetsLost || 0;
      k.packetsReceived += report.packetsReceived || 0;
      if (typeof report.jitter === "number") k.jitter = Math.max(k.jitter, report.jitter);
      if (report.kind === "video") {
        k.fps = report.framesPerSecond || k.fps;
        k.width = report.frameWidth || k.width;
        k.height = report.frameHeight || k.height;
        k.freezeCount = report.freezeCount || k.freezeCount;
      }
    }

    if (report.type === "outbound-rtp" && (report.kind === "audio" || report.kind === "video")) {
      const k = snap[report.kind];
      k.active = true;
      k.outBytes += report.bytesSent || 0;
      if (report.kind === "video" && report.qualityLimitationReason) {
        k.limitation = report.qualityLimitationReason;
      }
    }

    if (report.type === "data-channel") {
      snap.channels[report.label] = {
        state: report.state || "",
        bytesSent: report.bytesSent || 0,
        bytesReceived: report.bytesReceived || 0,
        messagesSent: report.messagesSent || 0,
        messagesReceived: report.messagesReceived || 0,
      };
    }
  });

  return snap;
}

/**
 * Collect coarse connection activity counters from getStats().
 *
 * This intentionally ignores identity-bearing fields. It is used only to decide
 * whether a `disconnected` state is still moving media/data before escalating to
 * an ICE restart.
 * @param {RTCPeerConnection|null} pc
 * @returns {Promise<object|null>}
 */
export async function collectConnectionActivity(pc) {
  if (!pc?.getStats) return null;

  try {
    return collectConnectionActivityFromReports(await pc.getStats());
  } catch {
    return null;
  }
}

/**
 * Build a low-cardinality activity snapshot from an RTCStatsReport.
 * @param {RTCStatsReport|Map<string, object>} stats
 * @returns {object}
 */
export function collectConnectionActivityFromReports(stats) {
  const activity = {
    bytesReceived: 0,
    bytesSent: 0,
    packetsReceived: 0,
    packetsSent: 0,
    messagesReceived: 0,
    messagesSent: 0,
  };

  stats?.forEach?.((report) => {
    if (report.type === "candidate-pair" && report.state === "succeeded") {
      activity.bytesReceived += report.bytesReceived || 0;
      activity.bytesSent += report.bytesSent || 0;
      activity.packetsReceived += report.packetsReceived || 0;
      activity.packetsSent += report.packetsSent || 0;
    }

    if (report.type === "transport") {
      activity.bytesReceived += report.bytesReceived || 0;
      activity.bytesSent += report.bytesSent || 0;
      activity.packetsReceived += report.packetsReceived || 0;
      activity.packetsSent += report.packetsSent || 0;
    }

    if (report.type === "inbound-rtp") {
      activity.bytesReceived += report.bytesReceived || 0;
      activity.packetsReceived += report.packetsReceived || 0;
    }

    if (report.type === "outbound-rtp") {
      activity.bytesSent += report.bytesSent || 0;
      activity.packetsSent += report.packetsSent || 0;
    }

    if (report.type === "data-channel") {
      activity.bytesReceived += report.bytesReceived || 0;
      activity.bytesSent += report.bytesSent || 0;
      activity.messagesReceived += report.messagesReceived || 0;
      activity.messagesSent += report.messagesSent || 0;
    }
  });

  return activity;
}

/**
 * @param {object|null} previous
 * @param {object|null} current
 * @returns {boolean}
 */
export function hasConnectionActivity(previous, current) {
  if (!previous || !current) return false;

  return (
    current.bytesReceived > previous.bytesReceived ||
    current.bytesSent > previous.bytesSent ||
    current.packetsReceived > previous.packetsReceived ||
    current.packetsSent > previous.packetsSent ||
    current.messagesReceived > previous.messagesReceived ||
    current.messagesSent > previous.messagesSent
  );
}

/**
 * Turn two per-feature snapshots into the always-complete statistics payload.
 * Every section is always present; counters become rates over the interval and a
 * missing stream simply reads zero (idle), never absent.
 * @param {object|null} prev
 * @param {object} curr
 * @returns {object} statistics payload for the lobby_stats event
 */
export function deriveFeatureStats(prev, curr) {
  const intervalSec = prev ? Math.max((curr.timestamp - prev.timestamp) / 1000, 0.001) : 1;
  const kbps = (cur, pre) =>
    prev ? Math.max(0, Math.round(((cur - pre) * 8) / intervalSec / 1000)) : 0;
  const lossPct = (lost, recv) => {
    const total = Math.max(0, lost) + Math.max(0, recv);
    return total > 0 ? Math.round((Math.max(0, lost) / total) * 1000) / 10 : 0;
  };

  const rtp = (kind) => {
    const c = curr[kind];
    const p = prev ? prev[kind] : null;
    return {
      active: c.active,
      in_kbps: kbps(c.inBytes, p ? p.inBytes : 0),
      out_kbps: kbps(c.outBytes, p ? p.outBytes : 0),
      loss_pct: p
        ? lossPct(c.packetsLost - p.packetsLost, c.packetsReceived - p.packetsReceived)
        : 0,
      jitter_ms: Math.round((c.jitter || 0) * 1000),
    };
  };

  const channel = (label) => {
    const c = curr.channels[label];
    const p = prev && prev.channels ? prev.channels[label] : null;
    if (!c) return { active: false, state: "closed", sent_kbps: 0, recv_kbps: 0, messages: 0 };
    return {
      active: c.state === "open" && c.bytesSent + c.bytesReceived > 0,
      state: c.state || "closed",
      sent_kbps: kbps(c.bytesSent, p ? p.bytesSent : 0),
      recv_kbps: kbps(c.bytesReceived, p ? p.bytesReceived : 0),
      messages: (c.messagesSent || 0) + (c.messagesReceived || 0),
    };
  };

  const audio = rtp("audio");
  const video = rtp("video");
  const rttMs = Math.round((curr.connection.rtt || 0) * 1000);
  // Connection health folds the worst of the active media streams.
  const jitterMs = Math.max(audio.jitter_ms, video.jitter_ms);
  const lossOverall = Math.max(audio.loss_pct, video.loss_pct);
  const mos = computeMos({ rttMs, jitterMs, lossPct: lossOverall });
  const level = mosToLevel(mos);

  return {
    connection: {
      rtt_ms: rttMs,
      jitter_ms: jitterMs,
      loss_pct: lossOverall,
      available_kbps: Math.round((curr.connection.availableOutgoing || 0) / 1000),
      mos,
      level,
      label: QUALITY_LABELS[level],
    },
    audio,
    video: {
      ...video,
      fps: Math.round(curr.video.fps || 0),
      width: curr.video.width || 0,
      height: curr.video.height || 0,
      freeze_count: curr.video.freezeCount || 0,
      limitation: curr.video.limitation || "none",
    },
    game: channel("gamedata"),
    file: channel("filetransfer"),
  };
}

/**
 * Apply media content hints to the tracks in a stream.
 * @param {MediaStream} stream
 * @param {"stable"|"low"|"high"|"screen"} profileName
 */
export function applyTrackHints(stream, profileName = DEFAULT_MEDIA_PROFILE) {
  const profile = mediaProfile(profileName);

  for (const track of stream?.getAudioTracks?.() || []) {
    if ("contentHint" in track) track.contentHint = profile.hints?.audio || "speech";
  }

  for (const track of stream?.getVideoTracks?.() || []) {
    if ("contentHint" in track) track.contentHint = profile.hints?.video || "motion";
  }
}

/**
 * Apply one fixed media profile to a single RTP sender.
 *
 * Sender caps are best-effort: browsers may reject setParameters while a
 * transceiver is still being negotiated or when an encoding field is not
 * supported. Capture constraints still keep the call conservative, so caps must
 * never abort SDP negotiation.
 *
 * @param {RTCRtpSender} sender
 * @param {"stable"|"low"|"high"|"screen"} profileName
 * @returns {Promise<boolean>} true when the sender accepted the profile
 */
export async function applySenderProfile(sender, profileName = DEFAULT_MEDIA_PROFILE) {
  if (!sender?.track || typeof sender.setParameters !== "function") return false;

  const profile = mediaProfile(profileName);
  let params;

  try {
    params = typeof sender.getParameters === "function" ? sender.getParameters() : {};
  } catch {
    return false;
  }

  if (!params.encodings || params.encodings.length === 0) {
    params.encodings = [{}];
  }

  const send = profile.send || MEDIA_PROFILES.stable.send;
  const maxBitrate = sender.track.kind === "video" ? send.videoBitrate : send.audioBitrate;

  params.encodings.forEach((encoding) => {
    if (maxBitrate) encoding.maxBitrate = maxBitrate;

    if (sender.track.kind === "video" && send.maxFramerate) {
      encoding.maxFramerate = send.maxFramerate;
    }
  });

  try {
    await sender.setParameters(params);
    return true;
  } catch {
    return false;
  }
}

/**
 * Apply one fixed media profile to all active RTP senders.
 * @param {RTCPeerConnection} pc
 * @param {"stable"|"low"|"high"|"screen"} profileName
 * @returns {Promise<void>}
 */
export async function applyMediaProfile(pc, profileName = DEFAULT_MEDIA_PROFILE) {
  if (!pc?.getSenders) return;

  for (const sender of pc.getSenders()) {
    await applySenderProfile(sender, profileName);
  }
}

/**
 * Apply a bitrate preset to all senders on the peer connection.
 * @param {RTCPeerConnection} pc
 * @param {"high"|"medium"|"low"} preset
 * @returns {Promise<void>}
 */
export async function applyBitratePreset(pc, preset) {
  const limits = BITRATE_PRESETS[preset];
  if (!limits) return;

  const senders = pc.getSenders();
  for (const sender of senders) {
    if (!sender.track) continue;
    const params = sender.getParameters();
    if (!params.encodings || params.encodings.length === 0) {
      params.encodings = [{}];
    }
    const maxBitrate = sender.track.kind === "video" ? limits.video : limits.audio;
    params.encodings.forEach((encoding) => {
      encoding.maxBitrate = maxBitrate;
      if (sender.track.kind === "video") {
        encoding.maxFramerate = preset === "high" ? 30 : 15;
      }
    });
    await sender.setParameters(params);
  }
}

// --- Codec Preferences ---

/**
 * Set preferred codec order on transceivers (H.264 > VP8, Opus first).
 * No-op if setCodecPreferences is not supported.
 * @param {RTCPeerConnection} pc
 */
export function setCodecPreferences(pc) {
  const transceivers = pc.getTransceivers ? pc.getTransceivers() : [];

  for (const transceiver of transceivers) {
    if (!transceiver.setCodecPreferences) continue;

    const kind = transceiver.receiver?.track?.kind || transceiver.sender?.track?.kind;
    if (!kind) continue;

    const capabilities = RTCRtpReceiver.getCapabilities
      ? RTCRtpReceiver.getCapabilities(kind)
      : null;
    if (!capabilities) continue;

    const codecs = [...capabilities.codecs];

    if (kind === "video") {
      codecs.sort((a, b) => {
        const aH264 = a.mimeType.toLowerCase().includes("h264") ? 0 : 1;
        const bH264 = b.mimeType.toLowerCase().includes("h264") ? 0 : 1;
        return aH264 - bH264;
      });
    } else if (kind === "audio") {
      codecs.sort((a, b) => {
        const aOpus = a.mimeType.toLowerCase().includes("opus") ? 0 : 1;
        const bOpus = b.mimeType.toLowerCase().includes("opus") ? 0 : 1;
        return aOpus - bOpus;
      });
    }

    transceiver.setCodecPreferences(codecs);
  }
}

// --- Picture-in-Picture ---

/**
 * Check if Picture-in-Picture is supported.
 * @returns {boolean}
 */
export function supportsPiP() {
  return typeof document !== "undefined" && !!document.pictureInPictureEnabled;
}

/**
 * Toggle Picture-in-Picture mode on a video element.
 * @param {HTMLVideoElement} videoElement
 * @returns {Promise<void>}
 */
export async function togglePiP(videoElement) {
  if (document.pictureInPictureElement === videoElement) {
    await document.exitPictureInPicture();
  } else {
    await videoElement.requestPictureInPicture();
  }
}
