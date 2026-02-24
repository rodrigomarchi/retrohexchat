import { mountHook, simulateEvent, cleanupDOM } from "../../helpers/hook_helper.js";
import TitleFlashHook from "../../../js/hooks/notifications/title_flash_hook.js";

describe("TitleFlashHook", () => {
  let hook;

  beforeEach(() => {
    vi.useFakeTimers();
    document.title = "RetroHexChat";
    hook = mountHook(TitleFlashHook);
  });

  afterEach(() => {
    if (hook.destroyed) hook.destroyed();
    vi.useRealTimers();
    document.title = "";
    cleanupDOM();
  });

  it("starts flashing title on title_flash_start", () => {
    simulateEvent(hook, "title_flash_start", { message: "New PM" });
    vi.advanceTimersByTime(1500);
    expect(document.title).toBe("New PM - RetroHexChat");
  });

  it("alternates between original and flash title", () => {
    simulateEvent(hook, "title_flash_start", { message: "Alert" });
    vi.advanceTimersByTime(1500);
    expect(document.title).toContain("Alert");
    vi.advanceTimersByTime(1500);
    expect(document.title).toBe("RetroHexChat");
  });

  it("stops flashing on title_flash_stop", () => {
    simulateEvent(hook, "title_flash_start", { message: "Test" });
    vi.advanceTimersByTime(1500);
    simulateEvent(hook, "title_flash_stop", {});
    expect(document.title).toBe("RetroHexChat");
  });

  it("uses default message when none provided", () => {
    simulateEvent(hook, "title_flash_start", {});
    vi.advanceTimersByTime(1500);
    expect(document.title).toContain("New activity");
  });

  it("does not start duplicate intervals", () => {
    simulateEvent(hook, "title_flash_start", { message: "A" });
    simulateEvent(hook, "title_flash_start", { message: "B" });
    // Should still be using first interval
    vi.advanceTimersByTime(1500);
    expect(document.title).toContain("A");
  });

  it("cleans up on destroy", () => {
    simulateEvent(hook, "title_flash_start", { message: "Test" });
    hook.destroyed();
    expect(hook.flasher.isFlashing()).toBe(false);
    expect(document.title).toBe("RetroHexChat");
  });
});
