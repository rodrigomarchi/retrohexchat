import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { createFeedbackToastElement, showFeedbackToast } from "../../js/lib/feedback_toast.js";

describe("feedback_toast", () => {
  describe("createFeedbackToastElement", () => {
    it("creates a toast-notification wrapper", () => {
      const el = createFeedbackToastElement("Copiado!");
      expect(el.classList.contains("toast-notification")).toBe(true);
      expect(el.getAttribute("role")).toBe("status");
    });

    it('has title bar with text "Info"', () => {
      const el = createFeedbackToastElement("Copiado!");
      const title = el.querySelector(".title-bar-text");
      expect(title.textContent).toBe("Info");
    });

    it("displays the message in toast-text", () => {
      const el = createFeedbackToastElement("Configurações salvas");
      const text = el.querySelector(".toast-text");
      expect(text.textContent).toBe("Configurações salvas");
    });

    it("has an OK button", () => {
      const el = createFeedbackToastElement("Copiado!");
      const btn = el.querySelector("button");
      expect(btn.textContent).toBe("OK");
    });

    it("has no checkbox (unlike tip toasts)", () => {
      const el = createFeedbackToastElement("Copiado!");
      const checkbox = el.querySelector('input[type="checkbox"]');
      expect(checkbox).toBeNull();
    });
  });

  describe("showFeedbackToast", () => {
    let hookEl;

    beforeEach(() => {
      vi.useFakeTimers();
      hookEl = document.createElement("div");
      const container = document.createElement("div");
      container.className = "toast-container";
      hookEl.appendChild(container);
    });

    afterEach(() => {
      vi.useRealTimers();
    });

    it("appends a toast to the container", () => {
      showFeedbackToast(hookEl, "Copiado!", 2000);
      const container = hookEl.querySelector(".toast-container");
      expect(container.children.length).toBe(1);
    });

    it("does nothing when no container exists", () => {
      const emptyEl = document.createElement("div");
      showFeedbackToast(emptyEl, "Copiado!", 2000);
      // Should not throw
    });
  });
});
