/**
 * LiveView Hook: LobbyWebRTCHook
 *
 * Owns the single, persistent RTCPeerConnection for a P2P session and
 * multiplexes every feature over it (audio/video transceivers, the file-transfer
 * and game DataChannels). The connection logic — signalling, negotiation,
 * recovery, ICE, stats — lives in the framework-free controller
 * `lib/p2p/lobby_connection.js`, which a test can drive without LiveView. This
 * file is only the registration seam.
 */
import { createLobbyConnectionHook } from "../../lib/p2p/lobby_connection.js";

export default createLobbyConnectionHook();
