/**
 * Toast DOM creation and animation.
 *
 * Pure functions for building 98.css-styled toast elements.
 * No localStorage access — used by ContextualTipsHook for rendering.
 */

/**
 * Create a 98.css-styled toast notification element.
 *
 * @param {Object} tip - Tip definition with id and text
 * @param {Object} options
 * @param {boolean} [options.showCheckbox=true] - Show "Não mostrar mais dicas" checkbox
 * @param {function} options.onDismiss - Called with (checkboxChecked) when dismissed
 * @returns {HTMLElement}
 */
export function createToastElement(tip, options = {}) {
  const { showCheckbox = true, onDismiss } = options;

  const wrapper = document.createElement("div");
  wrapper.className = "toast-notification";
  wrapper.setAttribute("role", "status");
  wrapper.setAttribute("aria-live", "polite");
  wrapper.dataset.tipId = tip.id;

  const win = document.createElement("div");
  win.className = "window";

  const titleBar = document.createElement("div");
  titleBar.className = "title-bar";
  const titleText = document.createElement("div");
  titleText.className = "title-bar-text";
  titleText.textContent = "Dica";
  titleBar.appendChild(titleText);
  win.appendChild(titleBar);

  const body = document.createElement("div");
  body.className = "window-body";

  const text = document.createElement("div");
  text.className = "toast-text";
  text.textContent = tip.text;
  body.appendChild(text);

  const actions = document.createElement("div");
  actions.className = "toast-actions";

  let checkboxInput = null;

  if (showCheckbox) {
    const checkboxWrapper = document.createElement("div");
    checkboxWrapper.className = "toast-checkbox";

    checkboxInput = document.createElement("input");
    checkboxInput.type = "checkbox";
    checkboxInput.id = `toast-suppress-${tip.id}`;

    // Prevent checkbox from stealing focus from chat input
    checkboxInput.addEventListener("mousedown", (e) => e.preventDefault());
    checkboxInput.addEventListener("click", (e) => {
      // Toggle manually since we prevent default mousedown
      checkboxInput.checked = !checkboxInput.checked;
      e.preventDefault();
    });

    const label = document.createElement("label");
    label.htmlFor = checkboxInput.id;
    label.textContent = "Não mostrar mais dicas";

    // Prevent label click from stealing focus
    label.addEventListener("mousedown", (e) => e.preventDefault());
    label.addEventListener("click", (e) => {
      checkboxInput.checked = !checkboxInput.checked;
      e.preventDefault();
    });

    checkboxWrapper.appendChild(checkboxInput);
    checkboxWrapper.appendChild(label);
    actions.appendChild(checkboxWrapper);
  }

  const button = document.createElement("button");
  button.textContent = "Entendi!";
  // Prevent button from stealing focus from chat input
  button.addEventListener("mousedown", (e) => e.preventDefault());
  button.addEventListener("click", () => {
    if (onDismiss) {
      onDismiss(checkboxInput ? checkboxInput.checked : false);
    }
  });
  actions.appendChild(button);

  body.appendChild(actions);
  win.appendChild(body);
  wrapper.appendChild(win);

  return wrapper;
}

/**
 * Apply entry animation (fade-in + slide-up).
 * @param {HTMLElement} element
 */
export function animateIn(element) {
  element.classList.add("toast-visible");
}

/**
 * Apply exit animation (fade-out + slide-down).
 * Resolves when the transition completes.
 * @param {HTMLElement} element
 * @returns {Promise<void>}
 */
export function animateOut(element) {
  return new Promise((resolve) => {
    element.classList.remove("toast-visible");
    element.classList.add("toast-hiding");

    const onEnd = () => {
      element.removeEventListener("transitionend", onEnd);
      resolve();
    };
    element.addEventListener("transitionend", onEnd);

    // Fallback in case transitionend doesn't fire
    setTimeout(resolve, 200);
  });
}
