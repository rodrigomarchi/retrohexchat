import { createToastElement, animateIn, animateOut } from "../../../js/lib/notifications/toast.js";
import { cleanupDOM } from "../../helpers/hook_helper.js";

describe("toast", () => {
  afterEach(() => {
    cleanupDOM();
  });

  const makeTip = (overrides = {}) => ({
    id: "first_message",
    text: "Use ↑ to edit your last message",
    ...overrides,
  });

  // ── createToastElement ────────────────────────────────────

  describe("createToastElement", () => {
    it("creates a wrapper with toast-notification class", () => {
      const el = createToastElement(makeTip(), { onDismiss: vi.fn() });
      expect(el.classList.contains("toast-notification")).toBe(true);
    });

    it("sets role=status and aria-live=polite for accessibility", () => {
      const el = createToastElement(makeTip(), { onDismiss: vi.fn() });
      expect(el.getAttribute("role")).toBe("status");
      expect(el.getAttribute("aria-live")).toBe("polite");
    });

    it("stores tip id in data attribute", () => {
      const el = createToastElement(makeTip({ id: "first_join" }), { onDismiss: vi.fn() });
      expect(el.dataset.tipId).toBe("first_join");
    });

    it("contains a retro-styled window with title-bar", () => {
      const el = createToastElement(makeTip(), { onDismiss: vi.fn() });
      const win = el.querySelector(".window");
      expect(win).not.toBeNull();
      const titleBar = win.querySelector(".title-bar");
      expect(titleBar).not.toBeNull();
      expect(titleBar.querySelector(".title-bar-text").textContent).toBe("Tip");
    });

    it("contains the tip text", () => {
      const tip = makeTip({ text: "Custom text here" });
      const el = createToastElement(tip, { onDismiss: vi.fn() });
      expect(el.querySelector(".toast-text").textContent).toBe("Custom text here");
    });

    it("contains a Got it! dismiss button", () => {
      const el = createToastElement(makeTip(), { onDismiss: vi.fn() });
      const button = el.querySelector("button");
      expect(button).not.toBeNull();
      expect(button.textContent).toBe("Got it!");
    });

    it("contains a suppress checkbox by default", () => {
      const el = createToastElement(makeTip(), { onDismiss: vi.fn() });
      const checkbox = el.querySelector('input[type="checkbox"]');
      expect(checkbox).not.toBeNull();
      const label = el.querySelector(".toast-checkbox label");
      expect(label.textContent).toBe("Don't show tips again");
    });

    it("omits checkbox when showCheckbox is false", () => {
      const el = createToastElement(makeTip(), {
        showCheckbox: false,
        onDismiss: vi.fn(),
      });
      const checkbox = el.querySelector('input[type="checkbox"]');
      expect(checkbox).toBeNull();
    });

    it("calls onDismiss with false when button clicked and checkbox unchecked", () => {
      const onDismiss = vi.fn();
      const el = createToastElement(makeTip(), { onDismiss });
      document.body.appendChild(el);

      const button = el.querySelector("button");
      button.click();

      expect(onDismiss).toHaveBeenCalledWith(false);
    });

    it("calls onDismiss with true when button clicked and checkbox is checked", () => {
      const onDismiss = vi.fn();
      const el = createToastElement(makeTip(), { onDismiss });
      document.body.appendChild(el);

      const checkbox = el.querySelector('input[type="checkbox"]');
      // Simulate checking the checkbox (since mousedown is prevented, set directly)
      checkbox.checked = true;

      const button = el.querySelector("button");
      button.click();

      expect(onDismiss).toHaveBeenCalledWith(true);
    });

    it("button mousedown is prevented to avoid stealing focus", () => {
      const el = createToastElement(makeTip(), { onDismiss: vi.fn() });
      document.body.appendChild(el);

      const button = el.querySelector("button");
      const event = new MouseEvent("mousedown", { cancelable: true });
      button.dispatchEvent(event);

      expect(event.defaultPrevented).toBe(true);
    });
  });

  // ── animateIn ─────────────────────────────────────────────

  describe("animateIn", () => {
    it("adds toast-visible class", () => {
      const el = document.createElement("div");
      el.className = "toast-notification";
      animateIn(el);
      expect(el.classList.contains("toast-visible")).toBe(true);
    });
  });

  // ── animateOut ────────────────────────────────────────────

  describe("animateOut", () => {
    it("removes toast-visible and adds toast-hiding class", async () => {
      const el = document.createElement("div");
      el.className = "toast-notification toast-visible";
      document.body.appendChild(el);

      const promise = animateOut(el);

      expect(el.classList.contains("toast-visible")).toBe(false);
      expect(el.classList.contains("toast-hiding")).toBe(true);

      // Resolve via the fallback timeout
      await promise;
    });

    it("returns a promise that resolves", async () => {
      const el = document.createElement("div");
      el.className = "toast-notification toast-visible";
      document.body.appendChild(el);

      await expect(animateOut(el)).resolves.toBeUndefined();
    });
  });
});
