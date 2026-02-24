/**
 * P2P capability detection and permission requests.
 * Logic module — hooks handle wiring only.
 */

/**
 * Detect browser capabilities for P2P features.
 * @returns {Promise<{webrtc: boolean, getUserMedia: boolean, dataChannel: boolean}>}
 */
export async function detectCapabilities() {
  const webrtc = typeof window.RTCPeerConnection === "function";
  const getUserMedia = typeof navigator.mediaDevices?.getUserMedia === "function";
  const dataChannel = webrtc && typeof RTCPeerConnection.prototype.createDataChannel === "function";

  return { webrtc, getUserMedia, dataChannel };
}

/**
 * Request browser permission for a media type.
 * @param {"microphone"|"camera"} type
 * @returns {Promise<{granted: boolean, type: string}>}
 */
export async function requestPermission(type) {
  const constraints = type === "camera" ? { video: true } : { audio: true };

  try {
    const stream = await navigator.mediaDevices.getUserMedia(constraints);
    // Stop tracks immediately — we only need permission, not the stream
    stream.getTracks().forEach((track) => track.stop());
    return { granted: true, type };
  } catch {
    return { granted: false, type };
  }
}
