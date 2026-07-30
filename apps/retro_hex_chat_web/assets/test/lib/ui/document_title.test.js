import { createDocumentTitle } from "../../../js/lib/ui/document_title.js";

describe("createDocumentTitle", () => {
  beforeEach(() => {
    vi.useFakeTimers();
    document.title = "RetroHexChat";
  });

  afterEach(() => {
    vi.useRealTimers();
    document.title = "";
  });

  it("adopts the current title as its base", () => {
    const title = createDocumentTitle();
    title.startFlash("Alert");
    expect(document.title).toBe("Alert - RetroHexChat");
  });

  it("applies a new base immediately", () => {
    const title = createDocumentTitle();
    title.setBase("#lobby[Troll]");
    expect(document.title).toBe("#lobby[Troll]");
  });

  it("ignores blank and non-string bases", () => {
    const title = createDocumentTitle();
    title.setBase("#lobby[Troll]");
    title.setBase("");
    title.setBase("   ");
    title.setBase(null);
    expect(document.title).toBe("#lobby[Troll]");
  });

  it("shows the flash message right away, then alternates", () => {
    const title = createDocumentTitle();
    title.startFlash("New PM");
    expect(document.title).toBe("New PM - RetroHexChat");
    vi.advanceTimersByTime(1500);
    expect(document.title).toBe("RetroHexChat");
    vi.advanceTimersByTime(1500);
    expect(document.title).toBe("New PM - RetroHexChat");
  });

  it("carries a base change into both halves of a running flash", () => {
    const title = createDocumentTitle();
    title.startFlash("Alert");
    title.setBase("Joe:Troll");
    expect(document.title).toBe("Alert - Joe:Troll");
    vi.advanceTimersByTime(1500);
    expect(document.title).toBe("Joe:Troll");
  });

  it("stops on the base title, not on the one captured at start", () => {
    const title = createDocumentTitle();
    title.startFlash("Alert");
    title.setBase("#retro[Troll]");
    title.stopFlash();
    expect(document.title).toBe("#retro[Troll]");
  });

  it("reports isFlashing correctly", () => {
    const title = createDocumentTitle();
    expect(title.isFlashing()).toBe(false);
    title.startFlash("Test");
    expect(title.isFlashing()).toBe(true);
    title.stopFlash();
    expect(title.isFlashing()).toBe(false);
  });

  it("does not start duplicate intervals", () => {
    const title = createDocumentTitle();
    title.startFlash("A");
    title.startFlash("B");
    expect(document.title).toContain("A");
  });

  it("stopFlash is a no-op when not flashing", () => {
    const title = createDocumentTitle();
    title.setBase("#lobby[Troll]");
    title.stopFlash();
    expect(title.isFlashing()).toBe(false);
    expect(document.title).toBe("#lobby[Troll]");
  });

  it("uses a custom interval", () => {
    const title = createDocumentTitle({ interval: 500 });
    title.startFlash("Fast");
    expect(document.title).toContain("Fast");
    vi.advanceTimersByTime(500);
    expect(document.title).toBe("RetroHexChat");
  });
});
