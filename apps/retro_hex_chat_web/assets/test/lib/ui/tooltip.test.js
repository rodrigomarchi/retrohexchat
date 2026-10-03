import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import {
  installRetroTooltips,
  placeTooltip,
  restoreTitle,
  stashTitle,
} from "../../../js/lib/ui/tooltip";

describe("tooltip", () => {
  let uninstall;
  let clock;

  const tip = () => document.querySelector(".rhc-tooltip");
  const over = (el, init = {}) =>
    el.dispatchEvent(
      new MouseEvent("pointerover", { bubbles: true, clientX: 10, clientY: 10, ...init }),
    );
  const out = (el, relatedTarget = null) =>
    el.dispatchEvent(new MouseEvent("pointerout", { bubbles: true, relatedTarget }));

  beforeEach(() => {
    vi.useFakeTimers();
    clock = { now: () => Date.now() };
    document.body.innerHTML = `
      <button id="save" title="Save the file"><span id="inner">Save</span></button>
      <button id="open" title="Open a file">Open</button>
      <button id="plain">Plain</button>
    `;
    uninstall = installRetroTooltips(document, clock);
  });

  afterEach(() => {
    uninstall();
    vi.useRealTimers();
    document.body.innerHTML = "";
  });

  it("shows the title after half a second, and takes it off so the browser draws nothing", () => {
    const save = document.getElementById("save");
    over(save);
    expect(save.hasAttribute("title")).toBe(false);
    expect(tip().hidden).toBe(true);

    vi.advanceTimersByTime(500);
    expect(tip().hidden).toBe(false);
    expect(tip().textContent).toBe("Save the file");
    expect(tip().getAttribute("role")).toBe("tooltip");
  });

  it("gives the title back when the pointer leaves", () => {
    const save = document.getElementById("save");
    over(save);
    vi.advanceTimersByTime(500);
    out(save, document.getElementById("plain"));

    expect(tip().hidden).toBe(true);
    expect(save.getAttribute("title")).toBe("Save the file");
  });

  it("stays up while the pointer moves onto a child of the same element", () => {
    const save = document.getElementById("save");
    const inner = document.getElementById("inner");
    over(save);
    vi.advanceTimersByTime(500);
    out(save, inner);
    over(inner);

    expect(tip().hidden).toBe(false);
    expect(tip().textContent).toBe("Save the file");
  });

  it("shows a neighbour's tip almost at once while one was just up", () => {
    const save = document.getElementById("save");
    const open = document.getElementById("open");
    over(save);
    vi.advanceTimersByTime(500);
    out(save, open);
    over(open);

    vi.advanceTimersByTime(100);
    expect(tip().hidden).toBe(false);
    expect(tip().textContent).toBe("Open a file");
  });

  it("hides on a press and on its own after a few seconds", () => {
    const save = document.getElementById("save");
    over(save);
    vi.advanceTimersByTime(500);
    document.dispatchEvent(new MouseEvent("pointerdown", { bubbles: true }));
    expect(tip().hidden).toBe(true);

    out(save, document.getElementById("plain"));
    over(document.getElementById("open"));
    vi.advanceTimersByTime(500 + 5000);
    expect(tip().hidden).toBe(true);
  });

  it("ignores a scroll elsewhere, and hides when what it points at scrolls", () => {
    document.body.insertAdjacentHTML("beforeend", '<div id="log"></div>');
    const save = document.getElementById("save");
    over(save);
    document.getElementById("log").dispatchEvent(new Event("scroll"));
    vi.advanceTimersByTime(500);
    expect(tip().hidden).toBe(false);

    document.body.dispatchEvent(new Event("scroll"));
    expect(tip().hidden).toBe(true);
  });

  it("never shows for touch", () => {
    const save = document.getElementById("save");
    const event = new MouseEvent("pointerover", { bubbles: true });
    Object.defineProperty(event, "pointerType", { value: "touch" });
    save.dispatchEvent(event);
    vi.advanceTimersByTime(1000);

    expect(tip().hidden).toBe(true);
    expect(save.getAttribute("title")).toBe("Save the file");
  });

  it("takes off a title a LiveView patch put back while the pointer rests", () => {
    const save = document.getElementById("save");
    over(save);
    save.setAttribute("title", "Save again");
    save.dispatchEvent(new MouseEvent("pointermove", { bubbles: true }));

    expect(save.hasAttribute("title")).toBe(false);
    vi.advanceTimersByTime(500);
    expect(tip().textContent).toBe("Save again");
  });

  it("removes the tip element when uninstalled", () => {
    uninstall();
    expect(tip()).toBeNull();
    uninstall = () => {};
  });
});

describe("stashTitle / restoreTitle", () => {
  it("lets a title that arrived meanwhile win over the stashed one", () => {
    const el = document.createElement("span");
    const stash = new WeakMap();
    el.setAttribute("title", "old");
    expect(stashTitle(el, stash)).toBe("old");

    el.setAttribute("title", "new");
    restoreTitle(el, stash);
    expect(el.getAttribute("title")).toBe("new");
  });
});

describe("placeTooltip", () => {
  const viewport = { width: 800, height: 600 };

  it("goes under the pointer", () => {
    expect(placeTooltip({ x: 100, y: 100 }, { width: 50, height: 20 }, viewport)).toEqual({
      left: 100,
      top: 120,
    });
  });

  it("stays inside the right edge", () => {
    expect(placeTooltip({ x: 790, y: 100 }, { width: 50, height: 20 }, viewport).left).toBe(748);
  });

  it("goes above the pointer when there is no room below", () => {
    expect(placeTooltip({ x: 100, y: 590 }, { width: 50, height: 20 }, viewport).top).toBe(568);
  });
});
