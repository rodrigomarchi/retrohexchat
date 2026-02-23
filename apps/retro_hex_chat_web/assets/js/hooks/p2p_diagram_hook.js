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

const DEFAULT_DOT_COUNT = 3;
const DEFAULT_CYCLE_MS = 1200;

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

    // Restart animation when dot count or cycle changes
    const dotCount = parseInt(this.el.dataset.dots, 10) || DEFAULT_DOT_COUNT;
    const cycleMs = parseInt(this.el.dataset.cycleMs, 10) || DEFAULT_CYCLE_MS;

    const configChanged = this._dotCount !== dotCount || this._cycleMs !== cycleMs;

    this._dotCount = dotCount;
    this._cycleMs = cycleMs;
    this._state = state;

    // Dot animation needed for transferring / calls with direction
    const needsDots =
      !this._reducedMotion &&
      (state === "transferring" || state === "video-call" || state === "audio-call");

    if (needsDots && direction !== "none") {
      if (configChanged) this._stopAnimation();
      this._startDotAnimation(direction);
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

        const offset = i / dotCount;
        let pos;

        if (direction === "bidi") {
          const raw = (progress + offset) % 1;
          pos = raw < 0.5 ? raw * 2 : 2 - raw * 2;
        } else if (direction === "rtl") {
          pos = 1 - ((progress + offset) % 1);
        } else {
          pos = (progress + offset) % 1;
        }

        dots[i].style.left = `${pos * 100}%`;
        dots[i].style.opacity = "1";

        // Audio wave: modulate dot size and Y position
        if (isAudio) {
          const wave = Math.sin((progress + offset) * Math.PI * 4);
          const size = 6 + wave * 3; // 3px to 9px
          dots[i].style.width = `${size}px`;
          dots[i].style.height = `${size}px`;
          dots[i].style.top = `${1 - wave * 2}px`;
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
