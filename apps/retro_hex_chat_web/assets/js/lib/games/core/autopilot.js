/**
 * A seat played by the game's own AI through the keyboard: the controller
 * decides, and the autopilot presses and releases the keys a person would, so
 * the match runs exactly as it does under a person's hands — the same key
 * handlers, the same inputs on the wire.
 *
 * Nothing turns it on but a page that sets `globalThis.__rhcAutopilot` before
 * the game loads — the video director films matches this way — and only on a
 * page the e2e server built: it carries `<meta name="rhc-autopilot">`, which no
 * other build prints, so a ranked match can never be handed to the computer.
 *
 * @module games/core/autopilot
 */

/** The global a page sets to have its seat played: `{ difficulty }`. */
export const AUTOPILOT_GLOBAL = "__rhcAutopilot";

/** The meta only the e2e server's pages carry. */
export const AUTOPILOT_META = 'meta[name="rhc-autopilot"]';

/**
 * The autopilot this page asked for, or null — always null on a page not
 * built by the e2e server.
 * @param {object} [scope]
 * @returns {{ difficulty: string|undefined }|null}
 */
export function autopilotRequest(scope = globalThis) {
  if (!scope?.document?.querySelector?.(AUTOPILOT_META)) return null;
  const request = scope[AUTOPILOT_GLOBAL];
  if (!request || typeof request !== "object") return null;
  return { difficulty: typeof request.difficulty === "string" ? request.difficulty : undefined };
}

/**
 * @param {object} options
 * @param {{ nextInputs: (observed: object) => object|null }} options.controller
 * @param {Record<string, readonly string[]>} options.inputs - each input's keys, the first pressed
 * @param {() => object} options.observe - what the controller is shown each step
 * @param {{ dispatchEvent: (event: Event) => boolean }} [options.target]
 * @returns {{ step: () => void, release: () => void, held: () => string[] }}
 */
export function createAutopilot({ controller, inputs, observe, target = globalThis }) {
  const held = new Set();

  const send = (type, name) => {
    const key = inputs[name][0];
    target.dispatchEvent(new KeyboardEvent(type, { key, bubbles: true, cancelable: true }));
  };

  return {
    step() {
      const next = controller.nextInputs(observe());
      if (!next) return;
      for (const name of Object.keys(inputs)) {
        const want = next[name] === true;
        if (want && !held.has(name)) {
          held.add(name);
          send("keydown", name);
        } else if (!want && held.has(name)) {
          held.delete(name);
          send("keyup", name);
        }
      }
    },
    release() {
      for (const name of held) send("keyup", name);
      held.clear();
    },
    held: () => [...held],
  };
}
