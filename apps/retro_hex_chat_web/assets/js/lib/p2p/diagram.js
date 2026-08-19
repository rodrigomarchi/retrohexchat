/**
 * The dot maths for the P2P connection diagram — pure, no DOM.
 *
 * The heavy animation is CSS; JS only cycles dot positions along the link. The
 * diagram hook owns the requestAnimationFrame loop and the dot elements; this
 * module decides where each dot sits and how the audio mode modulates it, so
 * the three directions and the wave can be tested without a frame.
 *
 * @module p2p/diagram
 */

export const DEFAULT_DOT_COUNT = 3;
export const DEFAULT_CYCLE_MS = 1200;

/**
 * A dot's position along the link, in [0, 1].
 *
 * @param {"bidi"|"rtl"|"ltr"|string} direction
 * @param {number} progress cycle progress in [0, 1)
 * @param {number} offset the dot's phase offset
 * @returns {number}
 */
export function dotPosition(direction, progress, offset) {
  if (direction === "bidi") {
    const raw = (progress + offset) % 1;
    return raw < 0.5 ? raw * 2 : 2 - raw * 2;
  }
  if (direction === "rtl") {
    return 1 - ((progress + offset) % 1);
  }
  return (progress + offset) % 1;
}

/**
 * The inline styles for one visible dot at a moment in the cycle.
 *
 * @param {object} params
 * @param {string} params.direction
 * @param {number} params.progress cycle progress in [0, 1)
 * @param {number} params.index the dot's index
 * @param {number} params.dotCount
 * @param {boolean} params.isAudio audio mode modulates size and vertical wave
 * @returns {{left: string, opacity: string, width?: string, height?: string, top?: string}}
 */
export function dotFrame({ direction, progress, index, dotCount, isAudio }) {
  const offset = index / dotCount;
  const pos = dotPosition(direction, progress, offset);
  const frame = { left: `${pos * 100}%`, opacity: "1" };

  if (isAudio) {
    const wave = Math.sin((progress + offset) * Math.PI * 4);
    const size = 6 + wave * 3; // 3px to 9px
    frame.width = `${size}px`;
    frame.height = `${size}px`;
    frame.top = `${1 - wave * 2}px`;
  }

  return frame;
}

/**
 * The animation configuration read from the diagram element's dataset.
 *
 * `needsDots` is the reduced-motion and state gate; the caller still checks the
 * direction is not "none" before starting, as the original did.
 *
 * @param {DOMStringMap} dataset
 * @param {boolean} reducedMotion
 * @returns {{dotCount: number, cycleMs: number, state: string, direction: string, needsDots: boolean}}
 */
export function diagramConfig(dataset, reducedMotion) {
  const dotCount = parseInt(dataset.dots, 10) || DEFAULT_DOT_COUNT;
  const cycleMs = parseInt(dataset.cycleMs, 10) || DEFAULT_CYCLE_MS;
  const state = dataset.state;
  const direction = dataset.direction || "none";
  const needsDots =
    !reducedMotion &&
    (state === "transferring" || state === "video-call" || state === "audio-call");

  return { dotCount, cycleMs, state, direction, needsDots };
}

/**
 * The diagram animator — the RAF loop, dot elements and state sync, no LiveView.
 *
 * The per-frame maths is `dotFrame`; this owns the loop that applies it, creates
 * the dot spans, and starts/stops the animation as the dataset state changes.
 * The hook binds it and calls `sync()` on mount and update.
 *
 * @param {HTMLElement} el the diagram element
 * @param {{matchMedia?: Function, raf?: Function, cancelRaf?: Function, now?: Function}} [deps]
 * @returns {{sync(): void, stop(): void}}
 */
export function createDiagramAnimator(el, deps = {}) {
  const matchMedia = deps.matchMedia || ((q) => window.matchMedia(q));
  const raf = deps.raf || ((cb) => requestAnimationFrame(cb));
  const cancelRaf = deps.cancelRaf || ((id) => cancelAnimationFrame(id));
  const now = deps.now || (() => performance.now());

  const reducedMotion = matchMedia("(prefers-reduced-motion: reduce)").matches;
  let rafId = null;
  let dotStartTime = null;
  let dotCount;
  let cycleMs;
  let state;

  function ensureDots() {
    const container = el.querySelector(".p2p-diagram__dots");
    if (!container) return;

    const existing = container.querySelectorAll(".p2p-diagram__dot").length;
    for (let i = existing; i < dotCount; i++) {
      const span = document.createElement("span");
      span.className = "p2p-diagram__dot";
      container.appendChild(span);
    }
  }

  function startDotAnimation(direction) {
    if (rafId) return; // already running

    ensureDots();
    const dots = el.querySelectorAll(".p2p-diagram__dot");
    if (dots.length === 0) return;

    dotStartTime = now();
    const isAudio = state === "audio-call";

    const animate = (frameNow) => {
      const progress = ((frameNow - dotStartTime) % cycleMs) / cycleMs;
      const visibleDots = Math.min(dots.length, dotCount);

      for (let i = 0; i < dots.length; i++) {
        if (i >= visibleDots) {
          dots[i].style.opacity = "0";
          continue;
        }

        const frame = dotFrame({ direction, progress, index: i, dotCount, isAudio });
        dots[i].style.left = frame.left;
        dots[i].style.opacity = frame.opacity;

        if (isAudio) {
          dots[i].style.width = frame.width;
          dots[i].style.height = frame.height;
          dots[i].style.top = frame.top;
        }
      }

      rafId = raf(animate);
    };

    rafId = raf(animate);
  }

  function stop() {
    if (rafId) {
      cancelRaf(rafId);
      rafId = null;
    }

    for (const dot of el.querySelectorAll(".p2p-diagram__dot")) {
      dot.style.opacity = "0";
      dot.style.width = "";
      dot.style.height = "";
      dot.style.top = "";
    }
  }

  return {
    sync() {
      const config = diagramConfig(el.dataset, reducedMotion);
      const configChanged = dotCount !== config.dotCount || cycleMs !== config.cycleMs;

      dotCount = config.dotCount;
      cycleMs = config.cycleMs;
      state = config.state;

      if (config.needsDots && config.direction !== "none") {
        if (configChanged) stop();
        startDotAnimation(config.direction);
      } else {
        stop();
      }
    },
    stop,
  };
}
