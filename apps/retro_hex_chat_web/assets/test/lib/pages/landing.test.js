import { switchTab, createKonamiDetector, togglePopup } from "../../../js/lib/pages/landing.js";

describe("landing", () => {
  afterEach(() => {
    document.body.innerHTML = "";
  });

  // ── switchTab ───────────────────────────────────────────────

  describe("switchTab", () => {
    it("activates the selected tab and shows its panel", () => {
      document.body.innerHTML = `
        <button role="tab" aria-controls="panel-a" id="tab-a" class="landing-tab active" aria-selected="true">A</button>
        <button role="tab" aria-controls="panel-b" id="tab-b" class="landing-tab" aria-selected="false">B</button>
        <div id="panel-a" role="tabpanel">Content A</div>
        <div id="panel-b" role="tabpanel" hidden>Content B</div>
      `;

      const tabs = document.querySelectorAll('[role="tab"]');
      const tabB = document.getElementById("tab-b");

      switchTab(tabB, tabs);

      expect(tabB.getAttribute("aria-selected")).toBe("true");
      expect(tabB.classList.contains("active")).toBe(true);
      expect(document.getElementById("panel-b").hidden).toBe(false);

      const tabA = document.getElementById("tab-a");
      expect(tabA.getAttribute("aria-selected")).toBe("false");
      expect(tabA.classList.contains("active")).toBe(false);
      expect(document.getElementById("panel-a").hidden).toBe(true);
    });
  });

  // ── createKonamiDetector ────────────────────────────────────

  describe("createKonamiDetector", () => {
    it("returns true when the full Konami code is entered", () => {
      const detect = createKonamiDetector();
      const sequence = [
        "ArrowUp",
        "ArrowUp",
        "ArrowDown",
        "ArrowDown",
        "ArrowLeft",
        "ArrowRight",
        "ArrowLeft",
        "ArrowRight",
        "b",
        "a",
      ];

      for (let i = 0; i < sequence.length - 1; i++) {
        expect(detect(sequence[i])).toBe(false);
      }
      expect(detect(sequence[sequence.length - 1])).toBe(true);
    });

    it("resets on wrong key", () => {
      const detect = createKonamiDetector();
      detect("ArrowUp");
      detect("ArrowUp");
      detect("x"); // wrong key
      detect("ArrowDown"); // should not advance

      // Start over
      const sequence = [
        "ArrowUp",
        "ArrowUp",
        "ArrowDown",
        "ArrowDown",
        "ArrowLeft",
        "ArrowRight",
        "ArrowLeft",
        "ArrowRight",
        "b",
        "a",
      ];
      let result = false;
      for (const key of sequence) {
        result = detect(key);
      }
      expect(result).toBe(true);
    });

    it("can be triggered multiple times", () => {
      const detect = createKonamiDetector();
      const sequence = [
        "ArrowUp",
        "ArrowUp",
        "ArrowDown",
        "ArrowDown",
        "ArrowLeft",
        "ArrowRight",
        "ArrowLeft",
        "ArrowRight",
        "b",
        "a",
      ];

      // First time
      for (const key of sequence) detect(key);

      // Second time
      let result = false;
      for (const key of sequence) {
        result = detect(key);
      }
      expect(result).toBe(true);
    });
  });

  // ── togglePopup ─────────────────────────────────────────────

  describe("togglePopup", () => {
    it("shows a hidden popup", () => {
      document.body.innerHTML = '<div id="test-popup" hidden></div>';
      togglePopup("test-popup", true);
      expect(document.getElementById("test-popup").hidden).toBe(false);
    });

    it("hides a visible popup", () => {
      document.body.innerHTML = '<div id="test-popup"></div>';
      togglePopup("test-popup", false);
      expect(document.getElementById("test-popup").hidden).toBe(true);
    });

    it("does nothing for non-existent popup", () => {
      expect(() => togglePopup("nonexistent", true)).not.toThrow();
    });
  });
});
