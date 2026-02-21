import {
  isSuppressed,
  setSuppressed,
  isTipSeen,
  markTipSeen,
  shouldShowTip,
  markPreempted,
  getTipById,
  resetAllTips,
  STORAGE_KEYS,
  TIP_IDS,
  TIPS,
  AUTO_DISMISS_MS,
  QUEUE_GAP_MS,
  IDLE_TIMEOUT_MS,
} from "../../js/lib/tips.js";
import { mockLocalStorage } from "../helpers/hook_helper.js";

describe("tips", () => {
  let storage;

  beforeEach(() => {
    storage = mockLocalStorage();
  });

  afterEach(() => {
    storage.restore();
  });

  // ── Constants ─────────────────────────────────────────────

  describe("constants", () => {
    it("defines 5 tip IDs", () => {
      expect(Object.keys(TIP_IDS)).toHaveLength(5);
    });

    it("defines 5 tip definitions", () => {
      expect(TIPS).toHaveLength(5);
    });

    it("defines timing constants", () => {
      expect(AUTO_DISMISS_MS).toBe(8000);
      expect(QUEUE_GAP_MS).toBe(2000);
      expect(IDLE_TIMEOUT_MS).toBe(30000);
    });

    it("each tip has id and text", () => {
      for (const tip of TIPS) {
        expect(tip.id).toBeDefined();
        expect(tip.text).toBeDefined();
        expect(typeof tip.text).toBe("string");
      }
    });

    it("idle_help tip has preemptedBy field", () => {
      const idleTip = TIPS.find((t) => t.id === TIP_IDS.IDLE_HELP);
      expect(idleTip.preemptedBy).toBe("help_used");
    });
  });

  // ── isSuppressed / setSuppressed ──────────────────────────

  describe("isSuppressed", () => {
    it("returns false when no key exists", () => {
      expect(isSuppressed()).toBe(false);
    });

    it("returns true when primary key is set", () => {
      storage.store[STORAGE_KEYS.SUPPRESSED] = "true";
      expect(isSuppressed()).toBe(true);
    });

    it("returns true when backup key is set", () => {
      storage.store[STORAGE_KEYS.SUPPRESSED_BACKUP] = "true";
      expect(isSuppressed()).toBe(true);
    });

    it("returns true when both keys are set", () => {
      storage.store[STORAGE_KEYS.SUPPRESSED] = "true";
      storage.store[STORAGE_KEYS.SUPPRESSED_BACKUP] = "true";
      expect(isSuppressed()).toBe(true);
    });
  });

  describe("setSuppressed", () => {
    it("sets both primary and backup keys when suppressing", () => {
      setSuppressed(true);
      expect(storage.store[STORAGE_KEYS.SUPPRESSED]).toBe("true");
      expect(storage.store[STORAGE_KEYS.SUPPRESSED_BACKUP]).toBe("true");
    });

    it("removes both keys when unsuppressing", () => {
      storage.store[STORAGE_KEYS.SUPPRESSED] = "true";
      storage.store[STORAGE_KEYS.SUPPRESSED_BACKUP] = "true";
      setSuppressed(false);
      expect(storage.store[STORAGE_KEYS.SUPPRESSED]).toBeUndefined();
      expect(storage.store[STORAGE_KEYS.SUPPRESSED_BACKUP]).toBeUndefined();
    });

    it("handles localStorage full gracefully", () => {
      vi.spyOn(Storage.prototype, "setItem").mockImplementation(() => {
        throw new DOMException("QuotaExceededError");
      });
      expect(() => setSuppressed(true)).not.toThrow();
    });
  });

  // ── isTipSeen / markTipSeen ───────────────────────────────

  describe("isTipSeen", () => {
    it("returns false when no tips are seen", () => {
      expect(isTipSeen("first_message")).toBe(false);
    });

    it("returns true when tip is marked as seen", () => {
      storage.store[STORAGE_KEYS.SEEN] = JSON.stringify({ first_message: true });
      expect(isTipSeen("first_message")).toBe(true);
    });

    it("returns false for unseen tip when others are seen", () => {
      storage.store[STORAGE_KEYS.SEEN] = JSON.stringify({ first_message: true });
      expect(isTipSeen("first_join")).toBe(false);
    });

    it("handles corrupted JSON gracefully", () => {
      storage.store[STORAGE_KEYS.SEEN] = "not-json";
      expect(isTipSeen("first_message")).toBe(false);
    });
  });

  describe("markTipSeen", () => {
    it("marks a tip as seen", () => {
      markTipSeen("first_message");
      const seen = JSON.parse(storage.store[STORAGE_KEYS.SEEN]);
      expect(seen.first_message).toBe(true);
    });

    it("preserves previously seen tips", () => {
      markTipSeen("first_message");
      markTipSeen("first_join");
      const seen = JSON.parse(storage.store[STORAGE_KEYS.SEEN]);
      expect(seen.first_message).toBe(true);
      expect(seen.first_join).toBe(true);
    });

    it("handles localStorage full gracefully", () => {
      vi.spyOn(Storage.prototype, "setItem").mockImplementation(() => {
        throw new DOMException("QuotaExceededError");
      });
      expect(() => markTipSeen("first_message")).not.toThrow();
    });
  });

  // ── shouldShowTip ─────────────────────────────────────────

  describe("shouldShowTip", () => {
    it("returns true for unseen, unsuppressed tip", () => {
      expect(shouldShowTip("first_message")).toBe(true);
    });

    it("returns false when tip is seen", () => {
      markTipSeen("first_message");
      expect(shouldShowTip("first_message")).toBe(false);
    });

    it("returns false when globally suppressed", () => {
      setSuppressed(true);
      expect(shouldShowTip("first_message")).toBe(false);
    });
  });

  // ── markPreempted ─────────────────────────────────────────

  describe("markPreempted", () => {
    it("marks idle_help as seen when help_used action fires", () => {
      markPreempted("help_used");
      expect(isTipSeen("idle_help")).toBe(true);
    });

    it("does not affect unrelated tips", () => {
      markPreempted("help_used");
      expect(isTipSeen("first_message")).toBe(false);
    });

    it("ignores unknown action IDs", () => {
      markPreempted("unknown_action");
      expect(isTipSeen("idle_help")).toBe(false);
    });
  });

  // ── getTipById ────────────────────────────────────────────

  describe("getTipById", () => {
    it("returns tip definition for valid ID", () => {
      const tip = getTipById("first_message");
      expect(tip).toBeDefined();
      expect(tip.text).toBe("Use ↑ to edit your last message");
    });

    it("returns undefined for invalid ID", () => {
      expect(getTipById("nonexistent")).toBeUndefined();
    });
  });

  // ── resetAllTips ──────────────────────────────────────────

  describe("resetAllTips", () => {
    it("clears all tip state", () => {
      markTipSeen("first_message");
      setSuppressed(true);
      resetAllTips();
      expect(isTipSeen("first_message")).toBe(false);
      expect(isSuppressed()).toBe(false);
    });
  });
});
