/**
 * A Hex Player, in the browser: the keys, the position, the time and the
 * spectrum of one sound or video in a message (`Components.UI.HexPlayer`).
 *
 * A sound is loaded as one that shares its samples with the page
 * (`crossorigin="anonymous"`), so the spectrum can be real. A file whose
 * storage does not allow that refuses to load in that mode; it is loaded again
 * plainly and plays the same, with bars that move without hearing it. The
 * audio graph is only built on the first press of Play — a browser starts no
 * sound before one — and only for a sound the page may read: once an element
 * feeds the graph, a sound the page may not read comes out of it silent.
 *
 * The keys and the glyph are the stylesheet's, drawn from the root's
 * `data-player-state` (`stopped`, `playing`, `paused`).
 *
 * @module hex_player/player_controller
 */
import { formatElapsed, formatLength } from "../hex_device/clock.js";
import { claimSound } from "../hex_device/exclusive.js";
import {
  BAR_COUNT,
  drawFrame,
  fallPeaks,
  readColours,
  simulatedBars,
  spectrumBars,
} from "../hex_device/visualizer.js";
import { log } from "../logger.js";

/** The position slider's steps from the start to the end. */
const SEEK_STEPS = 1000;

/** How high the bars stand while nothing plays: a floor, so the display reads as a spectrum. */
const IDLE_BAR = 0.08;

/** Where a position slider at `value` puts a file `duration` seconds long. */
export function seekTime(value, duration) {
  if (!Number.isFinite(duration) || duration <= 0) return null;
  const step = Math.max(0, Math.min(SEEK_STEPS, Number(value)));
  return Number.isFinite(step) ? (step / SEEK_STEPS) * duration : null;
}

/** The slider's value for `time` seconds into a file `duration` seconds long. */
export function seekValue(time, duration) {
  if (!Number.isFinite(duration) || duration <= 0) return 0;
  return Math.round(Math.max(0, Math.min(1, time / duration)) * SEEK_STEPS);
}

/**
 * @param {HTMLElement} el - the player's root
 * @param {object} [ports]
 * @param {(new () => AudioContext) | null} [ports.AudioContext]
 * @param {(callback: FrameRequestCallback) => number} [ports.requestFrame]
 * @param {(handle: number) => void} [ports.cancelFrame]
 * @param {() => number} [ports.now]
 * @param {(element: Element, name: string, value: string) => void} [ports.mark] - sets an
 *   attribute the server's next patch must keep (the hook's `js().setAttribute`)
 */
export function createPlayer(el, ports = {}) {
  const doc = el.ownerDocument;
  const win = doc.defaultView;
  const AudioContextClass =
    ports.AudioContext === undefined ? (win.AudioContext ?? null) : ports.AudioContext;
  const requestFrame = ports.requestFrame ?? ((callback) => win.requestAnimationFrame(callback));
  const cancelFrame = ports.cancelFrame ?? ((handle) => win.cancelAnimationFrame(handle));
  const now = ports.now ?? (() => win.performance.now());
  const mark = ports.mark ?? ((element, name, value) => element.setAttribute(name, value));

  const media = el.querySelector("[data-player-media]");
  const canvas = el.querySelector("[data-player-scope]");
  const seek = el.querySelector("[data-player-seek]");
  const elapsedField = el.querySelector("[data-player-field='elapsed']");
  const lengthField = el.querySelector("[data-player-field='length']");
  // What the server knows of the length: a recording made in a browser comes
  // without one (its duration reads as infinite), and without it the slider
  // could never move through it.
  const knownLength = Number(el.dataset.playerLength) / 1000;

  let state = "stopped";
  let graph = null;
  let frame = null;
  let peaks = [];
  let colours = null;
  let seeking = false;
  let sound = null;

  function duration() {
    const own = media?.duration;
    if (Number.isFinite(own) && own > 0) return own;
    return Number.isFinite(knownLength) && knownLength > 0 ? knownLength : Number.NaN;
  }

  // A sound the page may read: asked for that way, and not refused.
  const shared = () => media?.hasAttribute("crossorigin") ?? false;

  function showState(name) {
    state = name;
    mark(el, "data-player-state", name);
    if (name === "playing") loop();
    else paint();
  }

  function showTime() {
    if (!media) return;
    if (elapsedField) elapsedField.textContent = formatElapsed(media.currentTime * 1000);
    if (seek && !seeking) seek.value = String(seekValue(media.currentTime, duration()));
  }

  function showLength() {
    if (lengthField && Number.isFinite(media.duration)) {
      lengthField.textContent = formatLength(media.duration);
    }
    showTime();
  }

  function ensureGraph() {
    if (graph || !canvas || !AudioContextClass || !shared()) return graph;
    try {
      const context = new AudioContextClass();
      const source = context.createMediaElementSource(media);
      const analyser = context.createAnalyser();
      analyser.fftSize = 1024;
      analyser.smoothingTimeConstant = 0.7;
      source.connect(analyser);
      analyser.connect(context.destination);
      graph = { context, analyser };
    } catch (error) {
      log.warn("[HexPlayer] the audio graph could not be built; playing without it", error);
      graph = null;
    }
    return graph;
  }

  function fitCanvas() {
    const ratio = win.devicePixelRatio || 1;
    const width = Math.round(canvas.clientWidth * ratio);
    const height = Math.round(canvas.clientHeight * ratio);
    if (width > 0 && height > 0 && (canvas.width !== width || canvas.height !== height)) {
      canvas.width = width;
      canvas.height = height;
    }
  }

  function bars() {
    if (state !== "playing") return new Array(BAR_COUNT).fill(IDLE_BAR);
    if (graph) {
      const data = new Uint8Array(graph.analyser.frequencyBinCount);
      graph.analyser.getByteFrequencyData(data);
      return spectrumBars(data, BAR_COUNT);
    }
    return simulatedBars(now(), BAR_COUNT);
  }

  function paint() {
    if (!canvas) return;
    fitCanvas();
    colours ??= readColours(canvas);
    const next = bars();
    peaks = state === "playing" ? fallPeaks(peaks, next) : [];
    drawFrame(canvas, { kind: "spectrum", bars: next, peaks }, colours);
  }

  function loop() {
    if (frame !== null) cancelFrame(frame);
    frame = requestFrame(() => {
      frame = null;
      if (state !== "playing") return;
      paint();
      showTime();
      loop();
    });
  }

  function play() {
    if (!media) return;
    sound?.announce();
    if (ensureGraph()) {
      Promise.resolve(graph.context.resume?.()).catch((error) =>
        log.warn("[HexPlayer] the audio could not resume", error),
      );
    }
    Promise.resolve(media.play()).catch((error) => {
      // Refused (no press yet, or a file that will not load): it stays where it is.
      log.warn("[HexPlayer] the browser did not play this file", error);
      if (state === "playing") showState(media.currentTime > 0 ? "paused" : "stopped");
    });
  }

  function pause() {
    media?.pause();
  }

  function stop() {
    if (!media) return;
    media.pause();
    media.currentTime = 0;
    showState("stopped");
    showTime();
  }

  function toggleFullscreen() {
    if (doc.fullscreenElement === el) {
      Promise.resolve(doc.exitFullscreen?.()).catch((error) =>
        log.warn("[HexPlayer] full screen could not be left", error),
      );
    } else {
      Promise.resolve(el.requestFullscreen?.()).catch((error) =>
        log.warn("[HexPlayer] full screen was refused", error),
      );
    }
  }

  const commands = {
    play,
    pause,
    stop,
    mute: () => {
      media.muted = !media.muted;
      const key = el.querySelector("[data-player-command='mute']");
      if (key) mark(key, "aria-pressed", String(media.muted));
    },
    fullscreen: toggleFullscreen,
  };

  function onClick(event) {
    const key = event.target.closest?.("[data-player-command]");
    if (!key || !el.contains(key) || !media) return;
    const command = commands[key.dataset.playerCommand];
    if (!command) return;
    try {
      command();
    } catch (error) {
      log.error(`[HexPlayer] ${key.dataset.playerCommand} failed`, error);
    }
  }

  function onSeekInput() {
    seeking = true;
    const time = seekTime(seek.value, duration());
    if (time !== null) {
      media.currentTime = time;
      if (elapsedField) elapsedField.textContent = formatElapsed(time * 1000);
    }
  }

  function onSeekDone() {
    seeking = false;
  }

  // The file refused to be read by the page: load it again plainly. Any
  // other error leaves the player stopped.
  function onError() {
    if (shared() && !graph) {
      media.removeAttribute("crossorigin");
      media.load();
      return;
    }
    log.warn("[HexPlayer] this file could not be played");
    showState("stopped");
  }

  const mediaListeners = {
    playing: () => showState("playing"),
    pause: () => {
      if (state === "playing") showState(media.currentTime > 0 ? "paused" : "stopped");
    },
    ended: () => {
      media.currentTime = 0;
      showState("stopped");
      showTime();
    },
    loadedmetadata: showLength,
    durationchange: showLength,
    timeupdate: () => (state === "playing" ? null : showTime()),
    error: onError,
  };

  return {
    mount() {
      if (!media) return;
      el.addEventListener("click", onClick);
      seek?.addEventListener("input", onSeekInput);
      seek?.addEventListener("change", onSeekDone);
      for (const [name, listener] of Object.entries(mediaListeners)) {
        media.addEventListener(name, listener);
      }
      sound = claimSound(win, el, pause);
      if (media.readyState >= 1) showLength();
      showState("stopped");
    },
    /** What the player is doing, for a test. */
    state: () => ({ state, graph: graph !== null, shared: shared(), muted: media?.muted }),
    destroy() {
      if (frame !== null) cancelFrame(frame);
      frame = null;
      sound?.release();
      el.removeEventListener("click", onClick);
      seek?.removeEventListener("input", onSeekInput);
      seek?.removeEventListener("change", onSeekDone);
      if (media) {
        for (const [name, listener] of Object.entries(mediaListeners)) {
          media.removeEventListener(name, listener);
        }
        media.pause();
      }
      Promise.resolve(graph?.context.close?.()).catch((error) =>
        log.debug("[HexPlayer] the audio context did not close", error),
      );
      graph = null;
    },
  };
}
