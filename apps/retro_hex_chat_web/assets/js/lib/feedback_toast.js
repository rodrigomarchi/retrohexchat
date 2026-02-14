/**
 * Feedback toast creation and display.
 *
 * Simpler variant of the Z2 toast — no checkbox, no suppress logic.
 * Used for copy confirmation ("Copiado!") and settings saved toasts.
 */
import { animateIn, animateOut } from "./toast.js";

/**
 * Create a 98.css-styled feedback toast element (Info window, no checkbox).
 *
 * @param {string} message - Toast text to display
 * @returns {HTMLElement}
 */
export function createFeedbackToastElement(message) {
  const wrapper = document.createElement("div");
  wrapper.className = "toast-notification";
  wrapper.setAttribute("role", "status");
  wrapper.setAttribute("aria-live", "polite");

  const win = document.createElement("div");
  win.className = "window";

  const titleBar = document.createElement("div");
  titleBar.className = "title-bar";
  const titleText = document.createElement("div");
  titleText.className = "title-bar-text";
  titleText.textContent = "Info";
  titleBar.appendChild(titleText);
  win.appendChild(titleBar);

  const body = document.createElement("div");
  body.className = "window-body";

  const text = document.createElement("div");
  text.className = "toast-text";
  text.textContent = message;
  body.appendChild(text);

  const actions = document.createElement("div");
  actions.className = "toast-actions";

  const button = document.createElement("button");
  button.textContent = "OK";
  button.addEventListener("mousedown", (e) => e.preventDefault());
  actions.appendChild(button);

  body.appendChild(actions);
  win.appendChild(body);
  wrapper.appendChild(win);

  return wrapper;
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
