import { repositionMenu, createMenuNavigator } from "../../js/lib/menu.js";
import "../helpers/hook_helper.js"; // scrollIntoView stub
import { cleanupDOM } from "../helpers/hook_helper.js";

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

  // ── createMenuNavigator ────────────────────────────────

  describe("createMenuNavigator", () => {
    function makeItems(count) {
      const items = [];
      for (let i = 0; i < count; i++) {
        const li = document.createElement("li");
        li.textContent = `Item ${i}`;
        document.body.appendChild(li);
        items.push(li);
      }
      return items;
    }

    it("moveFocus(1) focuses first item from -1", () => {
      const items = makeItems(3);
      const nav = createMenuNavigator(() => items);
      nav.moveFocus(1);
      expect(nav.focusedIndex).toBe(0);
      expect(items[0].classList.contains("focused")).toBe(true);
    });

    it("moveFocus(-1) focuses last item from -1", () => {
      const items = makeItems(3);
      const nav = createMenuNavigator(() => items);
      nav.moveFocus(-1);
      expect(nav.focusedIndex).toBe(2);
    });

    it("wraps from last to first", () => {
      const items = makeItems(3);
      const nav = createMenuNavigator(() => items);
      nav.moveFocus(-1); // → 2
      nav.moveFocus(1); // → 0
      expect(nav.focusedIndex).toBe(0);
    });

    it("wraps from first to last", () => {
      const items = makeItems(3);
      const nav = createMenuNavigator(() => items);
      nav.moveFocus(1); // → 0
      nav.moveFocus(-1); // → 2
      expect(nav.focusedIndex).toBe(2);
    });

    it("clearFocus removes focused class", () => {
      const items = makeItems(3);
      const nav = createMenuNavigator(() => items);
      nav.moveFocus(1);
      nav.clearFocus();
      expect(items[0].classList.contains("focused")).toBe(false);
    });

    it("selectFocused clicks the item", () => {
      const items = makeItems(3);
      let clicked = false;
      items[0].addEventListener("click", () => {
        clicked = true;
      });
      const nav = createMenuNavigator(() => items);
      nav.moveFocus(1);
      nav.selectFocused();
      expect(clicked).toBe(true);
    });

    it("reset clears focus and index", () => {
      const items = makeItems(3);
      const nav = createMenuNavigator(() => items);
      nav.moveFocus(1);
      nav.reset();
      expect(nav.focusedIndex).toBe(-1);
      expect(items[0].classList.contains("focused")).toBe(false);
    });
  });
});
