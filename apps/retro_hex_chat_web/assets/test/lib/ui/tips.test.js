import {
  isSuppressed,
  setSuppressed,
  isTipSeen,
  markTipSeen,
  shouldShowTip,
  markPreempted,
  getTipById,
  resetAllTips,
  loadTipsState,
  tipsStateSnapshot,
  TIP_IDS,
  TIPS,
  AUTO_DISMISS_MS,
  QUEUE_GAP_MS,
  IDLE_TIMEOUT_MS,
} from "../../../js/lib/ui/tips.js";

describe("tips", () => {
  let localStorageMock;

  beforeEach(() => {
    localStorageMock = {
      getItem: vi.fn(() => {
        throw new Error("tips must not read localStorage");
      }),
      setItem: vi.fn(() => {
        throw new Error("tips must not write localStorage");
      }),
      removeItem: vi.fn(() => {
        throw new Error("tips must not remove localStorage");
      }),
    };

    vi.stubGlobal("localStorage", localStorageMock);
    resetAllTips();
  });

  afterEach(() => {
    vi.unstubAllGlobals();
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

    it("returns true when server snapshot is suppressed", () => {
      loadTipsState({ suppressed: true });
      expect(isSuppressed()).toBe(true);
    });

    it("ignores malformed suppressed snapshots", () => {
      loadTipsState({ suppressed: "true" });
      expect(isSuppressed()).toBe(false);
    });
  });

  describe("setSuppressed", () => {
    it("sets suppression in memory", () => {
      setSuppressed(true);
      expect(isSuppressed()).toBe(true);
      expect(tipsStateSnapshot()).toEqual({ seen_tips: [], suppressed: true });
    });

    it("clears suppression in memory", () => {
      setSuppressed(true);
      setSuppressed(false);
      expect(isSuppressed()).toBe(false);
    });

    it("does not use localStorage", () => {
      setSuppressed(true);
      expect(localStorageMock.getItem).not.toHaveBeenCalled();
      expect(localStorageMock.setItem).not.toHaveBeenCalled();
      expect(localStorageMock.removeItem).not.toHaveBeenCalled();
    });
  });

  // ── isTipSeen / markTipSeen ───────────────────────────────

  describe("isTipSeen", () => {
    it("returns false when no tips are seen", () => {
      expect(isTipSeen("first_message")).toBe(false);
    });

    it("returns true when tip is marked as seen", () => {
      loadTipsState({ seen_tips: ["first_message"] });
      expect(isTipSeen("first_message")).toBe(true);
    });

    it("returns false for unseen tip when others are seen", () => {
      loadTipsState({ seen_tips: ["first_message"] });
      expect(isTipSeen("first_join")).toBe(false);
    });

    it("handles malformed snapshots gracefully", () => {
      loadTipsState({ seen_tips: "not-a-list" });
      expect(isTipSeen("first_message")).toBe(false);
    });
  });

  describe("markTipSeen", () => {
    it("marks a tip as seen", () => {
      markTipSeen("first_message");
      expect(isTipSeen("first_message")).toBe(true);
    });

    it("preserves previously seen tips", () => {
      markTipSeen("first_message");
      markTipSeen("first_join");
      expect(tipsStateSnapshot().seen_tips).toEqual(["first_message", "first_join"]);
    });

    it("ignores unknown tip IDs", () => {
      expect(markTipSeen("unknown")).toBe(false);
      expect(tipsStateSnapshot().seen_tips).toEqual([]);
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
