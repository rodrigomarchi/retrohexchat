import { afterEach, describe, expect, it } from "vitest";
import MenuBarHook from "../../../js/hooks/ui/menu_bar_hook.js";
import { mountSiteMenuBar, siteMenuBarFor } from "../../../js/lib/ui/site_menu_bar.js";

function menuBar() {
  const el = document.createElement("nav");
  el.setAttribute("role", "menubar");
  el.innerHTML = `
    <div class="relative inline-flex">
      <button data-menubar-trigger>Navigate</button>
      <div data-menubar-dropdown class="u-hidden"><ul><li>Features</li></ul></div>
    </div>`;
  document.body.appendChild(el);
  return el;
}

const dropdown = (el) => el.querySelector("[data-menubar-dropdown]");

describe("site menu bar", () => {
  afterEach(() => {
    document.body.innerHTML = "";
  });

  it("mounts once per element and hands the same engine back", () => {
    const el = menuBar();
    const bar = mountSiteMenuBar(el);

    expect(mountSiteMenuBar(el)).toBe(bar);
    expect(siteMenuBarFor(el)).toBe(bar);
    expect(siteMenuBarFor(document.createElement("nav"))).toBeNull();
  });

  // Two engines on one element answer a press twice: open, then close.
  it("is adopted by MenuBarHook, so one press opens the menu", () => {
    const el = menuBar();
    const bar = mountSiteMenuBar(el);

    const hook = Object.create(MenuBarHook);
    hook.el = el;
    hook.mounted();

    expect(hook.menuBar).toBe(bar);
    el.querySelector("[data-menubar-trigger]").dispatchEvent(
      new MouseEvent("mousedown", { bubbles: true, button: 0 }),
    );
    expect(dropdown(el).classList.contains("u-hidden")).toBe(false);
  });
});
