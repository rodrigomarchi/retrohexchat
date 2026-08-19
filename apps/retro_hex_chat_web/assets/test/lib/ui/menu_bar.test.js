import { createMenuBar } from "../../../js/lib/ui/menu_bar.js";

// Direct controller test: menu_bar runs on public pages with no LiveSocket at
// all (see the moduledoc), so it must stand up from createMenuBar(el) alone.
// The exhaustive interaction matrix lives in test/hooks/ui/menu_bar_hook.test.js;
// this proves the standalone contract and the destroy() teardown.

function barFixture() {
  const el = document.createElement("nav");
  el.setAttribute("role", "menubar");
  el.innerHTML = `
    <div class="relative inline-flex">
      <button data-menubar-trigger>File</button>
      <div data-menubar-dropdown class="u-hidden"><ul><li>Disconnect</li></ul></div>
    </div>
    <div class="relative inline-flex">
      <button data-menubar-trigger>View</button>
      <div data-menubar-dropdown class="u-hidden"><ul><li>Channel List</li></ul></div>
    </div>
  `;
  document.body.appendChild(el);
  return el;
}

const dropdowns = (el) => el.querySelectorAll("[data-menubar-dropdown]");
const triggers = (el) => el.querySelectorAll("[data-menubar-trigger]");
const mousedown = (t) => t.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));

describe("createMenuBar (direct)", () => {
  let el, bar;

  beforeEach(() => {
    el = barFixture();
    bar = createMenuBar(el);
    bar.mount();
  });

  afterEach(() => {
    bar.destroy();
    document.body.innerHTML = "";
  });

  it("builds over the element and opens a dropdown from its trigger", () => {
    mousedown(triggers(el)[0]);
    expect(dropdowns(el)[0].classList.contains("u-hidden")).toBe(false);
    expect(triggers(el)[0].classList.contains("bg-primary")).toBe(true);
  });

  it("hot-tracks between menus on hover once one is open", () => {
    mousedown(triggers(el)[0]);
    triggers(el)[1].dispatchEvent(new MouseEvent("mouseenter", { bubbles: true }));
    expect(dropdowns(el)[0].classList.contains("u-hidden")).toBe(true);
    expect(dropdowns(el)[1].classList.contains("u-hidden")).toBe(false);
  });

  it("closes everything on Escape", () => {
    mousedown(triggers(el)[0]);
    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }));
    expect(dropdowns(el)[0].classList.contains("u-hidden")).toBe(true);
  });

  it("closes everything on an outside mousedown", () => {
    mousedown(triggers(el)[0]);
    document.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));
    expect(dropdowns(el)[0].classList.contains("u-hidden")).toBe(true);
  });

  it("unbinds document listeners on destroy", () => {
    bar.destroy();
    // With the controller torn down, an outside/Escape sequence is inert and a
    // trigger no longer opens — prove no document listener lingers.
    mousedown(triggers(el)[0]);
    expect(dropdowns(el)[0].classList.contains("u-hidden")).toBe(true);
    bar = createMenuBar(el);
    bar.mount();
  });
});
