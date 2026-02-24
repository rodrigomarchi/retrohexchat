/**
 * LiveView hook for real-time latency measurement.
 *
 * Sends periodic ping events to the server and measures round-trip time.
 * Pushes lag_update events with the calculated latency.
 */
import { calculateLag, PING_INTERVAL, PING_TIMEOUT } from "../../lib/connection/lag.js";

const LagHook = {
  mounted() {
    this._startPinging();

    this.handleEvent("pong", ({ client_time: clientTime }) => {
      clearTimeout(this._timeout);
      const lag = calculateLag(clientTime, Date.now());
      this.pushEvent("lag_update", { lag_ms: lag });
    });
  },

  disconnected() {
    this._stopPinging();
  },

  reconnected() {
    this._startPinging();
  },

  destroyed() {
    this._stopPinging();
  },

  _startPinging() {
    this._stopPinging();
    this._interval = setInterval(() => {
      this.pushEvent("ping", { client_time: Date.now() });
      this._timeout = setTimeout(() => {
        this.pushEvent("lag_update", { lag_ms: null });
      }, PING_TIMEOUT);
    }, PING_INTERVAL);
  },

  _stopPinging() {
    clearInterval(this._interval);
    clearTimeout(this._timeout);
    this._interval = null;
    this._timeout = null;
  },
};

export default LagHook;
