import { repositionMenu } from "../../../js/lib/ui/menu.js";
import "../../helpers/hook_helper.js"; // scrollIntoView stub
import { cleanupDOM } from "../../helpers/hook_helper.js";

describe("lib/menu", () => {
  afterEach(() => {
    cleanupDOM();
  });

  // ── repositionMenu ─────────────────────────────────────

  describe("repositionMenu", () => {
    it("flips left when overflowing right", () => {
      const el = document.createElement("div");
      el.style.position = "fixed";
      el.style.left = "950px";
      el.style.top = "100px";
      el.style.width = "200px";
      document.body.appendChild(el);

      // Mock viewport
      vi.spyOn(el, "getBoundingClientRect").mockReturnValue({
        left: 950,
        right: 1150,
        top: 100,
        bottom: 200,
        width: 200,
        height: 100,
      });
      Object.defineProperty(window, "innerWidth", { value: 1024, configurable: true });
      Object.defineProperty(window, "innerHeight", { value: 768, configurable: true });

      repositionMenu(el);
      expect(parseInt(el.style.left)).toBeLessThan(950);
    });

    it("flips up when overflowing bottom", () => {
      const el = document.createElement("div");
      el.style.position = "fixed";
      el.style.left = "100px";
      el.style.top = "700px";
      document.body.appendChild(el);

      vi.spyOn(el, "getBoundingClientRect").mockReturnValue({
        left: 100,
        right: 300,
        top: 700,
        bottom: 900,
        width: 200,
        height: 200,
      });
      Object.defineProperty(window, "innerWidth", { value: 1024, configurable: true });
      Object.defineProperty(window, "innerHeight", { value: 768, configurable: true });

      repositionMenu(el);
      expect(parseInt(el.style.top)).toBeLessThan(700);
    });

    it("does not change position when fits", () => {
      const el = document.createElement("div");
      el.style.position = "fixed";
      el.style.left = "100px";
      el.style.top = "100px";
      document.body.appendChild(el);

      vi.spyOn(el, "getBoundingClientRect").mockReturnValue({
        left: 100,
        right: 300,
        top: 100,
        bottom: 200,
        width: 200,
        height: 100,
      });
      Object.defineProperty(window, "innerWidth", { value: 1024, configurable: true });
      Object.defineProperty(window, "innerHeight", { value: 768, configurable: true });

      repositionMenu(el);
      expect(el.style.left).toBe("100px");
      expect(el.style.top).toBe("100px");
    });
  });
});
