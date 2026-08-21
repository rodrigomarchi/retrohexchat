import { mountHook, simulateEvent, cleanupDOM } from "../../helpers/hook_helper.js";
import DocumentTitleHook from "../../../js/hooks/notifications/document_title_hook.js";

describe("DocumentTitleHook", () => {
  let hook;

  function mount(title = "#lobby[Troll]") {
    return mountHook(DocumentTitleHook, { attrs: { "data-title": title } });
  }

  beforeEach(() => {
    vi.useFakeTimers();
    document.title = "RetroHexChat";
    hook = mount();
  });

  afterEach(() => {
    if (hook.destroyed) hook.destroyed();
    vi.useRealTimers();
    document.title = "";
    cleanupDOM();
  });

  it("applies the server-rendered title on mount", () => {
    expect(document.title).toBe("#lobby[Troll]");
  });

  it("follows the title through a patch", () => {
    hook.el.dataset.title = "Joe:Troll";
    hook.updated();
    expect(document.title).toBe("Joe:Troll");
  });

  it("ignores a blank title", () => {
    hook.el.dataset.title = "";
    hook.updated();
    expect(document.title).toBe("#lobby[Troll]");
  });

  it("starts flashing on title_flash_start", () => {
    simulateEvent(hook, "title_flash_start", { message: "New PM" });
    expect(document.title).toBe("New PM - #lobby[Troll]");
  });

  it("alternates between the flash message and the base title", () => {
    simulateEvent(hook, "title_flash_start", { message: "Alert" });
    vi.advanceTimersByTime(1500);
    expect(document.title).toBe("#lobby[Troll]");
    vi.advanceTimersByTime(1500);
    expect(document.title).toContain("Alert");
  });

  it("stops flashing on title_flash_stop", () => {
    simulateEvent(hook, "title_flash_start", { message: "Test" });
    simulateEvent(hook, "title_flash_stop", {});
    expect(document.title).toBe("#lobby[Troll]");
  });

  it("uses the default message when none is provided", () => {
    simulateEvent(hook, "title_flash_start", {});
    expect(document.title).toContain("New activity");
  });

  it("does not start duplicate intervals", () => {
    simulateEvent(hook, "title_flash_start", { message: "A" });
    simulateEvent(hook, "title_flash_start", { message: "B" });
    expect(document.title).toContain("A");
  });

  it("switching conversation mid-flash leaves the new title behind", () => {
    simulateEvent(hook, "title_flash_start", { message: "Alert" });
    hook.el.dataset.title = "#retro[Troll]";
    hook.updated();
    expect(document.title).toBe("Alert - #retro[Troll]");

    simulateEvent(hook, "title_flash_stop", {});
    expect(document.title).toBe("#retro[Troll]");
  });

  it("pushes tab_focused when the tab comes back and the socket is up", () => {
    simulateEvent(hook, "title_flash_start", { message: "Test" });

    document.dispatchEvent(new Event("visibilitychange"));

    expect(hook.pushEvent).toHaveBeenCalledWith("tab_focused", {});
    expect(hook.title.isFlashing()).toBe(false);
  });

  it("still stops the flash when the socket is gone", () => {
    // Regression: pushEvent throws when LiveView is not connected, which
    // skipped stopFlash() and left the title announcing activity to someone
    // already looking at the tab. Seen in production RUM on 2026-08-21.
    hook.__connected = false;
    simulateEvent(hook, "title_flash_start", { message: "Test" });

    document.dispatchEvent(new Event("visibilitychange"));

    expect(hook.title.isFlashing()).toBe(false);
    expect(document.title).toBe("#lobby[Troll]");
    expect(hook.pushEvent).not.toHaveBeenCalledWith("tab_focused", {});
  });

  it("stops flashing and drops its listener on destroy", () => {
    simulateEvent(hook, "title_flash_start", { message: "Test" });
    hook.destroyed();
    expect(hook.title.isFlashing()).toBe(false);
    expect(document.title).toBe("#lobby[Troll]");

    document.dispatchEvent(new Event("visibilitychange"));
    expect(hook.pushEvent).not.toHaveBeenCalledWith("tab_focused", {});
  });
});
