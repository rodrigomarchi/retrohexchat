/**
 * Landing page — vanilla JS interactions.
 * No frameworks, no LiveView, no WebSocket.
 */

import {
  initSmoothScroll,
  initTabs,
  initMobileMenu,
  initScrollReveal,
  initDesktopIcons,
  initKonamiCode,
} from "./lib/landing.js";

document.addEventListener("DOMContentLoaded", () => {
  initSmoothScroll();
  initTabs();
  initMobileMenu();
  initScrollReveal();
  initDesktopIcons();
  initKonamiCode();
});
