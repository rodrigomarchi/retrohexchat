import { mountHook, cleanupDOM } from "../../helpers/hook_helper.js";
import OpenTabConfirmHook from "../../../js/hooks/chat/open_tab_confirm_hook.js";

/**
 * The listener is delegated on `document`, so the links under test live outside
 * the hook element — which is exactly how it reaches a link inside message
 * content, raw HTML the server rendered rather than a component.
 */
describe("OpenTabConfirmHook", () => {
  let hook;
  let page;

  beforeEach(() => {
    page = document.createElement("div");
    page.innerHTML = `
      <a id="door" href="/call/abc" target="_blank" rel="noopener"
         data-confirm-tab="surface" data-confirm-label="Call in #retro">Join</a>
      <a id="message-link" class="chat-link" href="https://news.test/a"
         target="_blank" data-url="https://news.test/a">news.test/a</a>
      <a id="help" href="/chat/help" target="_blank">Help</a>
    `;
    document.body.appendChild(page);

    hook = mountHook(OpenTabConfirmHook);
  });

  afterEach(() => {
    if (hook.destroyed) hook.destroyed();
    cleanupDOM();
  });

  function click(id, init = {}) {
    const event = new MouseEvent("click", { bubbles: true, cancelable: true, ...init });
    page.querySelector(`#${id}`).dispatchEvent(event);
    return event;
  }

  it("holds the click on a marked door and reports where it was going", () => {
    const event = click("door");

    expect(event.defaultPrevented).toBe(true);
    expect(hook.__pushEvents).toEqual([
      {
        event: "confirm_open_tab",
        payload: {
          url: "/call/abc",
          kind: "surface",
          label: "Call in #retro",
          host: null,
        },
      },
    ]);
  });

  it("holds the click on a link inside message content", () => {
    const event = click("message-link");

    expect(event.defaultPrevented).toBe(true);
    expect(hook.__pushEvents[0].payload).toMatchObject({
      url: "https://news.test/a",
      kind: "external",
      host: "news.test",
    });
  });

  // The absence of the marking is the allowlist, and help was deliberately left
  // out of it.
  it("lets an unmarked link through untouched", () => {
    const event = click("help");

    expect(event.defaultPrevented).toBe(false);
    expect(hook.__pushEvents).toEqual([]);
  });

  it("lets a ctrl-click through, because it already asked for a tab", () => {
    const event = click("door", { ctrlKey: true });

    expect(event.defaultPrevented).toBe(false);
    expect(hook.__pushEvents).toEqual([]);
  });

  it("lets a click the page already handled through", () => {
    page.querySelector("#door").addEventListener("click", (e) => e.preventDefault());
    // The capture-phase listener runs first, so the guard is checked against a
    // `defaultPrevented` set by something even earlier — a synthetic event that
    // arrives already prevented.
    const event = new MouseEvent("click", { bubbles: true, cancelable: true });
    event.preventDefault();
    page.querySelector("#door").dispatchEvent(event);

    expect(hook.__pushEvents).toEqual([]);
  });

  it("stops listening when it goes away", () => {
    hook.destroyed();
    hook.destroyed = null;

    click("door");

    expect(hook.__pushEvents).toEqual([]);
  });
});
