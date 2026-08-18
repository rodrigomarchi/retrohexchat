/**
 * ViewportDetectHook — keeps the LiveView and CSS viewport contracts in sync.
 *
 * The app is fixed-positioned, so phones need visualViewport updates when the
 * address bar or keyboard changes the visible area. The server receives only
 * meaningful breakpoint changes; CSS variables update on every visual change.
 */
import {
  computeViewport,
  viewportChanged,
  viewportCssVars,
  viewportPayload,
} from "../../lib/ui/viewport.js";
function editableFocused() {
  const active = document.activeElement;
  if (!active) return false;
  if (active.isContentEditable) return true;

  const tagName = active.tagName?.toLowerCase();
  if (tagName === "textarea") return true;
  if (tagName !== "input") return false;

  const type = active.getAttribute("type") || "text";
  return !["button", "checkbox", "file", "hidden", "radio", "range", "reset", "submit"].includes(
    type,
  );
}

export default {
  mounted() {
    this.lastPayload = null;
    this.updateViewport = this.updateViewport.bind(this);
    this.scheduleViewportUpdate = this.scheduleViewportUpdate.bind(this);

    this.updateViewport({ force: true });

    window.addEventListener("resize", this.scheduleViewportUpdate);
    window.addEventListener("orientationchange", this.scheduleViewportUpdate);
    window.addEventListener("focusin", this.scheduleViewportUpdate);
    window.addEventListener("focusout", this.scheduleViewportUpdate);

    if (window.visualViewport) {
      window.visualViewport.addEventListener("resize", this.scheduleViewportUpdate);
      window.visualViewport.addEventListener("scroll", this.scheduleViewportUpdate);
    }
  },

  destroyed() {
    if (this.viewportRaf) cancelAnimationFrame(this.viewportRaf);

    window.removeEventListener("resize", this.scheduleViewportUpdate);
    window.removeEventListener("orientationchange", this.scheduleViewportUpdate);
    window.removeEventListener("focusin", this.scheduleViewportUpdate);
    window.removeEventListener("focusout", this.scheduleViewportUpdate);

    if (window.visualViewport) {
      window.visualViewport.removeEventListener("resize", this.scheduleViewportUpdate);
      window.visualViewport.removeEventListener("scroll", this.scheduleViewportUpdate);
    }

    document.documentElement.classList.remove("rhc-mobile-viewport", "rhc-keyboard-open");
    delete document.documentElement.dataset.rhcKeyboardOpen;
  },

  scheduleViewportUpdate() {
    if (this.viewportRaf) cancelAnimationFrame(this.viewportRaf);
    this.viewportRaf = requestAnimationFrame(() => {
      this.viewportRaf = null;
      this.updateViewport();
    });
  },

  updateViewport({ force = false } = {}) {
    const state = computeViewport({
      innerWidth: window.innerWidth,
      innerHeight: window.innerHeight,
      visualViewport: window.visualViewport,
      editableFocused: editableFocused(),
    });

    const root = document.documentElement;
    for (const [name, value] of Object.entries(viewportCssVars(state))) {
      root.style.setProperty(name, value);
    }
    root.classList.toggle("rhc-mobile-viewport", state.mobile);
    root.classList.toggle("rhc-keyboard-open", state.keyboardOpen);
    root.dataset.rhcKeyboardOpen = state.keyboardOpen ? "true" : "false";

    const payload = viewportPayload(state);
    if (force || viewportChanged(this.lastPayload, payload)) {
      this.lastPayload = payload;
      this.pushEvent("viewport_info", payload);
    }
  },
};
