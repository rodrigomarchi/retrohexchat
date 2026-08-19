import { createConnectionStatusView } from "../../../js/lib/connection/connection_status_view.js";

function shellFixture() {
  const el = document.createElement("div");
  el.innerHTML = `
    <div data-role="banner"><span data-role="banner-text"></span></div>
    <div data-role="overlay">
      <p data-role="overlay-info"></p>
      <p data-role="overlay-countdown"></p>
      <button data-role="overlay-action"></button>
    </div>
  `;
  document.body.appendChild(el);
  return el;
}

describe("createConnectionStatusView (direct)", () => {
  let el, view;

  beforeEach(() => {
    el = shellFixture();
  });

  afterEach(() => {
    view?.destroy();
    document.body.innerHTML = "";
    vi.restoreAllMocks();
    vi.useRealTimers();
  });

  it("shows the disconnected banner", () => {
    view = createConnectionStatusView(el, {});
    view.mount();
    view.render("disconnected", {});
    const banner = el.querySelector('[data-role="banner"]');
    expect(banner.classList.contains("connection-banner--visible")).toBe(true);
    expect(banner.classList.contains("connection-banner--disconnected")).toBe(true);
  });

  it("shows the reconnecting overlay with attempt/countdown text", () => {
    view = createConnectionStatusView(el, {});
    view.mount();
    view.render("reconnecting", { attempt: 2, maxAttempts: 5, remaining: 3 });
    const overlay = el.querySelector('[data-role="overlay"]');
    expect(overlay.classList.contains("reconnect-overlay--visible")).toBe(true);
    expect(el.querySelector('[data-role="overlay-info"]').textContent).toContain("2");
    expect(el.querySelector('[data-role="overlay-action"]').textContent).toBeTruthy();
  });

  it("clears the banner and overlay when connected again", () => {
    view = createConnectionStatusView(el, {});
    view.mount();
    view.render("disconnected", {});
    view.render("connected", {});
    expect(
      el.querySelector('[data-role="banner"]').classList.contains("connection-banner--visible"),
    ).toBe(false);
    expect(
      el.querySelector('[data-role="overlay"]').classList.contains("reconnect-overlay--visible"),
    ).toBe(false);
  });

  it("routes the overlay action button click to the onActionClick port", () => {
    const onActionClick = vi.fn();
    view = createConnectionStatusView(el, { onActionClick });
    view.mount();
    el.querySelector('[data-role="overlay-action"]').dispatchEvent(
      new MouseEvent("click", { bubbles: true }),
    );
    expect(onActionClick).toHaveBeenCalledOnce();
  });

  it("unbinds the action button on destroy", () => {
    const onActionClick = vi.fn();
    view = createConnectionStatusView(el, { onActionClick });
    view.mount();
    view.destroy();
    el.querySelector('[data-role="overlay-action"]').dispatchEvent(
      new MouseEvent("click", { bubbles: true }),
    );
    expect(onActionClick).not.toHaveBeenCalled();
    view = null;
  });

  describe("chat-input draft preservation", () => {
    function chatInput() {
      const input = document.createElement("input");
      input.dataset.testid = "chat-input-field";
      const send = document.createElement("button");
      send.dataset.testid = "chat-input-send";
      document.body.append(input, send);
      return { input, send };
    }

    it("captures the draft when disabled and restores it when re-enabled", () => {
      const { input } = chatInput();
      input.value = "half typed";
      view = createConnectionStatusView(el, {});
      view.mount();

      view.render("disconnected", {}); // shellDisabled -> capture + disable
      expect(input.disabled).toBe(true);

      input.value = "";
      view.render("connected", {}); // shellDisabled false -> restore
      expect(input.disabled).toBe(false);
      expect(input.value).toBe("half typed");
    });

    it("does not restore after clearDraft", () => {
      const { input } = chatInput();
      input.value = "half typed";
      view = createConnectionStatusView(el, {});
      view.mount();
      view.render("disconnected", {});
      input.value = "";
      view.clearDraft();
      view.render("connected", {});
      expect(input.value).toBe("");
    });
  });

  describe("shell disabling", () => {
    it("disables only the menu triggers marked offline-disabled", () => {
      const menuBar = document.createElement("div");
      menuBar.dataset.testid = "menu-bar";
      menuBar.innerHTML = `
        <button data-menubar-trigger data-offline-disabled="true" aria-disabled="false"></button>
        <button data-menubar-trigger data-offline-disabled="false" aria-disabled="false"></button>
      `;
      document.body.appendChild(menuBar);
      view = createConnectionStatusView(el, {});
      view.mount();
      view.render("disconnected", {});
      const [marked, unmarked] = menuBar.querySelectorAll("[data-menubar-trigger]");
      expect(marked.getAttribute("aria-disabled")).toBe("true");
      expect(unmarked.getAttribute("aria-disabled")).toBe("false");
    });
  });
});
