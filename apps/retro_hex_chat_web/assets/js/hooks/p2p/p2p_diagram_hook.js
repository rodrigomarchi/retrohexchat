/**
 * P2PDiagramHook — Drives CSS-class-based animations on the connection diagram.
 *
 * The Elixir component renders the diagram with data-state, data-direction,
 * data-percent, data-dots, and data-cycle-ms attributes. This hook reads those
 * on mount/update and applies animation classes. Heavy animation is CSS-only
 * (dash scrolling, glow, pulse). JS manages the RAF loop for dot position
 * cycling with state-specific behaviors (wave effect for audio, variable dot
 * count/speed for transfers and video).
 */
import { dotFrame, diagramConfig } from "../../lib/p2p/diagram.js";

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
    const config = diagramConfig(this.el.dataset, this._reducedMotion);

    // Restart animation when dot count or cycle changes
    const configChanged = this._dotCount !== config.dotCount || this._cycleMs !== config.cycleMs;

    this._dotCount = config.dotCount;
    this._cycleMs = config.cycleMs;
    this._state = config.state;

    if (config.needsDots && config.direction !== "none") {
      if (configChanged) this._stopAnimation();
      this._startDotAnimation(config.direction);
    } else {
      this._stopAnimation();
    }
  },

  _startDotAnimation(direction) {
    if (this._rafId) return; // already running

    this._ensureDots();
    const dots = this.el.querySelectorAll(".p2p-diagram__dot");
    if (dots.length === 0) return;

    this._dotStartTime = performance.now();
    const dotCount = this._dotCount;
    const cycleMs = this._cycleMs;
    const isAudio = this._state === "audio-call";

    const animate = (now) => {
      const elapsed = now - this._dotStartTime;
      const cycle = elapsed % cycleMs;
      const progress = cycle / cycleMs;

      const visibleDots = Math.min(dots.length, dotCount);
      for (let i = 0; i < dots.length; i++) {
        if (i >= visibleDots) {
          dots[i].style.opacity = "0";
          continue;
        }

        const frame = dotFrame({ direction, progress, index: i, dotCount, isAudio });

        dots[i].style.left = frame.left;
        dots[i].style.opacity = frame.opacity;

        // Audio wave: modulate dot size and Y position
        if (isAudio) {
          dots[i].style.width = frame.width;
          dots[i].style.height = frame.height;
          dots[i].style.top = frame.top;
        }
      }

      this._rafId = requestAnimationFrame(animate);
    };

    this._rafId = requestAnimationFrame(animate);
  },

  /** Ensure enough DOM dot elements exist for the configured count */
  _ensureDots() {
    const container = this.el.querySelector(".p2p-diagram__dots");
    if (!container) return;

    const existing = container.querySelectorAll(".p2p-diagram__dot").length;
    for (let i = existing; i < this._dotCount; i++) {
      const span = document.createElement("span");
      span.className = "p2p-diagram__dot";
      container.appendChild(span);
    }
  },

  _stopAnimation() {
    if (this._rafId) {
      cancelAnimationFrame(this._rafId);
      this._rafId = null;
    }

    // Hide dots and reset styles when not animating
    const dots = this.el.querySelectorAll(".p2p-diagram__dot");
    for (const dot of dots) {
      dot.style.opacity = "0";
      dot.style.width = "";
      dot.style.height = "";
      dot.style.top = "";
    }
  },
};

export default P2PDiagramHook;
