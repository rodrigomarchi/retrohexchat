/**
 * ViewportDetectHook — keeps the LiveView and CSS viewport contracts in sync.
 *
 * The app is fixed-positioned, so phones need visualViewport updates when the
 * address bar or keyboard changes the visible area. The server receives only
 * meaningful breakpoint changes; CSS variables update on every visual change.
 */
const MOBILE_BREAKPOINT = 768;
const KEYBOARD_INSET_THRESHOLD = 80;

function round(value) {
  return Math.round(Number(value) || 0);
}

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
    const visualViewport = window.visualViewport;
    const width = round(window.innerWidth);
    const height = round(window.innerHeight);
    const visualWidth = round(visualViewport?.width || width);
    const visualHeight = round(visualViewport?.height || height);
    const offsetTop = round(visualViewport?.offsetTop || 0);
    const offsetLeft = round(visualViewport?.offsetLeft || 0);
    const keyboardInset = Math.max(0, height - visualHeight - offsetTop);
    const mobile = width < MOBILE_BREAKPOINT;
    const keyboardOpen = mobile && editableFocused() && keyboardInset >= KEYBOARD_INSET_THRESHOLD;

    const root = document.documentElement;
    root.style.setProperty("--rhc-visual-viewport-height", `${visualHeight}px`);
    root.style.setProperty("--rhc-visual-viewport-width", `${visualWidth}px`);
    root.style.setProperty("--rhc-visual-viewport-offset-top", `${offsetTop}px`);
    root.style.setProperty("--rhc-visual-viewport-offset-left", `${offsetLeft}px`);
    root.style.setProperty("--rhc-keyboard-inset-bottom", `${keyboardInset}px`);
    root.classList.toggle("rhc-mobile-viewport", mobile);
    root.classList.toggle("rhc-keyboard-open", keyboardOpen);
    root.dataset.rhcKeyboardOpen = keyboardOpen ? "true" : "false";

    const payload = {
      width,
      height,
      visual_width: visualWidth,
      visual_height: visualHeight,
      mobile,
    };

    if (
      force ||
      !this.lastPayload ||
      this.lastPayload.width !== payload.width ||
      this.lastPayload.height !== payload.height ||
      this.lastPayload.mobile !== payload.mobile
    ) {
      this.lastPayload = payload;
      this.pushEvent("viewport_info", payload);
    }
  },
};
