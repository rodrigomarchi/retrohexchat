// Static public-page behavior for landing pages.
// Keep this bundle dependency-light: no LiveSocket, no highlight.js.

import { createPlausibleTracker } from "./lib/analytics/plausible";
import { formatTime, CLOCK_INTERVAL } from "./lib/connection/clock.js";
import { log } from "./lib/logger";
import { createMenuBar } from "./lib/ui/menu_bar";
import { mountPublicWindowManager } from "./lib/window_manager/public_manager";

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
  return mountPublicWindowManager(document.querySelector("[data-window-manager]"));
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

// The connect window is a real LiveView island, but the LiveSocket that drives
// it is not worth the critical path: most visitors read and leave, and crawlers
// never interact at all. So the socket arrives on first touch — the window is
// already dead-rendered, and connecting hydrates what is on screen.
const CONNECT_WINDOW = '[data-testid="landing-connect-window"]';
let connectBootState = "idle";
let pendingSubmit = null;

// The state lives on <html>, not on the window element: once a LiveSocket is up
// LiveView owns that subtree and strips attributes the server did not render —
// the same reason the window manager has to reconcile its geometry back.
function markConnectBoot(state) {
  connectBootState = state;
  document.documentElement.setAttribute("data-connect-boot", state);
}

// Until the socket is up, LiveView is not intercepting these forms, so a submit
// would be a native one: the browser would reload the page and the reader would
// lose what they typed. Hold the submit, boot, and replay it once LiveView owns
// the form — so reaching for the form fast costs a moment, never an entry.
function holdSubmitUntilReady(win) {
  win.addEventListener(
    "submit",
    (event) => {
      if (connectBootState === "ready") return;

      event.preventDefault();
      const form = event.target;
      // Keep the values, never the node: joining replaces this form, so a
      // reference would be detached by the time it could be replayed — and the
      // server has never seen what was typed, so the DOM cannot supply it back.
      pendingSubmit = {
        event: form.getAttribute("phx-submit"),
        values: Object.fromEntries(new FormData(form).entries()),
      };
      bootConnect();
    },
    true,
  );
}

function replayPendingSubmit() {
  const pending = pendingSubmit;
  pendingSubmit = null;
  if (!pending) return;

  const form = document.querySelector(`${CONNECT_WINDOW} form[phx-submit="${pending.event}"]`);

  if (!form) {
    log.error("[connect] the held form was gone before it could be replayed", pending.event);
    return;
  }

  for (const [name, value] of Object.entries(pending.values)) {
    const field = form.elements.namedItem(name);
    if (field) field.value = value;
  }

  form.requestSubmit();
}

function revealConnectBootError() {
  document.querySelectorAll("[data-connect-boot-error]").forEach(showElement);
}

async function bootConnect() {
  if (connectBootState !== "idle") return;
  markConnectBoot("loading");

  try {
    // PublicWindowManagerHook adopts the manager mounted above rather than
    // replacing it, so nothing is handed over here. It has to be a hook from
    // now on: a connected LiveView rebuilds the window roots from server markup
    // that carries no geometry, and only a hook gets the `updated()` that
    // reconciles the layout back.
    const { bootConnectLiveSocket, whenLiveViewJoined } = await import("./connect_boot");
    bootConnectLiveSocket();

    // connect() returns before the socket opens, so "ready" has to mean joined.
    // Marking it any earlier would replay a held submit against a page LiveView
    // is not driving yet — a native submit, and the reader loses what they typed.
    await whenLiveViewJoined();
    markConnectBoot("ready");
    replayPendingSubmit();
  } catch (error) {
    // A failed chunk leaves the form inert, which looks like a dead page unless
    // we say so. Never swallow this.
    markConnectBoot("failed");
    pendingSubmit = null;
    revealConnectBootError();
    log.error("[connect] could not load the sign-in socket", error);
  }
}

function setupConnectBoot() {
  const win = document.querySelector(CONNECT_WINDOW);
  if (!win) return;

  markConnectBoot("idle");
  holdSubmitUntilReady(win);

  // A reader the server recognises is one click from signing in, and that click
  // is lost if it lands before the socket is up. It is also the only thing that
  // opens a socket for auto-login to push through. So they get it during render;
  // everyone else waits until they actually reach for the form.
  if (win.querySelector('[data-connect-eager="true"]')) {
    bootConnect();
    return;
  }

  for (const event of ["pointerover", "pointerdown", "focusin"]) {
    win.addEventListener(event, bootConnect, { once: true, passive: true });
  }
}

setupClock();
setupMenuBar();
setupWindowManager();
setupConnectBoot();

const plausibleEnv = document.querySelector('meta[name="plausible-env"]')?.content || "prod";
const plausible = createPlausibleTracker({
  domain: "retrohexchat.app",
  defaultProps: { env: plausibleEnv },
});
plausible.attachAutoTracking();
window.plausible = plausible;
