import { describe, it, expect, beforeEach, vi } from "vitest";
import { createDispatcher } from "../../js/lib/notification_dispatcher.js";

describe("notification_dispatcher", () => {
  let toast, sound, titleFlash, browserNotif, faviconBadge;
  let dispatcher;

  function defaultPrefs() {
    return {
      sounds_enabled: true,
      browser_notifications: true,
      title_flash_enabled: true,
      privacy_mode: false,
      dnd_enabled: false,
      trigger_mentions: true,
      trigger_pms: true,
      trigger_channel_messages: false,
      trigger_joins_leaves: false,
      channel_levels: {},
    };
  }

  function makeEvent(overrides = {}) {
    return {
      id: "notif_1",
      type: "mention",
      channel: "#dev",
      sender: "Mario",
      content: "Hey @Nick!",
      timestamp: "2026-02-15T10:00:00Z",
      highlighted: true,
      ...overrides,
    };
  }

  beforeEach(() => {
    toast = { show: vi.fn() };
    sound = { play: vi.fn() };
    titleFlash = { start: vi.fn() };
    browserNotif = { show: vi.fn() };
    faviconBadge = { show: vi.fn(), clear: vi.fn() };

    dispatcher = createDispatcher({ toast, sound, titleFlash, browserNotif, faviconBadge });
  });

  describe("dispatch", () => {
    it("fires all channels for mention in non-active channel", () => {
      dispatcher.dispatch(makeEvent(), defaultPrefs(), {
        activeChannel: "#general",
        tabVisible: false,
      });

      expect(toast.show).toHaveBeenCalledOnce();
      expect(sound.play).toHaveBeenCalledWith("mention");
      expect(titleFlash.start).toHaveBeenCalled();
      expect(browserNotif.show).toHaveBeenCalled();
      expect(faviconBadge.show).toHaveBeenCalled();
    });

    it("suppresses notifications for active channel", () => {
      dispatcher.dispatch(makeEvent({ channel: "#dev" }), defaultPrefs(), {
        activeChannel: "#dev",
        tabVisible: true,
      });

      expect(toast.show).not.toHaveBeenCalled();
      expect(sound.play).not.toHaveBeenCalled();
    });

    it("does not suppress PMs even when channel matches", () => {
      dispatcher.dispatch(makeEvent({ type: "pm", channel: null }), defaultPrefs(), {
        activeChannel: "#dev",
        tabVisible: true,
      });

      expect(toast.show).toHaveBeenCalledOnce();
    });

    it("skips browser notification when tab is visible", () => {
      dispatcher.dispatch(makeEvent(), defaultPrefs(), {
        activeChannel: "#general",
        tabVisible: true,
      });

      expect(browserNotif.show).not.toHaveBeenCalled();
      expect(toast.show).toHaveBeenCalledOnce();
    });

    it("updates favicon in DND but skips toast/sound", () => {
      const prefs = { ...defaultPrefs(), dnd_enabled: true };

      dispatcher.dispatch(makeEvent(), prefs, {
        activeChannel: "#general",
        tabVisible: true,
      });

      expect(faviconBadge.show).toHaveBeenCalledOnce();
      expect(toast.show).not.toHaveBeenCalled();
      expect(sound.play).not.toHaveBeenCalled();
      expect(titleFlash.start).not.toHaveBeenCalled();
    });

    it("skips toast/sound for muted channel", () => {
      const prefs = { ...defaultPrefs(), channel_levels: { "#music": "mute" } };

      dispatcher.dispatch(makeEvent({ channel: "#music" }), prefs, {
        activeChannel: "#general",
        tabVisible: true,
      });

      expect(toast.show).not.toHaveBeenCalled();
      expect(sound.play).not.toHaveBeenCalled();
    });

    it("skips non-highlighted in mentions_only channel", () => {
      const prefs = {
        ...defaultPrefs(),
        trigger_channel_messages: true,
        channel_levels: { "#general": "mentions_only" },
      };

      dispatcher.dispatch(
        makeEvent({ type: "channel_message", channel: "#general", highlighted: false }),
        prefs,
        { activeChannel: "#dev", tabVisible: true },
      );

      expect(toast.show).not.toHaveBeenCalled();
    });

    it("notifies for highlighted in mentions_only channel", () => {
      const prefs = { ...defaultPrefs(), channel_levels: { "#general": "mentions_only" } };

      dispatcher.dispatch(
        makeEvent({ type: "mention", channel: "#general", highlighted: true }),
        prefs,
        {
          activeChannel: "#dev",
          tabVisible: true,
        },
      );

      expect(toast.show).toHaveBeenCalledOnce();
    });

    it("skips channel_message when trigger is disabled (default)", () => {
      dispatcher.dispatch(makeEvent({ type: "channel_message" }), defaultPrefs(), {
        activeChannel: "#general",
        tabVisible: true,
      });

      expect(toast.show).not.toHaveBeenCalled();
    });

    it("skips sound when sounds_enabled is false", () => {
      const prefs = { ...defaultPrefs(), sounds_enabled: false };

      dispatcher.dispatch(makeEvent(), prefs, {
        activeChannel: "#general",
        tabVisible: true,
      });

      expect(toast.show).toHaveBeenCalledOnce();
      expect(sound.play).not.toHaveBeenCalled();
    });

    it("skips title flash when title_flash_enabled is false", () => {
      const prefs = { ...defaultPrefs(), title_flash_enabled: false };

      dispatcher.dispatch(makeEvent(), prefs, {
        activeChannel: "#general",
        tabVisible: true,
      });

      expect(titleFlash.start).not.toHaveBeenCalled();
    });

    it("applies privacy mode to toast content", () => {
      const prefs = { ...defaultPrefs(), privacy_mode: true };

      dispatcher.dispatch(makeEvent({ channel: "#dev" }), prefs, {
        activeChannel: "#general",
        tabVisible: true,
      });

      expect(toast.show).toHaveBeenCalledOnce();
      const call = toast.show.mock.calls[0][0];
      expect(call.title).toBe("New message in #dev");
      expect(call.body).not.toContain("Mario");
      expect(call.body).not.toContain("Hey @Nick!");
    });

    it("applies privacy mode to PM content", () => {
      const prefs = { ...defaultPrefs(), privacy_mode: true };

      dispatcher.dispatch(makeEvent({ type: "pm", channel: null }), prefs, {
        activeChannel: "#general",
        tabVisible: true,
      });

      const call = toast.show.mock.calls[0][0];
      expect(call.title).toBe("New private message");
    });
  });

  describe("dispatchBatch", () => {
    it("shows summary toast for batch", () => {
      dispatcher.dispatchBatch(
        { count: 15, channels: ["#dev", "#general"], channel_count: 2 },
        defaultPrefs(),
      );

      expect(toast.show).toHaveBeenCalledOnce();
      const call = toast.show.mock.calls[0][0];
      expect(call.body).toContain("15 new messages in 2 channels");
    });

    it("updates favicon for batch", () => {
      dispatcher.dispatchBatch({ count: 5, channels: ["#dev"], channel_count: 1 }, defaultPrefs());
      expect(faviconBadge.show).toHaveBeenCalledOnce();
    });

    it("skips toast in DND for batch", () => {
      const prefs = { ...defaultPrefs(), dnd_enabled: true };
      dispatcher.dispatchBatch({ count: 5, channels: ["#dev"], channel_count: 1 }, prefs);

      expect(faviconBadge.show).toHaveBeenCalledOnce();
      expect(toast.show).not.toHaveBeenCalled();
    });
  });
});
