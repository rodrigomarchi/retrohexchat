// Static public-page behavior for landing pages.
// Keep this bundle dependency-light: no LiveSocket, no highlight.js.

import { createPlausibleTracker } from "./lib/analytics/plausible";
import { formatTime, CLOCK_INTERVAL } from "./lib/connection/clock.js";
import { createMenuBar } from "./lib/ui/menu_bar";
import { createWindowManager } from "./lib/window_manager/window_manager";

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

// Taskbar tray clock — reuses the app's ClockHook formatter/interval (local HH:MM,
// updated every 30s). No LiveSocket needed; it just ticks a plain setInterval.
function setupClock() {
  const clocks = document.querySelectorAll("[data-clock]");
  if (clocks.length === 0) return;

  const tick = () => {
    const text = formatTime(new Date());
    clocks.forEach((el) => {
      el.textContent = text;
    });
  };

  tick();
  setInterval(tick, CLOCK_INTERVAL);
}

// The same window manager the app runs, minus LiveView. Landing pages hold no
// windows of their own — each page *is* the window — so what it contributes
// here is the Start menu and the taskbar's right-click behaviour. Every button
// in that chrome is a real link, and the manager leaves those clicks alone
// because the windows they name live at other URLs.
function setupWindowManager() {
  const el = document.querySelector("[data-window-manager]");
  if (!el) return null;

  const wm = createWindowManager(el);
  wm.mount();
  return wm;
}

// The same menu bar the app runs, minus LiveView — including the mobile rail,
// so a phone gets the icon rail here exactly as it does in the chat.
function setupMenuBar() {
  const el = document.querySelector("[data-menubar-root]");
  if (!el) return null;

  const bar = createMenuBar(el);
  bar.mount();
  return bar;
}

setupClock();
setupMenuBar();
setupWindowManager();

const plausibleEnv = document.querySelector('meta[name="plausible-env"]')?.content || "prod";
const plausible = createPlausibleTracker({
  domain: "retrohexchat.app",
  defaultProps: { env: plausibleEnv },
});
plausible.attachAutoTracking();
window.plausible = plausible;
