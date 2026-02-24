import { mountHook, simulateEvent, cleanupDOM } from "../../helpers/hook_helper.js";
import EmojiPickerHook from "../../../js/hooks/chat/emoji_picker_hook.js";

describe("EmojiPickerHook", () => {
  let hook;
  let chatInput;

  beforeEach(() => {
    chatInput = document.createElement("textarea");
    chatInput.id = "chat-input";
    chatInput.value = "";
    chatInput.selectionStart = 0;
    chatInput.selectionEnd = 0;
    document.body.appendChild(chatInput);

    hook = mountHook(EmojiPickerHook);
  });

  afterEach(() => {
    if (hook.destroyed) hook.destroyed();
    cleanupDOM();
  });

  it("inserts emoji at cursor on insert_emoji event", () => {
    simulateEvent(hook, "insert_emoji", { char: "😀" });
    expect(chatInput.value).toBe("😀");
  });

  it("inserts emoji in the middle of text", () => {
    chatInput.value = "hello world";
    chatInput.selectionStart = 5;
    chatInput.selectionEnd = 5;
    simulateEvent(hook, "insert_emoji", { char: "👋" });
    expect(chatInput.value).toBe("hello👋 world");
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
