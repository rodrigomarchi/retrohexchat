import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";

import { FullscreenToggleController } from "../../../js/lib/space/fullscreen.js";

describe("FullscreenToggleController", () => {
  let button;
  let target;
  let controller;
  // jsdom implements neither the Fullscreen API nor fullscreenElement; the
  // test drives both through mocks + a configurable property.
  let fullscreenEl;

  beforeEach(() => {
    button = document.createElement("button");
    target = document.createElement("div");
    document.body.append(button, target);

    fullscreenEl = null;
    Object.defineProperty(document, "fullscreenElement", {
      configurable: true,
      get: () => fullscreenEl,
    });
    target.requestFullscreen = vi.fn(() => {
      fullscreenEl = target;
      document.dispatchEvent(new Event("fullscreenchange"));
      return Promise.resolve();
    });
    document.exitFullscreen = vi.fn(() => {
      fullscreenEl = null;
      document.dispatchEvent(new Event("fullscreenchange"));
      return Promise.resolve();
    });

    controller = new FullscreenToggleController({ button, target });
    controller.attach();
  });

  afterEach(() => {
    controller.detach();
    delete document.fullscreenElement;
    delete document.exitFullscreen;
    button.remove();
    target.remove();
  });

  it("requests fullscreen on the target and marks the button", () => {
    button.click();

    expect(target.requestFullscreen).toHaveBeenCalled();
    expect(button.hasAttribute("data-fullscreen")).toBe(true);
  });

  it("the same button exits fullscreen and clears the mark", () => {
    button.click(); // enter
    button.click(); // exit

    expect(document.exitFullscreen).toHaveBeenCalled();
    expect(button.hasAttribute("data-fullscreen")).toBe(false);
  });

  it("stays in sync when fullscreen ends outside the button (Esc)", () => {
    button.click();
    expect(button.hasAttribute("data-fullscreen")).toBe(true);

    // The UA exits on its own (Esc): only the change event fires.
    fullscreenEl = null;
    document.dispatchEvent(new Event("fullscreenchange"));

    expect(button.hasAttribute("data-fullscreen")).toBe(false);
  });

  it("ignores fullscreen held by another element", () => {
    fullscreenEl = document.createElement("video");
    document.dispatchEvent(new Event("fullscreenchange"));
    expect(button.hasAttribute("data-fullscreen")).toBe(false);

    // Clicking while another element is fullscreen still requests our target.
    button.click();
    expect(target.requestFullscreen).toHaveBeenCalled();
  });

  it("detach stops reacting to clicks and change events", () => {
    controller.detach();

    button.click();
    expect(target.requestFullscreen).not.toHaveBeenCalled();

    fullscreenEl = target;
    document.dispatchEvent(new Event("fullscreenchange"));
    expect(button.hasAttribute("data-fullscreen")).toBe(false);
  });
});
