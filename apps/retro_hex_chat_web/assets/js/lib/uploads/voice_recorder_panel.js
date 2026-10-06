/**
 * The composer's microphone: the toolbar button at rest, and the take it starts
 * — the running clock and the two ways out of it, Discard and Send.
 *
 * The server renders every element and every word of this — the recorder is
 * marked `phx-update="ignore"` so a keystroke's patch of the composer cannot
 * restore the template over a take in progress. What this controller does is
 * decide which group is showing and write the clock into one element; the
 * composer row's CSS reads the take's group being shown to put the take where
 * the input was. Nothing is written to the recorder's own `data-*` attributes,
 * because the server rewrites those even on an ignored element. None of the
 * text is in this file; a failure is reported by name and worded on the
 * server.
 *
 * A browser that cannot record hides the microphone outright. The alternative
 * is a button that asks for a microphone and then apologises.
 */
import { createVoiceRecorder } from "./voice_recorder.js";

const ACTIONS = ["start", "stop", "cancel"];

/**
 * A duration as a clock reading.
 *
 * @param {number} ms elapsed milliseconds
 * @returns {string} `m:ss`
 */
export function clock(ms) {
  const total = Math.max(Math.floor((Number(ms) || 0) / 1_000), 0);

  return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, "0")}`;
}

export function createVoiceRecorderPanel(el, ports = {}) {
  const build = ports.createRecorder ?? createVoiceRecorder;
  const onRecorded = ports.onRecorded ?? (() => {});
  const onError = ports.onError ?? (() => {});
  const listeners = [];
  let wasRecording = false;

  const recorder = build({
    onState: render,
    onError,
    onRecorded,
  });

  function find(selector) {
    return el.querySelector(selector);
  }

  function group(name) {
    return find(`[data-voice-state="${name}"]`);
  }

  function render({ recording, elapsedMs }) {
    // Read before hiding: the button that was pressed is about to disappear,
    // and focus inside the recorder is what says the keyboard is here at all.
    const focused = el.contains(document.activeElement);

    toggle(group("idle"), !recording);
    toggle(group("recording"), recording);

    const elapsed = find("[data-voice-elapsed]");
    if (elapsed) elapsed.textContent = clock(elapsedMs);

    // The keyboard goes to the control that ends the take, and back to the
    // microphone after it — but only if it was here; a take that ends itself
    // at the ceiling does not pull focus from wherever the reader went.
    if (recording !== wasRecording && focused) {
      find(`[data-voice-action="${recording ? "stop" : "start"}"]`)?.focus?.();
    }

    wasRecording = recording;
  }

  function toggle(node, shown) {
    if (node) node.hidden = !shown;
  }

  function run(action) {
    if (action === "start") return recorder.start();
    if (action === "stop") return recorder.stop();

    return recorder.cancel();
  }

  function listen(node, type, listener) {
    node.addEventListener(type, listener);
    listeners.push([node, type, listener]);
  }

  function bind(action) {
    const node = find(`[data-voice-action="${action}"]`);
    if (!node) return;

    listen(node, "click", (event) => {
      event.preventDefault();
      run(action);
    });
  }

  return {
    mount() {
      if (!recorder.supported()) {
        el.hidden = true;
        return;
      }

      el.hidden = false;
      ACTIONS.forEach(bind);

      // A take owns Escape while it runs: the press is consumed so neither the
      // window manager nor the server's window-level Escape ladder acts on it.
      listen(el, "keydown", (event) => {
        if (event.key === "Escape" && recorder.recording()) {
          event.preventDefault();
          event.stopPropagation();
          recorder.cancel();
        }
      });

      render({ recording: false, elapsedMs: 0 });
    },

    destroy() {
      recorder.destroy();

      while (listeners.length > 0) {
        const [node, type, listener] = listeners.pop();
        node.removeEventListener(type, listener);
      }
    },
  };
}
