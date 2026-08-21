/**
 * LiveView hook for real-time latency measurement.
 *
 * Sends periodic ping events to the server and measures round-trip time.
 * Pushes lag_update events with the calculated latency.
 *
 * The same round trip is the app's only measurement of how the socket — not
 * the page load — actually behaves for a real user, so it is reported to RUM
 * as well as to the status bar. The socket's own up/down transitions ride
 * along: LiveView tells this hook about them already, and nothing else was
 * recording them.
 */
import { calculateLag, PING_INTERVAL, PING_TIMEOUT } from "../../lib/connection/lag.js";
import { recordEvent, recordMeasurement } from "../../lib/telemetry/rum.js";

const LagHook = {
  mounted() {
    this._offlineSince = null;
    this._startPinging();

    this.handleEvent("pong", ({ client_time: clientTime }) => {
      clearTimeout(this._timeout);
      const lag = calculateLag(clientTime, Date.now());
      recordMeasurement("liveview_lag", { lag_ms: lag });
      this.pushEvent("lag_update", { lag_ms: lag });
    });
  },

  disconnected() {
    this._offlineSince = Date.now();
    recordEvent("liveview_socket_lost");
    this._stopPinging();
  },

  reconnected() {
    if (this._offlineSince) {
      // calculateLag is "elapsed since a client timestamp", which is exactly
      // what downtime is.
      recordMeasurement("liveview_socket_downtime", {
        downtime_ms: calculateLag(this._offlineSince, Date.now()),
      });
      this._offlineSince = null;
    }

    recordEvent("liveview_socket_restored");
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
        recordEvent("liveview_lag_timeout");
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
