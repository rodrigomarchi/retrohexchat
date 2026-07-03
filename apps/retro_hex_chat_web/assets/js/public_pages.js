// Static public-page behavior for landing pages.
// Keep this bundle dependency-light: no LiveSocket, no highlight.js.

import { createPlausibleTracker } from "./lib/analytics/plausible";
import { formatTime, CLOCK_INTERVAL } from "./lib/connection/clock.js";

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

// Vanilla port of MenuBarHook for the static landing menu bar. Same DOM contract
// (data-menubar-trigger + sibling data-menubar-dropdown.u-hidden): click opens/toggles,
// hovering another trigger switches menus while one is open, outside-mousedown and
// Escape close. Dropdown items are <a> links, so a click navigates and closes.
function setupMenuBar() {
  let activeMenu = null;

  const closeAll = () => {
    document
      .querySelectorAll("[data-menubar-dropdown]")
      .forEach((dropdown) => dropdown.classList.add("u-hidden"));
    document.querySelectorAll("[data-menubar-trigger]").forEach((trigger) => {
      trigger.classList.remove("bg-primary", "text-primary-foreground");
      if (trigger.dataset.disabled !== "true") trigger.classList.add("hover:bg-accent");
    });
    activeMenu = null;
  };

  const openMenu = (menu) => {
    closeAll();
    const dropdown = menu.querySelector("[data-menubar-dropdown]");
    if (!dropdown) return;
    dropdown.classList.remove("u-hidden");
    const trigger = menu.querySelector("[data-menubar-trigger]");
    if (trigger) {
      trigger.classList.add("bg-primary", "text-primary-foreground");
      trigger.classList.remove("hover:bg-accent");
    }
    activeMenu = menu;
  };

  document.addEventListener("mousedown", (event) => {
    const el = event.target instanceof Element ? event.target : null;
    const trigger = el && el.closest("[data-menubar-trigger]");

    if (trigger) {
      event.preventDefault();
      if (trigger.dataset.disabled === "true") return;
      const menu = trigger.parentElement;
      if (activeMenu === menu) closeAll();
      else openMenu(menu);
      return;
    }

    // Outside a trigger: close unless the press landed inside an open dropdown.
    if (activeMenu && !(el && el.closest("[data-menubar-dropdown]"))) closeAll();
  });

  document.addEventListener(
    "mouseenter",
    (event) => {
      if (!activeMenu) return;
      const el = event.target instanceof Element ? event.target : null;
      const trigger = el && el.closest("[data-menubar-trigger]");
      if (!trigger || trigger.dataset.disabled === "true") return;
      const menu = trigger.parentElement;
      if (menu !== activeMenu) openMenu(menu);
    },
    true,
  );

  document.addEventListener("click", (event) => {
    if (event.target instanceof Element && event.target.closest("[data-menubar-dropdown] li")) {
      closeAll();
    }
  });

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") closeAll();
  });
}

setupClock();
setupMenuBar();

const plausibleEnv = document.querySelector('meta[name="plausible-env"]')?.content || "prod";
const plausible = createPlausibleTracker({
  domain: "retrohexchat.app",
  defaultProps: { env: plausibleEnv },
});
plausible.attachAutoTracking();
window.plausible = plausible;
