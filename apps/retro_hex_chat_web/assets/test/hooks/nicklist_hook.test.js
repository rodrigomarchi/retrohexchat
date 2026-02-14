import { mountHook, cleanupDOM } from "../helpers/hook_helper.js";
import NicklistHook from "../../js/hooks/nicklist_hook.js";

describe("NicklistHook", () => {
  let hook;

  beforeEach(() => {
    hook = mountHook(NicklistHook, {
      tag: "ul",
      html: `
        <li phx-value-nick="Alice">Alice</li>
        <li phx-value-nick="Bob">Bob</li>
      `,
    });
  });

  afterEach(() => {
    cleanupDOM();
  });

  it("pushes nicklist_dblclick with nick on double-click", () => {
    const li = hook.el.querySelector("li[phx-value-nick='Alice']");
    li.dispatchEvent(new MouseEvent("dblclick", { bubbles: true }));
    expect(hook.pushEvent).toHaveBeenCalledWith("nicklist_dblclick", { nick: "Alice" });
  });

  it("does not push when double-clicking outside a nick", () => {
    hook.pushEvent.mockClear();
    hook.el.dispatchEvent(new MouseEvent("dblclick", { bubbles: true }));
    expect(hook.pushEvent).not.toHaveBeenCalled();
  });
});
