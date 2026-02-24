import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { mockLocalStorage } from "../../helpers/hook_helper.js";
import {
  loadPrefs,
  savePrefs,
  defaultPrefs,
  STORAGE_KEY,
} from "../../../js/lib/notifications/notification_prefs.js";

describe("notification_prefs", () => {
  let storage;

  beforeEach(() => {
    storage = mockLocalStorage();
  });

  afterEach(() => {
    storage.restore();
  });

  describe("defaultPrefs", () => {
    it("returns default notification preferences", () => {
      const prefs = defaultPrefs();

      expect(prefs.sounds_enabled).toBe(true);
      expect(prefs.browser_notifications).toBe(false);
      expect(prefs.title_flash_enabled).toBe(true);
      expect(prefs.privacy_mode).toBe(false);
      expect(prefs.dnd_enabled).toBe(false);
    });

    it("returns default trigger rules", () => {
      const prefs = defaultPrefs();

      expect(prefs.trigger_mentions).toBe(true);
      expect(prefs.trigger_pms).toBe(true);
      expect(prefs.trigger_channel_messages).toBe(false);
      expect(prefs.trigger_joins_leaves).toBe(false);
    });

    it("returns empty channel levels", () => {
      const prefs = defaultPrefs();
      expect(prefs.channel_levels).toEqual({});
    });
  });

  describe("loadPrefs", () => {
    it("returns defaults when localStorage is empty", () => {
      const prefs = loadPrefs();
      expect(prefs).toEqual(defaultPrefs());
    });

    it("loads saved preferences from localStorage", () => {
      storage.store[STORAGE_KEY] = JSON.stringify({
        sounds_enabled: false,
        dnd_enabled: true,
        channel_levels: { "#dev": "mentions_only" },
      });

      const prefs = loadPrefs();
      expect(prefs.sounds_enabled).toBe(false);
      expect(prefs.dnd_enabled).toBe(true);
      expect(prefs.channel_levels["#dev"]).toBe("mentions_only");
    });

    it("merges with defaults for missing keys", () => {
      storage.store[STORAGE_KEY] = JSON.stringify({
        sounds_enabled: false,
      });

      const prefs = loadPrefs();
      expect(prefs.sounds_enabled).toBe(false);
      expect(prefs.browser_notifications).toBe(false);
      expect(prefs.trigger_mentions).toBe(true);
      expect(prefs.channel_levels).toEqual({});
    });

    it("returns defaults for corrupted JSON", () => {
      storage.store[STORAGE_KEY] = "not valid json{{{";

      const prefs = loadPrefs();
      expect(prefs).toEqual(defaultPrefs());
    });
  });

  describe("savePrefs", () => {
    it("saves preferences to localStorage", () => {
      const prefs = { ...defaultPrefs(), sounds_enabled: false };
      savePrefs(prefs);

      const stored = JSON.parse(storage.store[STORAGE_KEY]);
      expect(stored.sounds_enabled).toBe(false);
    });

    it("overwrites previous preferences", () => {
      savePrefs({ ...defaultPrefs(), dnd_enabled: true });
      savePrefs({ ...defaultPrefs(), dnd_enabled: false });

      const stored = JSON.parse(storage.store[STORAGE_KEY]);
      expect(stored.dnd_enabled).toBe(false);
    });

    it("round-trips through load", () => {
      const prefs = {
        ...defaultPrefs(),
        sounds_enabled: false,
        privacy_mode: true,
        channel_levels: { "#music": "mute", "#dev": "mentions_only" },
      };

      savePrefs(prefs);
      const loaded = loadPrefs();

      expect(loaded.sounds_enabled).toBe(false);
      expect(loaded.privacy_mode).toBe(true);
      expect(loaded.channel_levels["#music"]).toBe("mute");
      expect(loaded.channel_levels["#dev"]).toBe("mentions_only");
    });
  });

  describe("STORAGE_KEY", () => {
    it("exports the expected key", () => {
      expect(STORAGE_KEY).toBe("retro_hex_chat_notification_prefs");
    });
  });
});
