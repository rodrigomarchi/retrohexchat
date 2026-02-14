import OnboardingHook from "../../js/hooks/onboarding_hook.js";
import {
  mountHook,
  cleanupDOM,
  simulateEvent,
  getPushEvents,
  mockLocalStorage,
} from "../helpers/hook_helper.js";

describe("OnboardingHook", () => {
  let storage;

  beforeEach(() => {
    storage = mockLocalStorage();
  });

  afterEach(() => {
    cleanupDOM();
    storage.restore();
  });

  // ── mounted ──────────────────────────────────────────────

  describe("mounted", () => {
    it("pushes check_onboarding with first_visit true when localStorage is empty", () => {
      const hook = mountHook(OnboardingHook);
      const events = getPushEvents(hook, "check_onboarding");

      expect(events).toHaveLength(1);
      expect(events[0]).toEqual({ first_visit: true });
    });

    it("pushes check_onboarding with first_visit false when onboarding is complete", () => {
      storage.store["retro_hex_chat_onboarding_complete"] = "true";
      const hook = mountHook(OnboardingHook);
      const events = getPushEvents(hook, "check_onboarding");

      expect(events).toHaveLength(1);
      expect(events[0]).toEqual({ first_visit: false });
    });

    it("registers mark_onboarding_complete event handler", () => {
      const hook = mountHook(OnboardingHook);
      expect(hook.handleEvent).toHaveBeenCalledWith(
        "mark_onboarding_complete",
        expect.any(Function),
      );
    });
  });

  // ── mark_onboarding_complete ─────────────────────────────

  describe("mark_onboarding_complete event", () => {
    it("sets localStorage flag when server sends event", () => {
      const hook = mountHook(OnboardingHook);
      simulateEvent(hook, "mark_onboarding_complete", {});

      expect(storage.store["retro_hex_chat_onboarding_complete"]).toBe("true");
    });
  });
});
