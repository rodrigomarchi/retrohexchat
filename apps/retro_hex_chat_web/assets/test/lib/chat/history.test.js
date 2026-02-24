import { isSensitiveCommand, createHistoryManager } from "../../../js/lib/chat/history.js";
import { mockLocalStorage, cleanupDOM } from "../../helpers/hook_helper.js";

describe("lib/history", () => {
  let storage;

  beforeEach(() => {
    storage = mockLocalStorage();
  });

  afterEach(() => {
    cleanupDOM();
    storage.restore();
  });

  // ── isSensitiveCommand ─────────────────────────────────

  describe("isSensitiveCommand", () => {
    it("detects /identify with args", () => {
      expect(isSensitiveCommand("/identify mypass")).toBe(true);
    });

    it("detects standalone /identify", () => {
      expect(isSensitiveCommand("/identify")).toBe(true);
    });

    it("detects /nickserv", () => {
      expect(isSensitiveCommand("/nickserv identify pass")).toBe(true);
    });

    it("detects /ns", () => {
      expect(isSensitiveCommand("/ns identify")).toBe(true);
    });

    it("is case-insensitive", () => {
      expect(isSensitiveCommand("/IDENTIFY mypass")).toBe(true);
      expect(isSensitiveCommand("/NickServ identify")).toBe(true);
    });

    it("handles leading whitespace", () => {
      expect(isSensitiveCommand("  /identify pass")).toBe(true);
    });

    it("returns false for normal commands", () => {
      expect(isSensitiveCommand("/msg user hello")).toBe(false);
      expect(isSensitiveCommand("/join #channel")).toBe(false);
    });
  });

  // ── createHistoryManager ───────────────────────────────

  describe("createHistoryManager", () => {
    let hm;

    beforeEach(() => {
      hm = createHistoryManager({});
    });

    describe("save and getHistory", () => {
      it("saves text to history", () => {
        hm.save("hello");
        expect(hm.getHistory()[0]).toBe("hello");
      });

      it("deduplicates entries", () => {
        hm.save("hello");
        hm.save("world");
        hm.save("hello");
        expect(hm.getHistory()).toEqual(["hello", "world"]);
      });

      it("caps at max entries", () => {
        const manager = createHistoryManager({ maxEntries: 3 });
        manager.save("a");
        manager.save("b");
        manager.save("c");
        manager.save("d");
        expect(manager.getHistory()).toHaveLength(3);
        expect(manager.getHistory()[0]).toBe("d");
      });

      it("does not save empty text", () => {
        hm.save("");
        hm.save("   ");
        expect(hm.getHistory()).toHaveLength(0);
      });

      it("does not save sensitive commands", () => {
        hm.save("/identify mypass");
        expect(hm.getHistory()).toHaveLength(0);
      });
    });

    describe("up/down navigation", () => {
      beforeEach(() => {
        hm.save("first");
        hm.save("second");
        hm.save("third");
      });

      it("up returns most recent entry", () => {
        const result = hm.up("draft", 5);
        expect(result).toEqual({ value: "third" });
      });

      it("up twice returns second entry", () => {
        hm.up("draft", 0);
        const result = hm.up("draft", 0);
        expect(result).toEqual({ value: "second" });
      });

      it("down restores draft", () => {
        hm.up("my draft", 8);
        const result = hm.down();
        expect(result).toEqual({ value: "my draft", cursor: 8 });
      });

      it("down returns null when not browsing", () => {
        expect(hm.down()).toBeNull();
      });

      it("up returns null when at end of history", () => {
        hm.up("", 0);
        hm.up("", 0);
        hm.up("", 0);
        const result = hm.up("", 0);
        expect(result).toBeNull();
      });
    });

    describe("search", () => {
      beforeEach(() => {
        hm.save("hello world");
        hm.save("/join #general");
      });

      it("finds matching entry", () => {
        expect(hm.search("hello")).toBe("hello world");
      });

      it("is case-insensitive", () => {
        expect(hm.search("HELLO")).toBe("hello world");
      });

      it("returns null for no match", () => {
        expect(hm.search("zzzzz")).toBeNull();
      });

      it("returns null for empty query", () => {
        expect(hm.search("")).toBeNull();
      });
    });

    describe("saveRecentCommand", () => {
      it("saves command name", () => {
        hm.saveRecentCommand("join");
        expect(hm.getRecentCommands()).toEqual(["join"]);
      });

      it("deduplicates and limits", () => {
        const manager = createHistoryManager({ maxRecentCommands: 3 });
        manager.saveRecentCommand("a");
        manager.saveRecentCommand("b");
        manager.saveRecentCommand("c");
        manager.saveRecentCommand("d");
        expect(manager.getRecentCommands()).toEqual(["d", "c", "b"]);
      });
    });

    describe("resetBrowsing", () => {
      it("resets browsing state", () => {
        hm.save("test");
        hm.up("", 0);
        hm.resetBrowsing();
        expect(hm.down()).toBeNull();
      });
    });

    describe("load", () => {
      it("reloads from localStorage", () => {
        storage.store["retro_hex_chat_history"] = JSON.stringify(["loaded"]);
        hm.load();
        expect(hm.getHistory()).toEqual(["loaded"]);
      });
    });
  });
});
