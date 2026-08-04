import ContextualTipsHook from "../../../js/hooks/ui/contextual_tips_hook.js";
import { mountHook, cleanupDOM, simulateEvent, getPushEvents } from "../../helpers/hook_helper.js";
import { resetAllTips, TIP_IDS } from "../../../js/lib/ui/tips.js";

describe("ContextualTipsHook", () => {
  let localStorageMock;

  beforeEach(() => {
    localStorageMock = {
      getItem: vi.fn(() => {
        throw new Error("ContextualTipsHook must not read localStorage");
      }),
      setItem: vi.fn(() => {
        throw new Error("ContextualTipsHook must not write localStorage");
      }),
      removeItem: vi.fn(() => {
        throw new Error("ContextualTipsHook must not remove localStorage");
      }),
    };

    vi.stubGlobal("localStorage", localStorageMock);
    resetAllTips();
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
    cleanupDOM();
    vi.unstubAllGlobals();
  });

  function mountTipsHook(tipsState = { seen_tips: [], suppressed: false }) {
    return mountHook(ContextualTipsHook, {
      attrs: { "data-tips-state": JSON.stringify(tipsState) },
    });
  }

  // ── mounted ───────────────────────────────────────────────

  describe("mounted", () => {
    it("registers tip_trigger event handler", () => {
      const hook = mountTipsHook();
      expect(hook.handleEvent).toHaveBeenCalledWith("tip_trigger", expect.any(Function));
    });

    it("does not push legacy tips_state_sync on mount", () => {
      const hook = mountTipsHook();
      const events = getPushEvents(hook, "tips_state_sync");
      expect(events).toHaveLength(0);
    });

    it("loads suppressed state from server data attributes", () => {
      const hook = mountTipsHook({ seen_tips: [], suppressed: true });
      simulateEvent(hook, "tip_trigger", { tip: "first_message" });

      expect(hook.el.querySelector(".toast-notification")).toBeNull();
    });
  });

  // ── tip_trigger event ─────────────────────────────────────

  describe("tip_trigger event", () => {
    it("shows toast for unseen tip", () => {
      const hook = mountTipsHook();
      simulateEvent(hook, "tip_trigger", { tip: "first_message" });

      const toast = hook.el.querySelector(".toast-notification");
      expect(toast).not.toBeNull();
      expect(toast.querySelector(".toast-text").textContent).toBe(
        "Use ↑ to edit your last message",
      );
    });

    it("skips already-seen tip", () => {
      const hook = mountTipsHook({ seen_tips: ["first_message"], suppressed: false });
      simulateEvent(hook, "tip_trigger", { tip: "first_message" });

      const toast = hook.el.querySelector(".toast-notification");
      expect(toast).toBeNull();
    });

    it("skips tip when globally suppressed", () => {
      const hook = mountTipsHook({ seen_tips: [], suppressed: true });
      simulateEvent(hook, "tip_trigger", { tip: "first_message" });

      const toast = hook.el.querySelector(".toast-notification");
      expect(toast).toBeNull();
    });

    it("handles help_used by marking preempted tips as seen", () => {
      const hook = mountTipsHook();
      simulateEvent(hook, "tip_trigger", { tip: "help_used" });

      expect(getPushEvents(hook, "tips_seen")).toContainEqual({ tips: [TIP_IDS.IDLE_HELP] });

      // No toast should appear for help_used
      const toast = hook.el.querySelector(".toast-notification");
      expect(toast).toBeNull();
    });
  });

  // ── auto-dismiss ──────────────────────────────────────────

  describe("auto-dismiss", () => {
    it("auto-dismisses toast after 8 seconds", () => {
      const hook = mountTipsHook();
      simulateEvent(hook, "tip_trigger", { tip: "first_message" });

      expect(hook.el.querySelector(".toast-notification")).not.toBeNull();

      vi.advanceTimersByTime(8000);
      // After animateOut fallback timeout
      vi.advanceTimersByTime(200);

      expect(getPushEvents(hook, "tips_seen")).toContainEqual({ tips: ["first_message"] });
    });

    it("marks tip as seen after auto-dismiss", () => {
      const hook = mountTipsHook();
      simulateEvent(hook, "tip_trigger", { tip: "first_message" });

      vi.advanceTimersByTime(8200);

      expect(getPushEvents(hook, "tips_seen")).toContainEqual({ tips: ["first_message"] });
    });
  });

  // ── dismiss button ────────────────────────────────────────

  describe("dismiss button", () => {
    it("marks tip as seen when Entendi! is clicked", () => {
      const hook = mountTipsHook();
      simulateEvent(hook, "tip_trigger", { tip: "first_message" });

      const button = hook.el.querySelector("button");
      button.click();

      // Wait for animateOut
      vi.advanceTimersByTime(200);

      expect(getPushEvents(hook, "tips_seen")).toContainEqual({ tips: ["first_message"] });
    });

    it("sets global suppression when checkbox is checked and dismissed", () => {
      const hook = mountTipsHook();
      simulateEvent(hook, "tip_trigger", { tip: "first_message" });

      const checkbox = hook.el.querySelector('input[type="checkbox"]');
      checkbox.checked = true;

      const button = hook.el.querySelector("button");
      button.click();

      expect(getPushEvents(hook, "tips_suppressed_changed")).toContainEqual({
        suppressed: true,
      });
    });
  });

  // ── toast does not steal focus ────────────────────────────

  describe("focus management", () => {
    it("toast button mousedown is prevented to avoid stealing focus", () => {
      const hook = mountTipsHook();
      simulateEvent(hook, "tip_trigger", { tip: "first_message" });

      const button = hook.el.querySelector("button");
      const event = new MouseEvent("mousedown", { cancelable: true });
      button.dispatchEvent(event);

      expect(event.defaultPrevented).toBe(true);
    });
  });

  // ── queuing ───────────────────────────────────────────────

  describe("queuing", () => {
    it("shows second tip after 2s gap when first is dismissed", async () => {
      const hook = mountTipsHook();
      simulateEvent(hook, "tip_trigger", { tip: "first_message" });
      simulateEvent(hook, "tip_trigger", { tip: "first_join" });

      // Only first toast visible
      const toasts = hook.el.querySelectorAll(".toast-notification");
      expect(toasts).toHaveLength(1);
      expect(toasts[0].dataset.tipId).toBe("first_message");

      // Dismiss first
      const button = hook.el.querySelector("button");
      button.click();
      await vi.advanceTimersByTimeAsync(200); // animateOut + promise flush

      // After 2s gap, second appears
      await vi.advanceTimersByTimeAsync(2000);

      const secondToast = hook.el.querySelector(".toast-notification");
      expect(secondToast).not.toBeNull();
      expect(secondToast.dataset.tipId).toBe("first_join");
    });

    it("does not show tip when dialog overlay is present", () => {
      const hook = mountTipsHook();

      // Add a dialog overlay
      const overlay = document.createElement("div");
      overlay.className = "dialog-overlay";
      document.body.appendChild(overlay);

      simulateEvent(hook, "tip_trigger", { tip: "first_message" });

      const toast = hook.el.querySelector(".toast-notification");
      expect(toast).toBeNull();
    });

    it("shows queued tip after dialog is removed", () => {
      const hook = mountTipsHook();

      // Add a dialog overlay
      const overlay = document.createElement("div");
      overlay.className = "dialog-overlay";
      document.body.appendChild(overlay);

      simulateEvent(hook, "tip_trigger", { tip: "first_message" });

      // No toast while dialog is open
      expect(hook.el.querySelector(".toast-notification")).toBeNull();

      // Remove dialog overlay
      overlay.remove();

      // Poll interval fires (500ms)
      vi.advanceTimersByTime(500);

      const toast = hook.el.querySelector(".toast-notification");
      expect(toast).not.toBeNull();
    });

    it("clears queue when suppress checkbox is checked", async () => {
      const hook = mountTipsHook();
      simulateEvent(hook, "tip_trigger", { tip: "first_message" });
      simulateEvent(hook, "tip_trigger", { tip: "first_join" });

      // Check suppress checkbox and dismiss
      const checkbox = hook.el.querySelector('input[type="checkbox"]');
      checkbox.checked = true;
      const button = hook.el.querySelector("button");
      button.click();

      await vi.advanceTimersByTimeAsync(200); // animateOut
      await vi.advanceTimersByTimeAsync(2000); // queue gap

      // No second toast should appear
      const toast = hook.el.querySelector(".toast-notification");
      expect(toast).toBeNull();
    });
  });

  // ── idle timer ────────────────────────────────────────────

  describe("idle timer", () => {
    it("fires idle_help tip after 30s of inactivity", () => {
      const hook = mountTipsHook();

      vi.advanceTimersByTime(30000);

      const toast = hook.el.querySelector(".toast-notification");
      expect(toast).not.toBeNull();
      expect(toast.querySelector(".toast-text").textContent).toBe("Type /help to see all commands");
    });

    it("resets idle timer on keydown", () => {
      const hook = mountTipsHook();

      vi.advanceTimersByTime(15000);
      document.dispatchEvent(new KeyboardEvent("keydown", { key: "a" }));
      vi.advanceTimersByTime(15000);

      // Should not have fired yet (reset at 15s, so 15s more = 30s from reset)
      const toast = hook.el.querySelector(".toast-notification");
      expect(toast).toBeNull();

      vi.advanceTimersByTime(15000);

      expect(hook.el.querySelector(".toast-notification")).not.toBeNull();
    });

    it("does not fire idle_help if help_used preemption occurred", () => {
      const hook = mountTipsHook();
      simulateEvent(hook, "tip_trigger", { tip: "help_used" });

      vi.advanceTimersByTime(30000);

      const toast = hook.el.querySelector(".toast-notification");
      expect(toast).toBeNull();
    });

    it("is a one-shot timer — never fires twice", async () => {
      const hook = mountTipsHook();

      vi.advanceTimersByTime(30000);
      const toast = hook.el.querySelector(".toast-notification");
      expect(toast).not.toBeNull();

      // Dismiss
      hook.el.querySelector("button").click();
      await vi.advanceTimersByTimeAsync(200);

      // Wait another 30s — no new toast
      vi.advanceTimersByTime(30000);
      expect(hook.el.querySelector(".toast-notification")).toBeNull();
    });
  });

  // ── destroyed ─────────────────────────────────────────────

  describe("destroyed", () => {
    it("cleans up without errors", () => {
      const hook = mountTipsHook();
      simulateEvent(hook, "tip_trigger", { tip: "first_message" });

      expect(() => hook.destroyed()).not.toThrow();
    });
  });

  describe("storage", () => {
    it("never touches localStorage", () => {
      const hook = mountTipsHook();
      simulateEvent(hook, "tip_trigger", { tip: "first_message" });
      hook.el.querySelector("button").click();

      expect(localStorageMock.getItem).not.toHaveBeenCalled();
      expect(localStorageMock.setItem).not.toHaveBeenCalled();
      expect(localStorageMock.removeItem).not.toHaveBeenCalled();
    });
  });
});
