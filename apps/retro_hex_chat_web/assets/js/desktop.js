// The desktop's first-paint bundle: what the page in front needs before the
// chat behind it exists — the window manager, the menus, the clock, the popups.
// Keep it dependency-light: no LiveSocket, no highlight.js. The chat's socket is
// a dynamic import, started by `lib/site/boot_policy.js`.

import { installPlausible } from "./lib/analytics/plausible";
import { formatTime, CLOCK_INTERVAL } from "./lib/connection/clock.js";
import { log } from "./lib/logger";
import { mountSiteMenuBar } from "./lib/ui/site_menu_bar";
import { installRetroTooltips } from "./lib/ui/tooltip";
import { bootMode, scheduleBoot } from "./lib/site/boot_policy";
import { heldLinkHref, linkFor } from "./lib/site/held_links";
import { registerServiceWorker } from "./lib/system/service_worker.js";
import { mountSiteWindowManager } from "./lib/window_manager/site_manager";

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

// Escape closes an open popup — and only the popup: the window manager, which
// listens after this, would otherwise close the page's window under it too.
document.addEventListener("keydown", (event) => {
  if (event.key !== "Escape") return;

  const open = document.querySelectorAll("[data-modal]:not([hidden])");
  if (open.length === 0) return;

  open.forEach((modal) => hideElement(modal));
  event.stopImmediatePropagation();
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

// The window manager, mounted now so the page in front is placed and usable at
// once. The LiveSocket's WindowManagerHook adopts this instance when it starts.
function setupWindowManager() {
  return mountSiteWindowManager(document.querySelector("[data-window-manager]"));
}

// The same menu bar the app runs, minus LiveView — including the mobile rail,
// so a phone gets the icon rail here exactly as it does in the chat.
function setupMenuBar() {
  const el = document.querySelector("[data-menubar-root]");
  if (!el) return null;

  return mountSiteMenuBar(el);
}

// The chat's LiveSocket is not worth the critical path for a reader of a page of
// the site, and a crawler never needs it: it starts when the page has a reason
// (`lib/site/boot_policy.js`). Until then LiveView is not intercepting forms,
// so a submit would be a native one — the browser would reload and the reader
// would lose what they typed. A submit is held, the socket started, and the
// submit replayed once LiveView owns the form.
let liveState = "idle";
let pendingSubmit = null;
let pendingLink = null;
let pendingPushes = [];
let windowManager = null;

function markLive(state) {
  liveState = state;
  document.documentElement.setAttribute("data-live-boot", state);
}

function holdSubmitsUntilLive() {
  document.addEventListener(
    "submit",
    (event) => {
      const form = event.target;
      if (liveState === "ready" || !form?.getAttribute?.("phx-submit")) return;

      event.preventDefault();
      // Keep the values, never the node: joining replaces this form, so a
      // reference would be detached by the time it could be replayed.
      pendingSubmit = {
        event: form.getAttribute("phx-submit"),
        id: form.id,
        values: Object.fromEntries(new FormData(form).entries()),
      };
      bootLive();
    },
    true,
  );
}

// The same for what the reader does with the windows before the chat exists —
// a desktop icon double-clicked, a window brought forward or closed: the window
// manager has no server to tell yet, so it hands each over (`wm:deferred-push`)
// and they are sent, in order, once the chat has started.
function holdPushesUntilLive() {
  document.addEventListener("wm:deferred-push", (event) => {
    pendingPushes.push(event.detail);
    bootLive();
  });
}

function replayPendingPushes() {
  const pending = pendingPushes;
  pendingPushes = [];
  if (pending.length === 0) return;

  if (typeof windowManager?.pushEvent !== "function") {
    log.error(
      "[desktop] the chat started without a window manager to send",
      pending.map((push) => push.event),
    );
    return;
  }
  for (const push of pending) windowManager.pushEvent(push.event, push.payload);
}

// The same for a patch link clicked while the chat starts (`lib/site/held_links.js`).
function holdLinksUntilLive() {
  document.addEventListener(
    "click",
    (event) => {
      const href = heldLinkHref(event, liveState);
      if (!href) return;

      event.preventDefault();
      event.stopPropagation();
      pendingLink = href;
      bootLive();
    },
    true,
  );
}

function replayPendingLink() {
  const href = pendingLink;
  pendingLink = null;
  if (!href) return;

  const link = linkFor(document, href);
  if (link) {
    link.click();
  } else {
    // The redrawn desktop no longer offers it: follow the address whole.
    log.warn("[desktop] a held link was gone after the chat started; loading it", href);
    window.location.assign(href);
  }
}

function replayPendingSubmit() {
  const pending = pendingSubmit;
  pendingSubmit = null;
  if (!pending) return;

  const form =
    (pending.id && document.getElementById(pending.id)) ||
    document.querySelector(`form[phx-submit="${pending.event}"]`);

  if (!form) {
    log.error("[desktop] the held form was gone before it could be replayed", pending.event);
    return;
  }

  for (const [name, value] of Object.entries(pending.values)) {
    const field = form.elements.namedItem(name);
    if (field) field.value = value;
  }

  form.requestSubmit();
}

async function bootLive() {
  if (liveState !== "idle") return;
  markLive("loading");

  try {
    const { bootLiveSocket, whenLiveViewJoined } = await import("./lib/system/live_boot");
    await bootLiveSocket();
    await whenLiveViewJoined();
    markLive("ready");
    replayPendingSubmit();
    replayPendingLink();
    replayPendingPushes();
    if (document.documentElement.dataset.member === "true") registerServiceWorker();
  } catch (error) {
    // A failed chunk leaves the desktop without its chat, which looks like a
    // dead page unless we say so. Never swallow this.
    markLive("failed");
    pendingSubmit = null;
    pendingLink = null;
    pendingPushes = [];
    log.error("[desktop] could not start the chat's LiveSocket", error);
  }
}

setupClock();
setupMenuBar();
windowManager = setupWindowManager();
holdSubmitsUntilLive();
holdLinksUntilLive();
holdPushesUntilLive();
scheduleBoot({
  mode: bootMode(document.documentElement, navigator.userAgent),
  boot: bootLive,
});
installRetroTooltips(document);

installPlausible();
