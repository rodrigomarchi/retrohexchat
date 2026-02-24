import { mountHook, cleanupDOM } from "../../helpers/hook_helper.js";
import NotifyListHook from "../../../js/hooks/notifications/notify_list_hook.js";

describe("NotifyListHook", () => {
  let hook;

  beforeEach(() => {
    hook = mountHook(NotifyListHook, {
      tag: "table",
      html: `
        <tr data-nickname="Alice"><td>Alice</td></tr>
        <tr data-nickname="Bob"><td>Bob</td></tr>
      `,
    });
  });

  afterEach(() => {
    cleanupDOM();
  });

  it("pushes notify_dblclick with nickname on double-click", () => {
    const row = hook.el.querySelector("tr[data-nickname='Alice']");
    row.dispatchEvent(new MouseEvent("dblclick", { bubbles: true }));
    expect(hook.pushEvent).toHaveBeenCalledWith("notify_dblclick", { nickname: "Alice" });
  });

  it("does not push when double-clicking outside a row", () => {
    hook.pushEvent.mockClear();
    hook.el.dispatchEvent(new MouseEvent("dblclick", { bubbles: true }));
    expect(hook.pushEvent).not.toHaveBeenCalled();
  });
});
