/**
 * Feedback toast creation and display.
 *
 * Simpler variant of the Z2 toast — no checkbox, no suppress logic.
 * Used for copy confirmation ("Copied!") and settings saved toasts.
 */
import { t } from "../i18n.js";
import { animateIn, animateOut, createToastElement } from "./toast.js";

/**
 * Create a retro-styled feedback toast element: the toast window titled
 * "Info", with OK and no "Don't show tips again".
 *
 * @param {string} message - Toast text to display
 * @returns {HTMLElement}
 */
export function createFeedbackToastElement(message) {
  return createToastElement(
    { text: message },
    { title: t("Info"), buttonLabel: t("OK"), showCheckbox: false },
  );
}

/**
 * Show a feedback toast on the given container element.
 * Auto-dismisses after `duration` ms.
 *
 * @param {HTMLElement} hookEl - The toast container element
 * @param {string} message - Toast text
 * @param {number} duration - Auto-dismiss duration in ms
 */
export function showFeedbackToast(hookEl, message, duration) {
  const container =
    hookEl.querySelector(".toast-container") || document.querySelector(".toast-container");
  if (!container) return;

  const el = createFeedbackToastElement(message);
  container.appendChild(el);

  requestAnimationFrame(() => animateIn(el));

  const dismiss = async () => {
    await animateOut(el);
    el.remove();
  };

  // OK button dismisses immediately
  const btn = el.querySelector("button");
  if (btn) {
    btn.addEventListener("click", dismiss);
  }

  // Auto-dismiss after duration
  setTimeout(dismiss, duration);
}
