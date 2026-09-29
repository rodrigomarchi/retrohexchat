import { mountHook, cleanupDOM } from "../../helpers/hook_helper.js";
import ActionListFocusHook from "../../../js/hooks/ui/action_list_focus_hook.js";

// requestAnimationFrame runs after the patch that removed the element, so the
// hook can tell a fall to <body> from focus that landed somewhere real.
function flushFrame() {
  return new Promise((resolve) => setTimeout(resolve, 0));
}

describe("ActionListFocusHook", () => {
  let hook;

  beforeEach(() => {
    globalThis.requestAnimationFrame = (fn) => setTimeout(fn, 0);

    hook = mountHook(ActionListFocusHook, {
      tag: "ul",
      attrs: { tabindex: "-1" },
      html: `
        <li><button data-testid="remove-a"></button></li>
        <li><button data-testid="remove-b"></button></li>
      `,
    });
  });

  afterEach(() => {
    cleanupDOM();
  });

  it("takes focus when the focused control leaves with its row", async () => {
    const button = hook.el.querySelector("[data-testid='remove-a']");
    button.focus();

    // The order the browser uses: focusout leaves the element while it is still
    // attached, and the patch that removes it lands before the next frame.
    button.dispatchEvent(new FocusEvent("focusout", { bubbles: true }));
    button.closest("li").remove();
    await flushFrame();

    expect(document.activeElement).toBe(hook.el);
  });

  it("leaves focus alone when it landed on something real", async () => {
    const stays = hook.el.querySelector("[data-testid='remove-b']");
    stays.focus();
    stays.dispatchEvent(new FocusEvent("focusout", { bubbles: true }));
    await flushFrame();

    expect(document.activeElement).toBe(stays);
  });

  it("does not reach for a list that is gone itself", async () => {
    const button = hook.el.querySelector("[data-testid='remove-a']");
    button.focus();

    button.dispatchEvent(new FocusEvent("focusout", { bubbles: true }));
    hook.el.remove();
    await flushFrame();

    expect(document.activeElement).toBe(document.body);
  });
});
