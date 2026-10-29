/**
 * Hex Radio's player, in the browser: the stream, the volume, the equaliser,
 * the LCD and the time on it.
 *
 * A station is tried first as one that shares its sound with the page
 * (`crossOrigin = "anonymous"`): its samples then pass through the preamp, the
 * equaliser and the analyser, and the spectrum is real. A station whose server
 * does not allow that refuses to load at all in that mode, so it is tried
 * again on a second, plain element the page never reads from — it plays, the
 * bars move without hearing it, and the equaliser says it cannot reach it. Two
 * elements, because once an element feeds the audio graph everything it plays
 * goes through it, and a stream the page may not read comes out of it silent.
 *
 * The server says which station (`play(station)`); everything after that is
 * here. The LCD's lamps and glyph are the stylesheet's, drawn from the root's
 * `data-radio-state` and `data-radio-mode`.
 *
 * @module radio/radio_controller
 */
import { t } from "../i18n.js";
import { log } from "../logger.js";
import { createEqualizer, gainFor, preampGain } from "./equalizer.js";
import { keepVolume, readVolume } from "./preferences.js";
import {
  BAR_COUNT,
  drawCurve,
  drawFrame,
  fallPeaks,
  readColours,
  scopePoints,
  simulatedBars,
  spectrumBars,
} from "./visualizer.js";

/** Elapsed time as the display shows it: `m:ss`, or `h:mm:ss` past an hour. */
export function formatElapsed(ms) {
  const total = Math.max(0, Math.floor(ms / 1000));
  const hours = Math.floor(total / 3600);
  const minutes = Math.floor((total % 3600) / 60);
  const seconds = String(total % 60).padStart(2, "0");
  return hours > 0
    ? `${hours}:${String(minutes).padStart(2, "0")}:${seconds}`
    : `${minutes}:${seconds}`;
}

const STATE_TEXT = () => ({
  stopped: t("Stopped"),
  connecting: t("Connecting…"),
  playing: t("Playing"),
  muted: t("Sound muted"),
  failed: t("No sound is coming from this radio."),
});

/**
 * @param {HTMLElement} el - the hook root: the player, the equaliser and the list inside it
 * @param {object} ports
 * @param {(name: string, text: string) => void} ports.status - writes a status field
 * @param {() => Storage | null} [ports.storage] - read when used: it may throw
 * @param {() => HTMLAudioElement} [ports.createAudio]
 * @param {(new () => AudioContext) | null} [ports.AudioContext]
 * @param {(callback: FrameRequestCallback) => number} [ports.requestFrame]
 * @param {(handle: number) => void} [ports.cancelFrame]
 * @param {() => number} [ports.now]
 * @param {(element: Element, name: string, value: string) => void} [ports.mark] - sets an
 *   attribute the server's next patch must keep (the hook's `js().setAttribute`)
 */
export function createRadio(el, ports) {
  const win = el.ownerDocument.defaultView;
  const storage = ports.storage ?? (() => null);
  const createAudio = ports.createAudio ?? (() => el.ownerDocument.createElement("audio"));
  const AudioContextClass =
    ports.AudioContext === undefined ? (win.AudioContext ?? null) : ports.AudioContext;
  const requestFrame = ports.requestFrame ?? ((callback) => win.requestAnimationFrame(callback));
  const cancelFrame = ports.cancelFrame ?? ((handle) => win.cancelAnimationFrame(handle));
  const now = ports.now ?? (() => win.performance.now());
  const mark = ports.mark ?? ((element, name, value) => element.setAttribute(name, value));

  const canvas = el.querySelector("[data-radio-scope]");
  const curve = el.querySelector("[data-radio-curve]");
  const equalizerPanel = el.querySelector("#hex-radio-equalizer");
  const volumeInput = el.querySelector("[data-radio-volume]");

  // The element whose sound the page reads, and the one it never does.
  const shared = createAudio();
  shared.crossOrigin = "anonymous";
  shared.preload = "none";
  const plain = createAudio();
  plain.preload = "none";

  let graph = null;
  let station = null;
  let state = "stopped";
  let mode = null;
  let attempt = 0;
  let startedAt = null;
  let volume = readVolume(storage);
  let muted = false;
  let visual = "spectrum";
  let peaks = [];
  let frame = null;
  let colours = null;
  let equalizerOn = true;
  let preamp = 0;
  const bands = new Array(10).fill(0);

  function showState(name) {
    state = name;
    const text = STATE_TEXT();
    ports.status("state", muted && name === "playing" ? text.muted : text[name]);
    mark(el, "data-radio-state", name);
    mark(el, "data-radio-mode", name === "playing" ? mode : "none");
    showEqualizerNote();
    // Anything but playing clears the display: the last frame drawn was music.
    if (name !== "playing") paint();
  }

  function press(toggle, on) {
    const key = el.querySelector(`[data-radio-toggle='${toggle}']`);
    if (key) mark(key, "aria-pressed", String(on));
  }

  function showEqualizerNote() {
    const note = el.querySelector("[data-radio-field='eq-note']");
    const closed = state === "playing" && mode === "plain";
    if (note) {
      note.textContent = closed
        ? t("This radio does not share its sound, so the equalizer cannot change it.")
        : "";
    }
    for (const slider of el.querySelectorAll("[data-radio-band]")) slider.disabled = closed;
  }

  function showTime() {
    const field = el.querySelector("[data-radio-field='time']");
    if (field) field.textContent = startedAt === null ? "--:--" : formatElapsed(now() - startedAt);
  }

  function ensureGraph() {
    if (graph || !AudioContextClass) return graph;
    try {
      const context = new AudioContextClass();
      const source = context.createMediaElementSource(shared);
      const pre = context.createGain();
      const equalizer = createEqualizer(context);
      const gain = context.createGain();
      const analyser = context.createAnalyser();
      analyser.fftSize = 2048;
      analyser.smoothingTimeConstant = 0.75;
      source.connect(pre);
      pre.connect(equalizer.input);
      equalizer.output.connect(gain);
      gain.connect(analyser);
      analyser.connect(context.destination);
      graph = { context, pre, equalizer, gain, analyser };
      applyEqualizer();
    } catch (error) {
      log.warn("[HexRadio] the audio graph could not be built; playing without it", error);
      graph = null;
    }
    return graph;
  }

  // Off, the bands and the preamp keep their places and the sound passes flat.
  function applyEqualizer() {
    if (!graph) return;
    bands.forEach((value, band) => graph.equalizer.set(band, equalizerOn ? value : 0));
    graph.pre.gain.value = equalizerOn ? preampGain(preamp) : 1;
  }

  function applyVolume() {
    const level = muted ? 0 : volume / 100;
    if (graph) graph.gain.gain.value = level;
    // The shared element feeds the graph, which sets the level; the plain
    // one is heard directly.
    shared.volume = graph ? 1 : level;
    plain.volume = level;
  }

  function release(audio) {
    audio.onplaying = null;
    audio.onerror = null;
    audio.pause();
    if (audio.getAttribute("src")) {
      audio.removeAttribute("src");
      // Drops the connection: a paused live stream keeps downloading.
      audio.load();
    }
  }

  function start(audio, nextMode, onFail) {
    const mine = attempt;
    audio.onplaying = () => {
      if (mine !== attempt) return;
      mode = nextMode;
      startedAt ??= now();
      showState("playing");
      loop();
    };
    audio.onerror = () => {
      if (mine === attempt) onFail();
    };
    audio.src = station.stream;
    applyVolume();
    Promise.resolve(audio.play()).catch((error) => {
      if (mine !== attempt) return;
      if (error?.name === "NotAllowedError") {
        // Stopped, as it is: the next press of Play is the one the browser waits for.
        log.warn("[HexRadio] the browser wants a press before playing", error);
        stopAll();
        showState("stopped");
      }
      // Any other refusal also arrives as the element's error event.
    });
  }

  function play(next) {
    if (next) station = next;
    if (!station?.stream) return;
    stopAll();
    attempt += 1;
    startedAt = null;
    showState("connecting");

    if (ensureGraph()) {
      Promise.resolve(graph.context.resume?.()).catch((error) =>
        log.warn("[HexRadio] the audio could not resume", error),
      );
      start(shared, "shared", () => {
        release(shared);
        start(plain, "plain", failed);
      });
    } else {
      start(plain, "plain", failed);
    }
  }

  function failed() {
    log.warn(`[HexRadio] ${station?.name ?? "a station"} could not be played`);
    stopAll();
    showState("failed");
  }

  function stopAll() {
    release(shared);
    release(plain);
    mode = null;
    startedAt = null;
    if (frame !== null) cancelFrame(frame);
    frame = null;
    peaks = [];
    paint();
    showTime();
  }

  function stop() {
    attempt += 1;
    stopAll();
    showState("stopped");
  }

  function currentFrame() {
    if (state !== "playing") return { kind: visual, bars: [], peaks: [], points: [] };
    const analyser = mode === "shared" ? graph?.analyser : null;

    if (visual === "scope") {
      const width = canvas.width;
      const height = canvas.height;
      if (analyser) {
        const data = new Uint8Array(analyser.fftSize);
        analyser.getByteTimeDomainData(data);
        return { kind: "scope", points: scopePoints(data, width, height) };
      }
      const bars = simulatedBars(now(), 64);
      const data = Uint8Array.from(bars, (bar, i) => 128 + (i % 2 ? -1 : 1) * bar * 90);
      return { kind: "scope", points: scopePoints(data, width, height) };
    }

    let bars;
    if (analyser) {
      const data = new Uint8Array(analyser.frequencyBinCount);
      analyser.getByteFrequencyData(data);
      bars = spectrumBars(data, BAR_COUNT);
    } else {
      bars = simulatedBars(now(), BAR_COUNT);
    }
    peaks = fallPeaks(peaks, bars);
    return { kind: "spectrum", bars, peaks };
  }

  function fitCanvas(target) {
    const ratio = win.devicePixelRatio || 1;
    const width = Math.round(target.clientWidth * ratio);
    const height = Math.round(target.clientHeight * ratio);
    if (width > 0 && height > 0 && (target.width !== width || target.height !== height)) {
      target.width = width;
      target.height = height;
    }
  }

  function paint() {
    if (!canvas) return;
    fitCanvas(canvas);
    colours ??= readColours(canvas);
    drawFrame(canvas, currentFrame(), colours);
    drawEqualizerCurve();
  }

  // The curve is drawn while its panel is open, and only then: shut, the
  // canvas has no size to draw at.
  function drawEqualizerCurve() {
    if (!curve || equalizerPanel?.dataset.open !== "true") return;
    fitCanvas(curve);
    colours ??= readColours(canvas ?? curve);
    drawCurve(curve, bands, colours, equalizerOn);
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

  function setVolume(value) {
    const next = Number.parseInt(value, 10);
    if (!Number.isFinite(next)) return;
    volume = Math.max(0, Math.min(100, next));
    keepVolume(storage, volume);
    applyVolume();
  }

  function setBand(band, value) {
    if (band === "preamp") {
      preamp = gainFor(value);
    } else {
      const index = Number(band);
      if (!(index >= 0 && index < bands.length)) return;
      bands[index] = gainFor(value);
    }
    applyEqualizer();
    drawEqualizerCurve();
  }

  function flat() {
    bands.fill(0);
    preamp = 0;
    applyEqualizer();
    for (const slider of el.querySelectorAll("[data-radio-band]")) slider.value = "0";
    drawEqualizerCurve();
  }

  const commands = {
    play: () => (state === "playing" || state === "connecting" ? null : play()),
    stop,
    mute: () => {
      muted = !muted;
      press("mute", muted);
      applyVolume();
      if (state === "playing") showState("playing");
    },
    "eq-power": () => {
      equalizerOn = !equalizerOn;
      press("eq-power", equalizerOn);
      applyEqualizer();
      drawEqualizerCurve();
    },
    flat,
    // Named, it chooses; bare (a click on the display), it turns to the other.
    visual: ({ visual: next }) => {
      if (next === "spectrum" || next === "scope") visual = next;
      else visual = visual === "spectrum" ? "scope" : "spectrum";
      peaks = [];
      paint();
    },
  };

  function run(name, detail = {}) {
    const command = commands[name];
    if (!command) return;
    try {
      command(detail);
    } catch (error) {
      log.error(`[HexRadio] ${name} failed`, error);
    }
  }

  function onCommand(event) {
    run(event.detail?.command, event.detail ?? {});
  }

  function onInput(event) {
    const target = event.target;
    if (target.matches?.("[data-radio-volume]")) setVolume(target.value);
    else if (target.matches?.("[data-radio-band]")) setBand(target.dataset.radioBand, target.value);
  }

  // The EQ switch opens its panel through LiveView; the curve is drawn once
  // the panel has a size.
  function onClick(event) {
    if (event.target.closest?.("[data-testid='hex-radio-equalizer-toggle']")) {
      requestFrame(drawEqualizerCurve);
    }
  }

  function onKey(event) {
    if (event.target.closest?.("input, textarea, select, button, [contenteditable='true']")) return;
    if (event.ctrlKey || event.metaKey || event.altKey) return;
    const key = String(event.key).toLowerCase();
    if (key === " ") {
      event.preventDefault();
      event.stopPropagation();
      run(state === "playing" || state === "connecting" ? "stop" : "play");
    } else if (key === "m") {
      event.preventDefault();
      event.stopPropagation();
      run("mute");
    }
  }

  return {
    mount() {
      if (volumeInput) volumeInput.value = String(volume);
      applyVolume();
      el.addEventListener("radio:command", onCommand);
      el.addEventListener("input", onInput);
      el.addEventListener("click", onClick);
      el.addEventListener("keydown", onKey);
      showState("stopped");
      paint();
    },
    /** Plays `next`, the station the server chose. */
    play,
    /** What the player is doing, for a test. */
    state: () => ({
      state,
      mode,
      volume,
      muted,
      visual,
      equalizerOn,
      preamp,
      bands: [...bands],
      station: station?.id ?? null,
    }),
    destroy() {
      attempt += 1;
      stopAll();
      el.removeEventListener("radio:command", onCommand);
      el.removeEventListener("input", onInput);
      el.removeEventListener("click", onClick);
      el.removeEventListener("keydown", onKey);
      Promise.resolve(graph?.context.close?.()).catch((error) =>
        log.debug("[HexRadio] the audio context did not close", error),
      );
      graph = null;
    },
  };
}
