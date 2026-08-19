import { createFormatToolbar } from "../../../js/lib/chat/format_toolbar.js";

// Direct controller test: drive createFormatToolbar without the hook wrapper,
// proving the lib contract stands on its own. The exhaustive interaction matrix
// lives in test/hooks/chat/format_toolbar_hook.test.js; this pins the seam.

function toolbarFixture() {
  document.body.innerHTML = `
    <textarea id="chat-input"></textarea>
    <div id="toolbar">
      <button data-format-toolbar-toggle aria-expanded="false">Aa</button>
      <div data-format-toolbar-panel class="u-hidden" aria-hidden="true">
        <button class="format-btn" data-format-code="bold">B</button>
        <button class="format-btn" data-format-code="md-bold">MB</button>
        <button class="format-btn" data-format-code="color">Color</button>
        <div data-format-color-dropdown>
          <button data-format-color-swatch data-color-code="04">red</button>
        </div>
      </div>
    </div>
  `;
  const el = document.getElementById("toolbar");
  const input = document.getElementById("chat-input");
  return { el, input };
}

function mousedown(target) {
  target.dispatchEvent(new MouseEvent("mousedown", { bubbles: true, cancelable: true }));
}

describe("createFormatToolbar (direct)", () => {
  let el, input, toolbar;

  beforeEach(() => {
    ({ el, input } = toolbarFixture());
    toolbar = createFormatToolbar(el);
    toolbar.mount();
  });

  afterEach(() => {
    toolbar.destroy();
    document.body.innerHTML = "";
  });

  it("opens and closes the panel on the toggle", () => {
    const panel = el.querySelector("[data-format-toolbar-panel]");
    mousedown(el.querySelector("[data-format-toolbar-toggle]"));
    expect(panel.classList.contains("u-hidden")).toBe(false);
    expect(panel.getAttribute("aria-hidden")).toBe("false");

    mousedown(el.querySelector("[data-format-toolbar-toggle]"));
    expect(panel.classList.contains("u-hidden")).toBe(true);
  });

  it("closes the panel on an outside mousedown", () => {
    mousedown(el.querySelector("[data-format-toolbar-toggle]"));
    mousedown(document.body);
    expect(el.querySelector("[data-format-toolbar-panel]").classList.contains("u-hidden")).toBe(
      true,
    );
  });

  it("closes the open panel on Escape", () => {
    mousedown(el.querySelector("[data-format-toolbar-toggle]"));
    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }));
    expect(el.querySelector("[data-format-toolbar-panel]").classList.contains("u-hidden")).toBe(
      true,
    );
  });

  it("inserts the IRC control code for a format button", () => {
    mousedown(el.querySelector('[data-format-code="bold"]'));
    expect(input.value).toBe("\x02");
  });

  it("applies a markdown wrap for a markdown button", () => {
    input.value = "";
    mousedown(el.querySelector('[data-format-code="md-bold"]'));
    expect(input.value).toBe("**text**");
  });

  it("toggles the colour dropdown and inserts a colour code from a swatch", () => {
    const dropdown = el.querySelector("[data-format-color-dropdown]");
    mousedown(el.querySelector('[data-format-code="color"]'));
    expect(dropdown.classList.contains("format-color-dropdown--open")).toBe(true);

    mousedown(el.querySelector("[data-format-color-swatch]"));
    expect(input.value).toBe("\x0304");
    expect(dropdown.classList.contains("format-color-dropdown--open")).toBe(false);
  });

  it("unbinds every listener on destroy", () => {
    toolbar.destroy();
    const panel = el.querySelector("[data-format-toolbar-panel]");
    mousedown(el.querySelector("[data-format-toolbar-toggle]"));
    expect(panel.classList.contains("u-hidden")).toBe(true);
    // re-mount so afterEach's destroy has a live controller to tear down
    toolbar = createFormatToolbar(el);
    toolbar.mount();
  });
});
