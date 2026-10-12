import { describe, it, expect, vi } from "vitest";
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

    it("hands a modal another module draws to the panel port", () => {
      const el = shellWithLoading();
      const host = el.querySelector("[data-space-modal]");
      const board = vi.fn();
      const panel = vi.fn((target, modal) => {
        target.textContent = modal.kind;
        return modal.kind === "sign";
      });
      const overlays = createSpaceOverlays(el, { board, panel });

      overlays.renderModal({ kind: "sign" });
      expect(host.hidden).toBe(false);
      expect(host.textContent).toBe("sign");
      expect(board).not.toHaveBeenCalled();

      overlays.renderModal({ kind: "image", title: "Chess" });
      expect(board).toHaveBeenCalledOnce();
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

  describe("a gate's confirm", () => {
    function gateShell() {
      const el = document.createElement("div");
      el.innerHTML = `
        <div data-space-modal hidden data-confirm-enter_construct="Enter the Construct?"></div>
        <template data-space-confirm-template>
          <p data-space-modal-question></p>
          <div><button data-space-modal-yes>Yes</button><button data-space-modal-no>No</button></div>
        </template>`;
      return el;
    }

    it("asks the server's question with the app's own buttons, and answers through the ports", () => {
      const el = gateShell();
      const confirm = vi.fn();
      const cancel = vi.fn();
      const overlays = createSpaceOverlays(el, { confirm, cancel });

      overlays.renderModal({ kind: "confirm", action: "enter_construct", title: "Construct" });

      const host = el.querySelector("[data-space-modal]");
      expect(host.hidden).toBe(false);
      expect(host.querySelector("[data-space-modal-question]").textContent).toBe(
        "Enter the Construct?",
      );
      host.querySelector("[data-space-modal-yes]").click();
      host.querySelector("[data-space-modal-no]").click();
      expect(confirm).toHaveBeenCalledOnce();
      expect(cancel).toHaveBeenCalledOnce();
    });

    it("falls back to the gate's title for an action with no sentence", () => {
      const el = gateShell();
      const overlays = createSpaceOverlays(el);
      overlays.renderModal({ kind: "confirm", action: "somewhere_else", title: "Somewhere" });
      expect(el.querySelector("[data-space-modal-question]").textContent).toBe("Somewhere");
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
