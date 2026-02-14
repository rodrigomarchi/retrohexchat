import { isOnboardingComplete, markOnboardingComplete } from "../../js/lib/onboarding.js";
import { mockLocalStorage } from "../helpers/hook_helper.js";

describe("onboarding", () => {
  let storage;

  beforeEach(() => {
    storage = mockLocalStorage();
  });

  afterEach(() => {
    storage.restore();
  });

  describe("isOnboardingComplete", () => {
    it("returns false when no key exists", () => {
      expect(isOnboardingComplete()).toBe(false);
    });

    it("returns true when key is 'true'", () => {
      storage.store["retro_hex_chat_onboarding_complete"] = "true";
      expect(isOnboardingComplete()).toBe(true);
    });

    it("returns false when key has other value", () => {
      storage.store["retro_hex_chat_onboarding_complete"] = "false";
      expect(isOnboardingComplete()).toBe(false);
    });
  });

  describe("markOnboardingComplete", () => {
    it("sets the localStorage key to 'true'", () => {
      markOnboardingComplete();
      expect(storage.store["retro_hex_chat_onboarding_complete"]).toBe("true");
    });

    it("persists across subsequent reads", () => {
      markOnboardingComplete();
      expect(isOnboardingComplete()).toBe(true);
    });
  });
});
