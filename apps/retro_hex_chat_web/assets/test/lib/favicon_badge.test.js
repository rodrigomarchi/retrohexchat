import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { createFaviconBadge } from "../../js/lib/favicon_badge.js";

describe("favicon_badge", () => {
  let badge;
  let linkEl;

  beforeEach(() => {
    linkEl = document.createElement("link");
    linkEl.rel = "icon";
    linkEl.href = "http://localhost/favicon.ico";
    document.head.appendChild(linkEl);

    // Mock Image constructor
    vi.stubGlobal(
      "Image",
      class {
        constructor() {
          this.crossOrigin = null;
          this.onload = null;
          this.onerror = null;
          this._src = "";
        }

        get src() {
          return this._src;
        }

        set src(val) {
          this._src = val;
          // Simulate async load
          if (this.onload) {
            setTimeout(() => this.onload(), 0);
          }
        }
      },
    );

    // Mock canvas
    const mockCtx = {
      drawImage: vi.fn(),
      beginPath: vi.fn(),
      arc: vi.fn(),
      fill: vi.fn(),
      stroke: vi.fn(),
      fillStyle: "",
      strokeStyle: "",
      lineWidth: 0,
    };

    vi.spyOn(document, "createElement").mockImplementation((tag) => {
      if (tag === "canvas") {
        return {
          width: 0,
          height: 0,
          getContext: vi.fn(() => mockCtx),
          toDataURL: vi.fn(() => "data:image/png;base64,badge"),
        };
      }
      return document.createElementNS("http://www.w3.org/1999/xhtml", tag);
    });

    badge = createFaviconBadge();
  });

  afterEach(() => {
    document.head.innerHTML = "";
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
  });

  describe("isActive", () => {
    it("returns false initially", () => {
      expect(badge.isActive()).toBe(false);
    });
  });

  describe("show", () => {
    it("sets active to true after image loads", async () => {
      badge.show();
      await vi.waitFor(() => expect(badge.isActive()).toBe(true));
    });

    it("updates link href to canvas data URL", async () => {
      badge.show();
      await vi.waitFor(() => expect(linkEl.href).toBe("data:image/png;base64,badge"));
    });

    it("does not re-draw if already active", async () => {
      badge.show();
      await vi.waitFor(() => expect(badge.isActive()).toBe(true));

      const hrefAfterFirst = linkEl.href;
      badge.show();
      // Still the same href — no second draw
      expect(linkEl.href).toBe(hrefAfterFirst);
    });
  });

  describe("clear", () => {
    it("restores original favicon href", async () => {
      badge.show();
      await vi.waitFor(() => expect(badge.isActive()).toBe(true));

      badge.clear();
      expect(linkEl.href).toBe("http://localhost/favicon.ico");
      expect(badge.isActive()).toBe(false);
    });

    it("does nothing when not active", () => {
      badge.clear();
      expect(linkEl.href).toBe("http://localhost/favicon.ico");
      expect(badge.isActive()).toBe(false);
    });
  });

  describe("missing favicon", () => {
    it("handles missing link element gracefully", () => {
      document.head.innerHTML = "";
      const b = createFaviconBadge();
      // Should not throw
      b.show();
      expect(b.isActive()).toBe(false);
    });
  });
});
