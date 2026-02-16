import { mountHook, simulateEvent, cleanupDOM, mockLocalStorage } from "../helpers/hook_helper.js";

// Mock lib modules before importing hook
vi.mock("../../js/lib/notification_dispatcher.js", () => ({
  createDispatcher: vi.fn(() => ({
    dispatch: vi.fn(),
    dispatchBatch: vi.fn(),
  })),
}));

vi.mock("../../js/lib/notification_toast.js", () => ({
  createNotificationToastManager: vi.fn(() => ({
    show: vi.fn(),
    showBatch: vi.fn(),
    clear: vi.fn(),
    getVisibleCount: vi.fn(() => 0),
  })),
}));

vi.mock("../../js/lib/browser_notification.js", () => ({
  show: vi.fn(),
  getPermission: vi.fn(() => "default"),
  isSupported: vi.fn(() => true),
}));

vi.mock("../../js/lib/favicon_badge.js", () => ({
  createFaviconBadge: vi.fn(() => ({
    show: vi.fn(),
    clear: vi.fn(),
    isActive: vi.fn(() => false),
  })),
}));

vi.mock("../../js/lib/notification_prefs.js", () => ({
  loadPrefs: vi.fn(() => ({
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
  })),
  savePrefs: vi.fn(),
}));

import { createDispatcher } from "../../js/lib/notification_dispatcher.js";
import NotificationDispatcherHook from "../../js/hooks/notification_dispatcher_hook.js";

describe("NotificationDispatcherHook", () => {
  let hook;
  let storage;
  let mockDispatcher;

  beforeEach(() => {
    storage = mockLocalStorage();

    // Create toast container
    const toastContainer = document.createElement("div");
    toastContainer.id = "notification-toasts";
    document.body.appendChild(toastContainer);

    // Reset mock dispatcher
    mockDispatcher = {
      dispatch: vi.fn(),
      dispatchBatch: vi.fn(),
    };
    createDispatcher.mockReturnValue(mockDispatcher);

    hook = mountHook(NotificationDispatcherHook);
  });

  afterEach(() => {
    cleanupDOM();
    storage.restore();
    vi.clearAllMocks();
  });

  describe("mounted", () => {
    it("creates a dispatcher", () => {
      expect(createDispatcher).toHaveBeenCalledOnce();
    });

    it("registers notify event handler", () => {
      expect(hook.handleEvent).toHaveBeenCalledWith("notify", expect.any(Function));
    });

    it("registers notification_batch event handler", () => {
      expect(hook.handleEvent).toHaveBeenCalledWith("notification_batch", expect.any(Function));
    });
  });

  describe("notify event", () => {
    it("calls dispatcher.dispatch with event payload", () => {
      const payload = {
        id: "notif_1",
        type: "mention",
        channel: "#dev",
        sender: "Mario",
        content: "Hey!",
      };

      simulateEvent(hook, "notify", payload);

      expect(mockDispatcher.dispatch).toHaveBeenCalledOnce();
      expect(mockDispatcher.dispatch).toHaveBeenCalledWith(
        payload,
        expect.any(Object),
        expect.any(Object),
      );
    });
  });

  describe("notification_batch event", () => {
    it("calls dispatcher.dispatchBatch with batch data", () => {
      const batch = { count: 15, channels: ["#dev", "#general"], channel_count: 2 };

      simulateEvent(hook, "notification_batch", batch);

      expect(mockDispatcher.dispatchBatch).toHaveBeenCalledOnce();
      expect(mockDispatcher.dispatchBatch).toHaveBeenCalledWith(batch, expect.any(Object));
    });
  });

  describe("update_notification_prefs event", () => {
    it("registers handler for preference updates", () => {
      expect(hook.handleEvent).toHaveBeenCalledWith(
        "update_notification_prefs",
        expect.any(Function),
      );
    });
  });
});
