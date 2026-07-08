import { describe, it, expect } from "vitest";

import { ChatState } from "../../../js/lib/space/chat.js";

describe("ChatState bubbles", () => {
  it("shows a bubble until it expires", () => {
    const chat = new ChatState({ bubbleMs: 1000, logLimit: 5 });
    chat.receive({ key: "registered:1", nickname: "alice", text: "hi" }, 0);

    expect(chat.bubble("registered:1", 0)?.text).toBe("hi");
    expect(chat.bubble("registered:1", 999)?.text).toBe("hi");
    expect(chat.bubble("registered:1", 1000)).toBe(null);
  });

  it("replaces a participant's bubble with the newest message", () => {
    const chat = new ChatState({ bubbleMs: 1000 });
    chat.receive({ key: "registered:1", nickname: "a", text: "first" }, 0);
    chat.receive({ key: "registered:1", nickname: "a", text: "second" }, 100);

    expect(chat.bubble("registered:1", 100)?.text).toBe("second");
  });

  it("returns null for an unknown participant", () => {
    const chat = new ChatState();
    expect(chat.bubble("ghost", 0)).toBe(null);
  });
});

describe("ChatState diagnostic buffer", () => {
  it("appends bubble events and caps the buffer length", () => {
    const chat = new ChatState({ logLimit: 3 });
    for (let i = 1; i <= 5; i += 1) {
      chat.receive({ key: "registered:1", nickname: "a", text: `m${i}` }, i);
    }

    const log = chat.log();
    expect(log).toHaveLength(3);
    expect(log.map((e) => e.text)).toEqual(["m3", "m4", "m5"]);
    expect(log[0].nickname).toBe("a");
  });
});
