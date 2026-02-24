import { createTitleFlasher } from "../../../js/lib/ui/title_flash.js";

describe("createTitleFlasher", () => {
  beforeEach(() => {
    vi.useFakeTimers();
    document.title = "RetroHexChat";
  });

  afterEach(() => {
    vi.useRealTimers();
    document.title = "";
  });

  it("starts flashing with activity message", () => {
    const flasher = createTitleFlasher();
    flasher.start("New PM");
    vi.advanceTimersByTime(1500);
    expect(document.title).toBe("New PM - RetroHexChat");
  });

  it("alternates between activity and original title", () => {
    const flasher = createTitleFlasher();
    flasher.start("Alert");
    vi.advanceTimersByTime(1500);
    expect(document.title).toContain("Alert");
    vi.advanceTimersByTime(1500);
    expect(document.title).toBe("RetroHexChat");
  });

  it("stops and restores original title", () => {
    const flasher = createTitleFlasher();
    flasher.start("Test");
    vi.advanceTimersByTime(1500);
    flasher.stop();
    expect(document.title).toBe("RetroHexChat");
  });

  it("reports isFlashing correctly", () => {
    const flasher = createTitleFlasher();
    expect(flasher.isFlashing()).toBe(false);
    flasher.start("Test");
    expect(flasher.isFlashing()).toBe(true);
    flasher.stop();
    expect(flasher.isFlashing()).toBe(false);
  });

  it("does not start duplicate intervals", () => {
    const flasher = createTitleFlasher();
    flasher.start("A");
    flasher.start("B");
    vi.advanceTimersByTime(1500);
    // Should still be "A" since second start was no-op
    expect(document.title).toContain("A");
  });

  it("stop is no-op when not flashing", () => {
    const flasher = createTitleFlasher();
    flasher.stop(); // Should not throw
    expect(flasher.isFlashing()).toBe(false);
  });

  it("uses custom interval", () => {
    const flasher = createTitleFlasher({ interval: 500 });
    flasher.start("Fast");
    vi.advanceTimersByTime(500);
    expect(document.title).toContain("Fast");
    vi.advanceTimersByTime(500);
    expect(document.title).toBe("RetroHexChat");
  });

  it("captures current title at start time", () => {
    document.title = "Custom Title";
    const flasher = createTitleFlasher();
    flasher.start("Alert");
    flasher.stop();
    expect(document.title).toBe("Custom Title");
  });
});
