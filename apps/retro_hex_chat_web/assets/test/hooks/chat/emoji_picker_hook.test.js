import { mountHook, cleanupDOM } from "../../helpers/hook_helper.js";
import EmojiPickerHook from "../../../js/hooks/chat/emoji_picker_hook.js";

describe("EmojiPickerHook", () => {
  let hook;

  beforeEach(() => {
    hook = mountHook(EmojiPickerHook);
  });

  afterEach(() => {
    if (hook.destroyed) hook.destroyed();
    cleanupDOM();
  });

  it("pushes toggle_emoji_picker on Escape", () => {
    hook.pushEvent.mockClear();
    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }));
    expect(hook.pushEvent).toHaveBeenCalledWith("toggle_emoji_picker", {});
  });

  it("pushes toggle_emoji_picker on outside click", () => {
    hook.pushEvent.mockClear();
    document.body.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));
    expect(hook.pushEvent).toHaveBeenCalledWith("toggle_emoji_picker", {});
  });
});
