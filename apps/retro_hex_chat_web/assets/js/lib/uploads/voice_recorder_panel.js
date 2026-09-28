/**
 * The composer's recording strip: the microphone button, the running clock, and
 * the two ways out of a take.
 *
 * The server renders every element and every word of this — the strip is marked
 * `phx-update="ignore"` so a keystroke's patch of the composer cannot restore
 * the template over a take in progress. What this controller does is decide
 * which of those elements is showing and write the clock into one of them,
 * which is why none of the text below is in this file.
 *
 * A browser that cannot record hides the strip outright. The alternative is a
 * button that asks for a microphone and then apologises, and the decision is
 * already made by then: on a desktop the file picker was always the better
 * answer.
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
  const listeners = [];

  const recorder = build({
    onState: render,
    onError: showError,
    onRecorded,
  });

  function find(selector) {
    return el.querySelector(selector);
  }

  function group(name) {
    return find(`[data-voice-state="${name}"]`);
  }

  function render({ recording, elapsedMs }) {
    toggle(group("idle"), !recording);
    toggle(group("recording"), recording);

    const elapsed = find("[data-voice-elapsed]");
    if (elapsed) elapsed.textContent = clock(elapsedMs);

    if (recording) clearError();
  }

  function toggle(node, shown) {
    if (node) node.hidden = !shown;
  }

  function clearError() {
    el.querySelectorAll("[data-voice-error]").forEach((node) => {
      node.hidden = true;
    });
  }

  function showError(code) {
    clearError();
    toggle(find(`[data-voice-error="${code}"]`), true);
  }

  function run(action) {
    if (action === "start") return recorder.start();
    if (action === "stop") return recorder.stop();

    return recorder.cancel();
  }

  function bind(action) {
    const node = find(`[data-voice-action="${action}"]`);
    if (!node) return;

    const listener = (event) => {
      event.preventDefault();
      run(action);
    };

    node.addEventListener("click", listener);
    listeners.push([node, listener]);
  }

  return {
    mount() {
      if (!recorder.supported()) {
        el.hidden = true;
        return;
      }

      el.hidden = false;
      ACTIONS.forEach(bind);
      render({ recording: false, elapsedMs: 0 });
    },

    destroy() {
      recorder.destroy();

      while (listeners.length > 0) {
        const [node, listener] = listeners.pop();
        node.removeEventListener("click", listener);
      }
    },
  };
}
