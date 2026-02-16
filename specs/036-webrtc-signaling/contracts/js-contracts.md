# JavaScript Contracts: WebRTC Signaling (036)

## webrtc.js (lib module — pure logic, no DOM)

```javascript
/**
 * Create a new RTCPeerConnection with given ICE server config.
 * @param {RTCIceServer[]} iceServers - ICE server configuration
 * @returns {RTCPeerConnection}
 */
export function createPeerConnection(iceServers)

/**
 * Create an SDP offer and set as local description.
 * @param {RTCPeerConnection} pc
 * @returns {Promise<{type: "offer", sdp: string}>}
 */
export async function createOffer(pc)

/**
 * Set remote offer and create SDP answer.
 * @param {RTCPeerConnection} pc
 * @param {{type: "offer", sdp: string}} offer
 * @returns {Promise<{type: "answer", sdp: string}>}
 */
export async function createAnswer(pc, offer)

/**
 * Set remote answer on peer connection.
 * @param {RTCPeerConnection} pc
 * @param {{type: "answer", sdp: string}} answer
 * @returns {Promise<void>}
 */
export async function handleAnswer(pc, answer)

/**
 * Add an ICE candidate to the peer connection.
 * @param {RTCPeerConnection} pc
 * @param {RTCIceCandidateInit} candidate
 * @returns {Promise<void>}
 */
export async function addIceCandidate(pc, candidate)

/**
 * Close peer connection and clean up.
 * @param {RTCPeerConnection} pc
 */
export function close(pc)

/**
 * Register callback for connection state changes.
 * @param {RTCPeerConnection} pc
 * @param {(state: RTCPeerConnectionState) => void} callback
 */
export function onConnectionStateChange(pc, callback)

/**
 * Register callback for new ICE candidates.
 * @param {RTCPeerConnection} pc
 * @param {(candidate: RTCIceCandidate | null) => void} callback
 */
export function onIceCandidate(pc, callback)

/**
 * Register callback for incoming data channels.
 * @param {RTCPeerConnection} pc
 * @param {(channel: RTCDataChannel) => void} callback
 */
export function onDataChannel(pc, callback)

/**
 * Retry state machine constants.
 */
export const RETRY_CONFIG = {
  maxAttempts: 3,
  delays: [2000, 4000, 8000],
  disconnectedGracePeriod: 5000,
}
```

## webrtc_hook.js (hook — wiring only)

```javascript
/**
 * LiveView Hook: WebRTCHook
 *
 * Server events handled:
 *   - "p2p_start_offer"  → createPeerConnection + createOffer, push offer to server
 *   - "p2p_start_answer" → store ICE servers, wait for offer via p2p_signal
 *   - "p2p_signal"       → dispatch to createAnswer / handleAnswer / addIceCandidate
 *
 * Events pushed to server:
 *   - "p2p_signal"    → {type, sdp|candidate} — relay to peer
 *   - "p2p_connected" → {} — connection established
 *   - "p2p_failed"    → {reason} — permanent failure
 *   - "p2p_retry"     → {attempt} — retry started
 *
 * Internal state:
 *   - this.pc           → current RTCPeerConnection (or null)
 *   - this.iceServers   → ICE server config from server
 *   - this.retryCount   → current retry attempt (0-based)
 *   - this.disconnectedTimer → 5s grace timer ID
 */
```
