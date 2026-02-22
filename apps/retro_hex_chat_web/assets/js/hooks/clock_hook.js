/**
 * LiveView hook for displaying the local clock.
 *
 * Renders the current time in HH:MM format and updates every 30 seconds.
 */
import { formatTime, CLOCK_INTERVAL } from "../lib/clock.js";

const ClockHook = {
  mounted() {
    this.el.textContent = formatTime(new Date());
    this._interval = setInterval(() => {
      this.el.textContent = formatTime(new Date());
    }, CLOCK_INTERVAL);
  },

  updated() {
    this.el.textContent = formatTime(new Date());
  },

  destroyed() {
    clearInterval(this._interval);
    this._interval = null;
  },
};

export default ClockHook;
