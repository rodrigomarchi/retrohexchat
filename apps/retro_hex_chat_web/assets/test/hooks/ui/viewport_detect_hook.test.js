import { mountHook, cleanupDOM } from "../../helpers/hook_helper.js";
import ViewportDetectHook from "../../../js/hooks/ui/viewport_detect_hook.js";

describe("ViewportDetectHook", () => {
  const originalVisualViewport = window.visualViewport;
  const originalInnerWidth = window.innerWidth;
  const originalInnerHeight = window.innerHeight;

  afterEach(() => {
    cleanupDOM();
    Object.defineProperty(window, "innerWidth", {
      configurable: true,
      writable: true,
      value: originalInnerWidth,
    });
    Object.defineProperty(window, "innerHeight", {
      configurable: true,
      writable: true,
      value: originalInnerHeight,
    });
    Object.defineProperty(window, "visualViewport", {
      configurable: true,
      value: originalVisualViewport,
    });
    document.documentElement.removeAttribute("style");
  });

  function setViewport({
    width,
    height,
    visualWidth = width,
    visualHeight = height,
    offsetTop = 0,
    offsetLeft = 0,
  }) {
    Object.defineProperty(window, "innerWidth", {
      configurable: true,
      writable: true,
      value: width,
    });
    Object.defineProperty(window, "innerHeight", {
      configurable: true,
      writable: true,
      value: height,
    });
    Object.defineProperty(window, "visualViewport", {
      configurable: true,
      value: {
        width: visualWidth,
        height: visualHeight,
        offsetTop,
        offsetLeft,
        addEventListener: vi.fn(),
        removeEventListener: vi.fn(),
      },
    });
  }

  function focusEditable(tagName = "textarea") {
    const editable = document.createElement(tagName);
    document.body.appendChild(editable);
    editable.focus();
    return editable;
  }

  it("pushes mobile viewport info and writes visual viewport CSS variables", () => {
    setViewport({
      width: 390,
      height: 844,
      visualWidth: 384,
      visualHeight: 612,
      offsetTop: 12,
      offsetLeft: 3,
    });
    focusEditable();

    const hook = mountHook(ViewportDetectHook);

    expect(hook.pushEvent).toHaveBeenCalledWith("viewport_info", {
      width: 390,
      height: 844,
      visual_width: 384,
      visual_height: 612,
      mobile: true,
    });
    expect(document.documentElement.style.getPropertyValue("--rhc-visual-viewport-height")).toBe(
      "612px",
    );
    expect(document.documentElement.style.getPropertyValue("--rhc-visual-viewport-width")).toBe(
      "384px",
    );
    expect(
      document.documentElement.style.getPropertyValue("--rhc-visual-viewport-offset-left"),
    ).toBe("3px");
    expect(document.documentElement.style.getPropertyValue("--rhc-keyboard-inset-bottom")).toBe(
      "220px",
    );
    expect(document.documentElement.classList.contains("rhc-mobile-viewport")).toBe(true);
    expect(document.documentElement.classList.contains("rhc-keyboard-open")).toBe(true);
    expect(document.documentElement.dataset.rhcKeyboardOpen).toBe("true");

    hook.destroyed();
    expect(document.documentElement.classList.contains("rhc-keyboard-open")).toBe(false);
    expect(document.documentElement.dataset.rhcKeyboardOpen).toBeUndefined();
  });

  it("reports desktop when width reaches the shared 768px breakpoint", () => {
    setViewport({ width: 390, height: 844 });
    const hook = mountHook(ViewportDetectHook);
    hook.pushEvent.mockClear();

    setViewport({ width: 768, height: 844 });
    hook.updateViewport();

    expect(hook.pushEvent).toHaveBeenCalledWith(
      "viewport_info",
      expect.objectContaining({ width: 768, mobile: false }),
    );
    hook.destroyed();
  });

  it("updates visual viewport CSS without spamming the server for visual-only changes", () => {
    setViewport({ width: 390, height: 844, visualHeight: 844 });
    const hook = mountHook(ViewportDetectHook);
    hook.pushEvent.mockClear();

    setViewport({ width: 390, height: 844, visualHeight: 620 });
    hook.updateViewport();

    expect(document.documentElement.style.getPropertyValue("--rhc-visual-viewport-height")).toBe(
      "620px",
    );
    expect(hook.pushEvent).not.toHaveBeenCalled();
    hook.destroyed();
  });

  it("does not mark keyboard open when the viewport shrinks without editable focus", () => {
    setViewport({ width: 390, height: 844, visualHeight: 612 });

    const hook = mountHook(ViewportDetectHook);

    expect(document.documentElement.style.getPropertyValue("--rhc-keyboard-inset-bottom")).toBe(
      "232px",
    );
    expect(document.documentElement.classList.contains("rhc-keyboard-open")).toBe(false);
    expect(document.documentElement.dataset.rhcKeyboardOpen).toBe("false");
    hook.destroyed();
  });
});
