/**
 * Win98 up-down control: the pair of arrow buttons the `updown` component
 * attaches to a number field.
 *
 * One delegated listener serves every control on the page, so a control that
 * LiveView renders later works without a hook of its own. A press steps the
 * field once; holding it repeats after a pause, as Windows does. Each step
 * fires `input` and `change` on the field, so a `phx-change` form hears it as
 * if the value had been typed.
 *
 * The press never takes focus: a pointerdown that is not cancelled would move
 * focus to the button, and the caret belongs in the field.
 */

const REPEAT_DELAY_MS = 400;
const REPEAT_INTERVAL_MS = 60;

/**
 * Steps the number field of an up-down control.
 *
 * @param {HTMLInputElement} input
 * @param {"up"|"down"} direction
 * @returns {boolean} whether the value changed
 */
export function stepNumberField(input, direction) {
  if (!input || input.disabled || input.readOnly) return false;

  const before = input.value;
  try {
    if (direction === "up") input.stepUp();
    else input.stepDown();
  } catch (error) {
    // `stepUp` throws on a field whose value is not a number yet (or whose type
    // was changed under it). Start from the bound the arrow points away from.
    console.debug("[updown] step refused, starting from the field's bound", error);
    input.value = direction === "up" ? input.min || "0" : input.max || "0";
  }

  if (input.value === before) return false;

  input.dispatchEvent(new Event("input", { bubbles: true }));
  input.dispatchEvent(new Event("change", { bubbles: true }));
  return true;
}

/**
 * Wires every up-down control under `root` (the document by default).
 *
 * @param {Document|HTMLElement} [root]
 * @param {{setTimeout?: Function, clearTimeout?: Function}} [timers]
 * @returns {() => void} removes the listeners
 */
export function installUpDown(root = document, timers = window) {
  const state = { timer: null };

  const stop = () => {
    if (state.timer !== null) timers.clearTimeout(state.timer);
    state.timer = null;
  };

  const repeat = (input, direction) => {
    state.timer = timers.setTimeout(() => {
      if (!stepNumberField(input, direction)) return stop();
      repeat(input, direction);
    }, REPEAT_INTERVAL_MS);
  };

  const onPointerDown = (event) => {
    if (event.button !== 0) return;
    const button = event.target.closest?.("[data-updown-step]");
    if (!button || button.disabled) return;

    const input = button.closest("[data-updown]")?.querySelector('input[type="number"]');
    if (!input) return;

    event.preventDefault();
    stop();
    const direction = button.dataset.updownStep;
    if (!stepNumberField(input, direction)) return;

    state.timer = timers.setTimeout(() => repeat(input, direction), REPEAT_DELAY_MS);
  };

  root.addEventListener("pointerdown", onPointerDown);
  root.addEventListener("pointerup", stop);
  root.addEventListener("pointercancel", stop);
  root.addEventListener("pointerout", stop);

  return () => {
    stop();
    root.removeEventListener("pointerdown", onPointerDown);
    root.removeEventListener("pointerup", stop);
    root.removeEventListener("pointercancel", stop);
    root.removeEventListener("pointerout", stop);
  };
}
