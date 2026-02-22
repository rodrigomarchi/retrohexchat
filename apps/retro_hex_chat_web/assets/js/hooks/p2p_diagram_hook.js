/**
 * P2PDiagramHook — Drives CSS-class-based animations on the connection diagram.
 *
 * The Elixir component renders the diagram with data-state, data-direction,
 * and data-percent attributes. This hook reads those on mount/update and
 * applies animation classes. Heavy animation is CSS-only (dash scrolling,
 * dot flow, pulse). JS only manages the RAF loop for dot position cycling
 * and respects prefers-reduced-motion.
 */

const DOT_COUNT = 3;
const DOT_CYCLE_MS = 1200;

const P2PDiagramHook = {
  mounted() {
    this._reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    this._rafId = null;
    this._dotStartTime = null;

    this._syncState();
  },

  updated() {
    this._syncState();
  },

  destroyed() {
    this._stopAnimation();
  },

  // --- Private ---

  _syncState() {
    const state = this.el.dataset.state;
    const direction = this.el.dataset.direction || "none";

    // Dot animation needed for transferring / calls with direction
    const needsDots =
      !this._reducedMotion &&
      (state === "transferring" || state === "video-call" || state === "audio-call");

    if (needsDots && direction !== "none") {
      this._startDotAnimation(direction);
    } else {
      this._stopAnimation();
    }
  },

  _startDotAnimation(direction) {
    if (this._rafId) return; // already running

    const dots = this.el.querySelectorAll(".p2p-diagram__dot");
    if (dots.length === 0) return;

    this._dotStartTime = performance.now();

    const animate = (now) => {
      const elapsed = now - this._dotStartTime;
      const cycle = elapsed % DOT_CYCLE_MS;
      const progress = cycle / DOT_CYCLE_MS;

      for (let i = 0; i < Math.min(dots.length, DOT_COUNT); i++) {
        const offset = i / DOT_COUNT;
        let pos;

        if (direction === "bidi") {
          // Bidirectional: ping-pong
          const raw = (progress + offset) % 1;
          pos = raw < 0.5 ? raw * 2 : 2 - raw * 2;
        } else if (direction === "rtl") {
          pos = 1 - ((progress + offset) % 1);
        } else {
          // ltr
          pos = (progress + offset) % 1;
        }

        dots[i].style.left = `${pos * 100}%`;
        dots[i].style.opacity = "1";
      }

      this._rafId = requestAnimationFrame(animate);
    };

    this._rafId = requestAnimationFrame(animate);
  },

  _stopAnimation() {
    if (this._rafId) {
      cancelAnimationFrame(this._rafId);
      this._rafId = null;
    }

    // Hide dots when not animating
    const dots = this.el.querySelectorAll(".p2p-diagram__dot");
    for (const dot of dots) {
      dot.style.opacity = "0";
    }
  },
};

export default P2PDiagramHook;
