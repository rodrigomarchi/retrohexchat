/**
 * Media management for audio/video calls — pure logic, no DOM or LiveView dependencies.
 * @module media
 */

/**
 * Quality level labels.
 */
export const QUALITY_LABELS = {
  excellent: "Excellent",
  good: "Good",
  fair: "Fair",
  poor: "Poor",
};

/**
 * Bitrate presets for manual quality adjustment.
 */
export const BITRATE_PRESETS = {
  high: { video: 1_500_000, audio: 128_000 },
  medium: { video: 500_000, audio: 64_000 },
  low: { video: 150_000, audio: 32_000 },
};

// --- Media Acquisition ---

/**
 * Standard audio constraints with echo cancellation.
 * @returns {MediaTrackConstraints}
 */
export function getAudioConstraints() {
  return { echoCancellation: true, noiseSuppression: true };
}

/**
 * Standard video constraints for 640x480.
 * @returns {MediaTrackConstraints}
 */
export function getVideoConstraints() {
  return { width: { ideal: 640 }, height: { ideal: 480 }, facingMode: "user" };
}

/**
 * Categorize a getUserMedia error into a user-friendly message.
 * @param {Error} error
 * @returns {{ code: string, message: string }}
 */
export function categorizeMediaError(error) {
  switch (error.name) {
    case "NotAllowedError":
      return {
        code: "permission_denied",
        message:
          "Microphone permission denied. Enable microphone permission in your browser and try again.",
      };
    case "NotReadableError":
      return {
        code: "not_readable",
        message:
          "Camera in use by another application. Try closing other programs using the camera.",
      };
    case "NotFoundError":
      return {
        code: "not_found",
        message: "No camera found.",
      };
    default:
      return {
        code: "unknown",
        message: `Error accessing media: ${error.message}`,
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
    return await navigator.mediaDevices.getUserMedia(constraints);
  } catch (error) {
    throw categorizeMediaError(error);
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
    audio: { ...getAudioConstraints(), deviceId: { exact: deviceId } },
  });
  const newTrack = newStream.getAudioTracks()[0];
  const audioSender = senders.find((s) => s.track && s.track.kind === "audio");
  if (audioSender) {
    await replaceTrack(audioSender, newTrack);
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
    video: { ...getVideoConstraints(), deviceId: { exact: deviceId } },
  });
  const newTrack = newStream.getVideoTracks()[0];
  const videoSender = senders.find((s) => s.track && s.track.kind === "video");
  if (videoSender) {
    await replaceTrack(videoSender, newTrack);
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
