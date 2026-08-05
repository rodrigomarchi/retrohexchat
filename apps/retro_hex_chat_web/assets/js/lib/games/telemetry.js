/**
 * Client-side telemetry for a running P2P game session.
 *
 * The call already reports its health to the server (RTT, jitter, loss, freeze
 * count) and that is how call problems get found. Games had no equivalent: a
 * match that stuttered on one side left nothing behind to look at. This
 * collects the equivalent signals for the game channel and emits a periodic
 * sample the engine forwards to the server.
 *
 * What matters here is the *asymmetry* between the two peers. A host that steps
 * at 60 Hz while its guest renders at 12 fps is the exact failure this exists to
 * make visible, so every sample is tagged with the role that produced it.
 *
 * @module games/telemetry
 */

/** How often a sample is emitted. Matches the call's stats cadence. */
export const SAMPLE_INTERVAL_MS = 5000;

/** Ceiling on retained inter-arrival gaps, so a long match cannot grow memory. */
const MAX_GAP_SAMPLES = 512;

export class GameTelemetry {
  /**
   * @param {object} options
   * @param {string} options.gameId
   * @param {boolean} options.isHost
   * @param {(sample: object) => void} options.onSample
   * @param {number} [options.intervalMs]
   */
  constructor({ gameId, isHost, onSample, intervalMs = SAMPLE_INTERVAL_MS }) {
    this.gameId = gameId;
    this.role = isHost ? "host" : "guest";
    this.onSample = onSample;
    this.intervalMs = intervalMs;
    this.running = false;
    this._windowStart = 0;
    this._resetWindow(0);
  }

  /**
   * @param {number} now
   * @returns {void}
   */
  start(now) {
    this.running = true;
    this._resetWindow(now);
  }

  /** @returns {void} */
  stop() {
    this.running = false;
  }

  /** @returns {void} */
  frameRendered() {
    this._frames += 1;
  }

  /**
   * @param {number} count - Simulation steps executed this frame.
   * @returns {void}
   */
  stepsRan(count) {
    this._steps += count;
  }

  /**
   * @param {number} droppedSteps - Steps discarded because the loop fell behind.
   * @param {number} stallCount - Frames whose backlog exceeded the catch-up cap.
   * @returns {void}
   */
  stalled(droppedSteps, stallCount) {
    this._droppedSteps += droppedSteps;
    this._stalls += stallCount;
  }

  /**
   * @param {number} bytes
   * @returns {void}
   */
  stateSent(bytes) {
    this._statesOut += 1;
    this._bytesOut += bytes;
  }

  /**
   * @param {number} bytes
   * @param {number} now
   * @returns {void}
   */
  stateReceived(bytes, now) {
    this._statesIn += 1;
    this._bytesIn += bytes;

    if (this._lastStateAt !== null) {
      const gap = now - this._lastStateAt;
      if (this._gaps.length < MAX_GAP_SAMPLES) this._gaps.push(gap);
      if (gap > this._gapMax) this._gapMax = gap;
    }

    this._lastStateAt = now;
  }

  /**
   * A send was skipped because the channel was already backed up.
   * @param {number} bufferedBytes
   * @returns {void}
   */
  sendDropped(bufferedBytes) {
    this._sendDropped += 1;
    this.bufferedObserved(bufferedBytes);
  }

  /**
   * @param {number} bufferedBytes
   * @returns {void}
   */
  bufferedObserved(bufferedBytes) {
    if (bufferedBytes > this._bufferedPeak) this._bufferedPeak = bufferedBytes;
  }

  /**
   * Emit a sample if the window has elapsed.
   * @param {number} now
   * @param {string} channelState
   * @returns {object|null} the emitted sample, or null
   */
  maybeFlush(now, channelState) {
    if (!this.running) return null;

    const elapsed = now - this._windowStart;
    if (elapsed < this.intervalMs) return null;

    const sample = this._buildSample(elapsed, channelState);
    this._resetWindow(now);

    if (this.onSample) this.onSample(sample);
    return sample;
  }

  /**
   * @param {number} elapsedMs
   * @param {string} channelState
   * @returns {object}
   */
  _buildSample(elapsedMs, channelState) {
    const perSecond = (count) => Math.round((count / elapsedMs) * 1000 * 10) / 10;

    return {
      game_id: this.gameId,
      role: this.role,
      window_ms: Math.round(elapsedMs),
      channel_state: channelState || "unknown",
      render_fps: perSecond(this._frames),
      step_hz: perSecond(this._steps),
      state_out_hz: perSecond(this._statesOut),
      state_in_hz: perSecond(this._statesIn),
      bytes_out: this._bytesOut,
      bytes_in: this._bytesIn,
      state_gap_p50_ms: percentile(this._gaps, 50),
      state_gap_p95_ms: percentile(this._gaps, 95),
      state_gap_max_ms: Math.round(this._gapMax),
      send_dropped: this._sendDropped,
      buffered_peak_bytes: this._bufferedPeak,
      dropped_steps: this._droppedSteps,
      stall_count: this._stalls,
    };
  }

  /**
   * @param {number} now
   * @returns {void}
   */
  _resetWindow(now) {
    this._windowStart = now;
    this._frames = 0;
    this._steps = 0;
    this._statesIn = 0;
    this._statesOut = 0;
    this._bytesIn = 0;
    this._bytesOut = 0;
    this._sendDropped = 0;
    this._bufferedPeak = 0;
    this._droppedSteps = 0;
    this._stalls = 0;
    this._gapMax = 0;
    this._gaps = [];
    this._lastStateAt = null;
  }
}

/**
 * Nearest-rank percentile over a gap sample set.
 * @param {number[]} values
 * @param {number} rank - 0..100
 * @returns {number} milliseconds, rounded
 */
export function percentile(values, rank) {
  if (!values.length) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  const index = Math.min(sorted.length - 1, Math.ceil((rank / 100) * sorted.length) - 1);
  return Math.round(sorted[Math.max(0, index)]);
}
