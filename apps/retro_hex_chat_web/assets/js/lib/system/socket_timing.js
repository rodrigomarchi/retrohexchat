/**
 * How long a LiveSocket gives a WebSocket handshake before it falls back to
 * long-polling, for every page that opens one.
 *
 * The fallback exists for networks that block WebSocket outright, and those
 * fail fast: the socket errors and LiveView falls back without waiting out
 * this timer. The timer only decides how long a *working but slow* handshake
 * gets, so it has to clear intercontinental latency — cutting it short strands
 * the session on long-polling for its whole lifetime, and WebRTC signalling
 * rides this socket.
 *
 * @module system/socket_timing
 */
export const LONG_POLL_FALLBACK_MS = 10_000;
