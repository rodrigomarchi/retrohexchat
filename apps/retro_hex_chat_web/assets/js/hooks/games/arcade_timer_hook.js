/**
 * ArcadeTimer hook — displays elapsed time since a game started.
 * Reads `data-started-at` (ISO 8601 UTC) and updates the element
 * every second with "M:SS" or "H:MM:SS" format.
 */
const ArcadeTimerHook = {
  mounted() {
    this._startedAt = new Date(this.el.dataset.startedAt);
    this._tick();
    this._interval = setInterval(() => this._tick(), 1000);
  },

  destroyed() {
    if (this._interval) {
      clearInterval(this._interval);
    }
  },

  _tick() {
    const elapsed = Math.floor((Date.now() - this._startedAt.getTime()) / 1000);
    this.el.textContent = this._format(Math.max(0, elapsed));
  },

  _format(totalSeconds) {
    const hours = Math.floor(totalSeconds / 3600);
    const minutes = Math.floor((totalSeconds % 3600) / 60);
    const seconds = totalSeconds % 60;
    const pad = (n) => String(n).padStart(2, "0");

    if (hours > 0) {
      return `${hours}:${pad(minutes)}:${pad(seconds)}`;
    }
    return `${minutes}:${pad(seconds)}`;
  },
};

export default ArcadeTimerHook;
