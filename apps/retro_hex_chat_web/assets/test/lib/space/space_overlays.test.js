import { createSpaceOverlays } from "../../../js/lib/space/space_overlays.js";

function shellWithLoading() {
  const el = document.createElement("div");
  el.innerHTML = `
    <div data-space-loading>
      <div data-space-loading-panel aria-label="Channel Space: Entering...">
        <span data-space-loading-text>Entering...</span>
      </div>
    </div>
    <div data-space-modal hidden></div>
  `;
  return el;
}

describe("createSpaceOverlays", () => {
  describe("loading indicator", () => {
    it("updates the status text and mirrors it into the panel aria-label", () => {
      const el = shellWithLoading();
      const overlays = createSpaceOverlays(el);
      overlays.setLoadingText("Loading room...");
      expect(el.querySelector("[data-space-loading-text]").textContent).toBe("Loading room...");
      expect(el.querySelector("[data-space-loading-panel]").getAttribute("aria-label")).toBe(
        "Channel Space: Loading room...",
      );
    });

    it("hides the panel and latches it so a later status cannot flash it back", () => {
      const el = shellWithLoading();
      const overlays = createSpaceOverlays(el);
      overlays.hideLoading();
      const host = el.querySelector("[data-space-loading]");
      expect(host.hidden).toBe(true);
      expect(host.getAttribute("aria-hidden")).toBe("true");

      overlays.setLoadingText("Could not open space.");
      expect(el.querySelector("[data-space-loading-text]").textContent).toBe("Entering...");
    });

    it("is inert when the shell has no loading host", () => {
      const el = document.createElement("div");
      const overlays = createSpaceOverlays(el);
      expect(() => {
        overlays.setLoadingText("x");
        overlays.hideLoading();
      }).not.toThrow();
    });
  });

  describe("board modal", () => {
    it("clears and hides the modal host when the modal closes", () => {
      const el = shellWithLoading();
      const host = el.querySelector("[data-space-modal]");
      host.hidden = false;
      host.appendChild(document.createElement("span"));
      const overlays = createSpaceOverlays(el);
      overlays.renderModal(null);
      expect(host.hidden).toBe(true);
      expect(host.childNodes.length).toBe(0);
    });

    it("renders the title and appends the drawn board canvas", () => {
      const el = shellWithLoading();
      const host = el.querySelector("[data-space-modal]");
      const drawnCanvas = document.createElement("canvas");
      const overlays = createSpaceOverlays(el, {
        board: (asset) => (asset === "chess" ? { canvas: drawnCanvas } : null),
      });
      overlays.renderModal({ title: "Chess", asset: "chess" });
      expect(host.hidden).toBe(false);
      expect(host.querySelector(".font-bold").textContent).toBe("Chess");
      expect(host.contains(drawnCanvas)).toBe(true);
    });

    it("renders the title alone when the board has no canvas", () => {
      const el = shellWithLoading();
      const host = el.querySelector("[data-space-modal]");
      const overlays = createSpaceOverlays(el, { board: () => null });
      overlays.renderModal({ title: "Empty" });
      expect(host.querySelector(".font-bold").textContent).toBe("Empty");
      expect(host.querySelector("canvas")).toBe(null);
    });
  });

  describe("spoken lines", () => {
    it("puts the last line said into the live region, in words", () => {
      const el = document.createElement("div");
      el.innerHTML = `<div data-space-said aria-live="polite"></div>`;
      const overlays = createSpaceOverlays(el);

      overlays.announceLine({ nickname: "lumen", text: "party at the lamp" });
      expect(el.querySelector("[data-space-said]").textContent).toBe("lumen: party at the lamp");

      overlays.announceLine({ nickname: "kestrel", text: "" });
      expect(el.querySelector("[data-space-said]").textContent).toBe("lumen: party at the lamp");
    });

    it("is inert when the shell has no live region", () => {
      expect(() =>
        createSpaceOverlays(document.createElement("div")).announceLine({ text: "hi" }),
      ).not.toThrow();
    });
  });

  describe("knockouts", () => {
    function region() {
      const el = document.createElement("div");
      el.innerHTML = `<div data-space-said data-ko-text="%{name} is down!" data-getup-text="%{name} is back up"></div>`;
      return el;
    }

    it("says who went down and who got back up, from the server's sentences", () => {
      const el = region();
      const overlays = createSpaceOverlays(el);

      overlays.announceAction({ kind: "ko", nickname: "kestrel" });
      expect(el.querySelector("[data-space-said]").textContent).toBe("kestrel is down!");

      overlays.announceAction({ kind: "getup", nickname: "kestrel" });
      expect(el.querySelector("[data-space-said]").textContent).toBe("kestrel is back up");
    });

    it("stays quiet about every other action", () => {
      const el = region();
      const overlays = createSpaceOverlays(el);

      overlays.announceAction({ kind: "hit", nickname: "kestrel" });
      overlays.announceAction({ kind: "sword", nickname: "kestrel" });
      overlays.announceAction({ kind: "ko" });
      expect(el.querySelector("[data-space-said]").textContent).toBe("");
    });
  });
});
