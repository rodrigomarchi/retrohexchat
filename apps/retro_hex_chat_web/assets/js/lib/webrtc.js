/**
 * WebRTC peer connection management — pure logic, no DOM or LiveView dependencies.
 * @module webrtc
 */

/**
 * Retry state machine constants.
 */
export const RETRY_CONFIG = {
  maxAttempts: 3,
  delays: [2000, 4000, 8000],
  disconnectedGracePeriod: 5000,
};

/**
 * Create a new RTCPeerConnection with given ICE server config.
 * @param {RTCIceServer[]} iceServers
 * @returns {RTCPeerConnection}
 */
export function createPeerConnection(iceServers) {
  return new RTCPeerConnection({ iceServers });
}

/**
 * Create an SDP offer and set as local description.
 * @param {RTCPeerConnection} pc
 * @returns {Promise<{type: "offer", sdp: string}>}
 */
export async function createOffer(pc) {
  const offer = await pc.createOffer();
  await pc.setLocalDescription(offer);
  return offer;
}

/**
 * Set remote offer and create SDP answer.
 * @param {RTCPeerConnection} pc
 * @param {{type: "offer", sdp: string}} offer
 * @returns {Promise<{type: "answer", sdp: string}>}
 */
export async function createAnswer(pc, offer) {
  await pc.setRemoteDescription(offer);
  const answer = await pc.createAnswer();
  await pc.setLocalDescription(answer);
  return answer;
}

/**
 * Set remote answer on peer connection.
 * @param {RTCPeerConnection} pc
 * @param {{type: "answer", sdp: string}} answer
 * @returns {Promise<void>}
 */
export async function handleAnswer(pc, answer) {
  await pc.setRemoteDescription(answer);
}

/**
 * Add an ICE candidate to the peer connection.
 * @param {RTCPeerConnection} pc
 * @param {RTCIceCandidateInit} candidate
 * @returns {Promise<void>}
 */
export async function addIceCandidate(pc, candidate) {
  await pc.addIceCandidate(candidate);
}

/**
 * Close peer connection and clean up.
 * @param {RTCPeerConnection} pc
 */
export function close(pc) {
  pc.close();
}

/**
 * Register callback for connection state changes.
 * @param {RTCPeerConnection} pc
 * @param {(state: RTCPeerConnectionState) => void} callback
 */
export function onConnectionStateChange(pc, callback) {
  pc.onconnectionstatechange = () => callback(pc.connectionState);
}

/**
 * Register callback for new ICE candidates.
 * @param {RTCPeerConnection} pc
 * @param {(candidate: RTCIceCandidate | null) => void} callback
 */
export function onIceCandidate(pc, callback) {
  pc.onicecandidate = (event) => callback(event.candidate);
}

/**
 * Register callback for incoming data channels.
 * @param {RTCPeerConnection} pc
 * @param {(channel: RTCDataChannel) => void} callback
 */
export function onDataChannel(pc, callback) {
  pc.ondatachannel = (event) => callback(event.channel);
}
