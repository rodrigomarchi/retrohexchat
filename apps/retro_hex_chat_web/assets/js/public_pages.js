// Static public-page behavior for landing pages.
// Keep this bundle dependency-light: no LiveSocket, no highlight.js.

import { createPlausibleTracker } from "./lib/analytics/plausible";

function targetElement(selector) {
  if (!selector) return null;
  return document.querySelector(selector);
}

function showElement(element) {
  if (!element) return;
  element.hidden = false;
  element.setAttribute("aria-hidden", "false");
}

function hideElement(element) {
  if (!element) return;
  element.hidden = true;
  element.setAttribute("aria-hidden", "true");
}

document.addEventListener("click", (event) => {
  const closest = (selector) =>
    event.target instanceof Element ? event.target.closest(selector) : null;

  const toggleButton = closest("[data-toggle-target]");
  if (toggleButton) {
    const target = targetElement(toggleButton.dataset.toggleTarget);
    if (!target) return;

    target.hidden = !target.hidden;
    toggleButton.setAttribute("aria-expanded", String(!target.hidden));
    return;
  }

  const showButton = closest("[data-show-target]");
  if (showButton) {
    const target = targetElement(showButton.dataset.showTarget);
    showElement(target);
    return;
  }

  const hideButton = closest("[data-hide-target]");
  if (hideButton) {
    hideElement(targetElement(hideButton.dataset.hideTarget));
    return;
  }

  const modal = closest("[data-modal]");
  if (modal && event.target === modal) {
    hideElement(modal);
  }
});

document.addEventListener("keydown", (event) => {
  if (event.key !== "Escape") return;

  document.querySelectorAll("[data-modal]:not([hidden])").forEach((modal) => {
    hideElement(modal);
  });
});

const plausibleEnv = document.querySelector('meta[name="plausible-env"]')?.content || "prod";
const plausible = createPlausibleTracker({
  domain: "retrohexchat.app",
  defaultProps: { env: plausibleEnv },
});
plausible.attachAutoTracking();
window.plausible = plausible;
