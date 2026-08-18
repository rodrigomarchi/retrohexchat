import { afterEach, describe, expect, it } from "vitest";

import { createToolbarGroup } from "../../../js/lib/ui/toolbar_group.js";

afterEach(() => {
  document.body.innerHTML = "";
});

function mount() {
  const el = document.createElement("div");
  el.innerHTML = `
    <div class="toolbar-group">
      <button data-toolbar-group-toggle>A</button>
      <div class="toolbar-group-dropdown u-hidden"><button class="toolbar-btn">x</button></div>
    </div>
    <div class="toolbar-group">
      <button data-toolbar-group-toggle>B</button>
      <div class="toolbar-group-dropdown u-hidden"><button class="toolbar-btn">y</button></div>
    </div>`;
  document.body.appendChild(el);
  const group = createToolbarGroup(el);
  group.mount();
  return { el, group };
}

const dropdowns = (el) => Array.from(el.querySelectorAll(".toolbar-group-dropdown"));
const isOpen = (d) => !d.classList.contains("u-hidden");

describe("createToolbarGroup", () => {
  it("opens a dropdown on its toggle's mousedown", () => {
    const { el } = mount();
    el.querySelectorAll("[data-toolbar-group-toggle]")[0].dispatchEvent(
      new MouseEvent("mousedown", { bubbles: true }),
    );
    expect(isOpen(dropdowns(el)[0])).toBe(true);
  });

  it("closes an open dropdown when its toggle is pressed again", () => {
    const { el } = mount();
    const toggle = el.querySelectorAll("[data-toolbar-group-toggle]")[0];
    toggle.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));
    toggle.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));
    expect(isOpen(dropdowns(el)[0])).toBe(false);
  });

  it("only one group is open at a time", () => {
    const { el } = mount();
    const [a, b] = el.querySelectorAll("[data-toolbar-group-toggle]");
    a.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));
    b.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));
    expect(isOpen(dropdowns(el)[0])).toBe(false);
    expect(isOpen(dropdowns(el)[1])).toBe(true);
  });

  it("closes when a dropdown button is clicked", () => {
    const { el } = mount();
    el.querySelectorAll("[data-toolbar-group-toggle]")[0].dispatchEvent(
      new MouseEvent("mousedown", { bubbles: true }),
    );
    el.querySelector(".toolbar-group-dropdown .toolbar-btn").dispatchEvent(
      new MouseEvent("click", { bubbles: true }),
    );
    expect(dropdowns(el).every((d) => !isOpen(d))).toBe(true);
  });

  it("closes on an outside click and on Escape, and unbinds on destroy", () => {
    const { el, group } = mount();
    const open = () =>
      el
        .querySelectorAll("[data-toolbar-group-toggle]")[0]
        .dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));

    open();
    document.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));
    expect(dropdowns(el).every((d) => !isOpen(d))).toBe(true);

    open();
    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }));
    expect(dropdowns(el).every((d) => !isOpen(d))).toBe(true);

    open();
    group.destroy();
    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }));
    // still open: the document listener was removed
    expect(isOpen(dropdowns(el)[0])).toBe(true);
  });
});
