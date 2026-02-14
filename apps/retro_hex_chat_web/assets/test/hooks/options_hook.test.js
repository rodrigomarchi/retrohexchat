import { mountHook, simulateEvent, cleanupDOM } from "../helpers/hook_helper.js";
import OptionsHook from "../../js/hooks/options_hook.js";

describe("OptionsHook", () => {
  let hook;

  beforeEach(() => {
    hook = mountHook(OptionsHook);
  });

  afterEach(() => {
    // Clean up CSS custom properties
    document.documentElement.style.removeProperty("--chat-font-family");
    document.documentElement.style.removeProperty("--chat-font-size");
    cleanupDOM();
  });

  it("applies CSS custom properties from server event", () => {
    simulateEvent(hook, "apply_preferences", {
      styles: {
        "--chat-font-family": "Courier New",
        "--chat-font-size": "14px",
      },
    });

    expect(document.documentElement.style.getPropertyValue("--chat-font-family")).toBe(
      "Courier New",
    );
    expect(document.documentElement.style.getPropertyValue("--chat-font-size")).toBe("14px");
  });

  it("handles empty styles gracefully", () => {
    simulateEvent(hook, "apply_preferences", { styles: {} });
    // Should not throw
  });

  it("handles missing styles key", () => {
    simulateEvent(hook, "apply_preferences", {});
    // Should not throw
  });
});
