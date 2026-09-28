import { mountHook, cleanupDOM } from "../../helpers/hook_helper.js";
import URLCatcherHook from "../../../js/hooks/ui/url_catcher_hook.js";

/**
 * The fixture is an `<article data-url>` because that is what the dialog
 * renders. It used to be a `<tr>`, matching a `tr[data-url]` selector in the
 * hook — and the dialog had stopped rendering a table, so the test agreed with
 * the hook while the screen did neither.
 */
describe("URLCatcherHook", () => {
  let hook;
  let openSpy;

  beforeEach(() => {
    openSpy = vi.spyOn(window, "open").mockImplementation(() => null);
    hook = mountHook(URLCatcherHook, {
      html: `
        <article data-url="https://example.com">
          <a class="uc-entry-url" href="https://example.com" data-confirm-tab="external">example.com</a>
        </article>
        <article data-url="https://test.com"><span>test.com</span></article>
      `,
    });
  });

  afterEach(() => {
    openSpy.mockRestore();
    cleanupDOM();
  });

  it("asks before opening, rather than opening", () => {
    const row = hook.el.querySelector("article[data-url='https://test.com'] span");
    row.dispatchEvent(new MouseEvent("dblclick", { bubbles: true }));

    expect(openSpy).not.toHaveBeenCalled();
    expect(hook.__pushEvents).toEqual([
      { event: "confirm_open_tab", payload: { url: "https://test.com", kind: "external" } },
    ]);
  });

  it("does not ask when the double-click landed on the gated anchor", () => {
    // The anchor's own clicks already raised the dialog; a third push for the
    // same URL is noise.
    const anchor = hook.el.querySelector("a[data-confirm-tab]");
    anchor.dispatchEvent(new MouseEvent("dblclick", { bubbles: true }));

    expect(hook.__pushEvents).toEqual([]);
  });

  it("does nothing when double-clicking outside a row", () => {
    hook.el.dispatchEvent(new MouseEvent("dblclick", { bubbles: true }));

    expect(openSpy).not.toHaveBeenCalled();
    expect(hook.__pushEvents).toEqual([]);
  });
});
