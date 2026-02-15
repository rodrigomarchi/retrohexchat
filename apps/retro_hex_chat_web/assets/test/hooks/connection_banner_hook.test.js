import { mountHook, cleanupDOM } from "../helpers/hook_helper.js";
import ConnectionBannerHook from "../../js/hooks/connection_banner_hook.js";

describe("ConnectionBannerHook", () => {
  let hook;

  beforeEach(() => {
    vi.useFakeTimers();
    hook = mountHook(ConnectionBannerHook, {
      attrs: { id: "connection-banner" },
    });
  });

  afterEach(() => {
    vi.useRealTimers();
    cleanupDOM();
  });

  it("initializes state machine on mount", () => {
    expect(hook._sm).toBeDefined();
  });

  it("does not show banner on disconnect before first reconnect", () => {
    if (hook.disconnected) {
      hook.disconnected();
    }
    vi.advanceTimersByTime(2000);
    expect(hook.el.classList.contains("connection-banner--visible")).toBe(false);
  });

  it("shows disconnected banner after debounce when wasConnected", () => {
    // Simulate initial connection
    if (hook.reconnected) {
      hook.reconnected();
    }
    // Now disconnect
    if (hook.disconnected) {
      hook.disconnected();
    }
    vi.advanceTimersByTime(1000);
    expect(hook.el.classList.contains("connection-banner--visible")).toBe(true);
    expect(hook.el.classList.contains("connection-banner--disconnected")).toBe(true);
  });

  it("shows reconnected banner and fades after 3s", () => {
    // Connect then disconnect then reconnect
    if (hook.reconnected) hook.reconnected();
    if (hook.disconnected) hook.disconnected();
    vi.advanceTimersByTime(1000);
    if (hook.reconnected) hook.reconnected();
    expect(hook.el.classList.contains("connection-banner--reconnected")).toBe(true);
    vi.advanceTimersByTime(3000);
    expect(hook.el.classList.contains("connection-banner--visible")).toBe(false);
  });

  it("clears all timers on destroyed", () => {
    if (hook.reconnected) hook.reconnected();
    if (hook.disconnected) hook.disconnected();
    hook.destroyed();
    vi.advanceTimersByTime(5000);
    // No errors thrown, banner stays in whatever state
  });

  it("hides banner when overlay is visible", () => {
    // Create a fake reconnect overlay in the DOM
    const overlay = document.createElement("div");
    overlay.classList.add("reconnect-overlay", "reconnect-overlay--visible");
    document.body.appendChild(overlay);

    if (hook.reconnected) hook.reconnected();
    if (hook.disconnected) hook.disconnected();
    vi.advanceTimersByTime(1000);

    // Trigger check for overlay
    hook._checkOverlay();
    expect(hook.el.classList.contains("connection-banner--visible")).toBe(false);
  });
});
