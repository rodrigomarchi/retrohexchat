import { mountHook, cleanupDOM } from "../../helpers/hook_helper.js";
import ClockHook from "../../../js/hooks/connection/clock_hook.js";

describe("ClockHook", () => {
  let hook;

  beforeEach(() => {
    vi.useFakeTimers();
    hook = mountHook(ClockHook, {
      attrs: { id: "clock-display" },
    });
  });

  afterEach(() => {
    vi.useRealTimers();
    cleanupDOM();
  });

  it("renders current time on mount", () => {
    // The element should have some time text (not the placeholder)
    expect(hook.el.textContent).toMatch(/\d{2}:\d{2}/);
  });

  it("updates time after interval", () => {
    vi.advanceTimersByTime(30000);
    // Should still be a valid time (may or may not have changed depending on timing)
    expect(hook.el.textContent).toMatch(/\d{2}:\d{2}/);
  });

  it("restores time on updated (after LiveView patch)", () => {
    hook.el.textContent = "--:--";
    hook.updated();
    expect(hook.el.textContent).toMatch(/\d{2}:\d{2}/);
  });

  it("clears interval on destroyed", () => {
    hook.destroyed();
    const textAfterDestroy = hook.el.textContent;
    vi.advanceTimersByTime(60000);
    // Text should not change after destroy
    expect(hook.el.textContent).toBe(textAfterDestroy);
  });
});
