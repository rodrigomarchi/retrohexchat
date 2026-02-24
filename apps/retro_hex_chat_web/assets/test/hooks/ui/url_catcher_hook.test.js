import { mountHook, cleanupDOM } from "../../helpers/hook_helper.js";
import URLCatcherHook from "../../../js/hooks/ui/url_catcher_hook.js";

describe("URLCatcherHook", () => {
  let hook;
  let openSpy;

  beforeEach(() => {
    openSpy = vi.spyOn(window, "open").mockImplementation(() => null);
    hook = mountHook(URLCatcherHook, {
      tag: "table",
      html: `
        <tr data-url="https://example.com"><td>example.com</td></tr>
        <tr data-url="https://test.com"><td>test.com</td></tr>
      `,
    });
  });

  afterEach(() => {
    openSpy.mockRestore();
    cleanupDOM();
  });

  it("opens URL in new tab on double-click", () => {
    const row = hook.el.querySelector("tr[data-url='https://example.com']");
    row.dispatchEvent(new MouseEvent("dblclick", { bubbles: true }));
    expect(openSpy).toHaveBeenCalledWith("https://example.com", "_blank", "noopener,noreferrer");
  });

  it("does not open when double-clicking outside a row", () => {
    hook.el.dispatchEvent(new MouseEvent("dblclick", { bubbles: true }));
    expect(openSpy).not.toHaveBeenCalled();
  });
});
