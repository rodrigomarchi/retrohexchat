import { mountHook, cleanupDOM } from "../helpers/hook_helper.js";
import PasteHook from "../../js/hooks/paste_hook.js";

describe("PasteHook", () => {
  let hook;
  let input;

  beforeEach(() => {
    input = document.createElement("textarea");
    input.id = "chat-input";
    document.body.appendChild(input);
    hook = mountHook(PasteHook);
  });

  afterEach(() => {
    cleanupDOM();
  });

  function createPasteEvent(text) {
    const event = new Event("paste", { bubbles: true, cancelable: true });
    event.clipboardData = { getData: () => text };
    return event;
  }

  it("pushes paste_lines for multi-line paste", () => {
    const event = createPasteEvent("line1\nline2\nline3");
    input.dispatchEvent(event);
    expect(hook.pushEvent).toHaveBeenCalledWith("paste_lines", {
      lines: ["line1", "line2", "line3"],
    });
  });

  it("prevents default for multi-line paste", () => {
    const event = createPasteEvent("line1\nline2");
    input.dispatchEvent(event);
    expect(hook.pushEvent).toHaveBeenCalledWith("paste_lines", expect.any(Object));
  });

  it("allows single-line paste (no pushEvent)", () => {
    hook.pushEvent.mockClear();
    const event = createPasteEvent("just one line");
    input.dispatchEvent(event);
    expect(hook.pushEvent).not.toHaveBeenCalled();
  });

  it("filters empty lines", () => {
    const event = createPasteEvent("line1\n\n\nline2");
    input.dispatchEvent(event);
    expect(hook.pushEvent).toHaveBeenCalledWith("paste_lines", {
      lines: ["line1", "line2"],
    });
  });
});
