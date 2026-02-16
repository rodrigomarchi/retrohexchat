import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import {
  isSupported,
  getPermission,
  requestPermission,
  show,
} from "../../js/lib/browser_notification.js";

describe("browser_notification", () => {
  let originalNotification;

  beforeEach(() => {
    originalNotification = globalThis.Notification;
  });

  afterEach(() => {
    if (originalNotification) {
      globalThis.Notification = originalNotification;
    } else {
      delete globalThis.Notification;
    }
  });

  describe("isSupported", () => {
    it("returns true when Notification is defined", () => {
      globalThis.Notification = { permission: "default", requestPermission: vi.fn() };
      expect(isSupported()).toBe(true);
    });

    it("returns false when Notification is not defined", () => {
      delete globalThis.Notification;
      expect(isSupported()).toBe(false);
    });
  });

  describe("getPermission", () => {
    it('returns "granted" when permission is granted', () => {
      globalThis.Notification = { permission: "granted" };
      expect(getPermission()).toBe("granted");
    });

    it('returns "denied" when permission is denied', () => {
      globalThis.Notification = { permission: "denied" };
      expect(getPermission()).toBe("denied");
    });

    it('returns "default" when permission is default', () => {
      globalThis.Notification = { permission: "default" };
      expect(getPermission()).toBe("default");
    });

    it('returns "unsupported" when Notification API not available', () => {
      delete globalThis.Notification;
      expect(getPermission()).toBe("unsupported");
    });
  });

  describe("requestPermission", () => {
    it("calls Notification.requestPermission", async () => {
      globalThis.Notification = {
        permission: "default",
        requestPermission: vi.fn().mockResolvedValue("granted"),
      };

      const result = await requestPermission();
      expect(result).toBe("granted");
      expect(Notification.requestPermission).toHaveBeenCalledOnce();
    });

    it('returns "unsupported" when API not available', async () => {
      delete globalThis.Notification;
      const result = await requestPermission();
      expect(result).toBe("unsupported");
    });

    it('returns "denied" when requestPermission throws', async () => {
      globalThis.Notification = {
        permission: "default",
        requestPermission: vi.fn().mockRejectedValue(new Error("fail")),
      };

      const result = await requestPermission();
      expect(result).toBe("denied");
    });
  });

  describe("show", () => {
    it("creates notification when permission is granted", () => {
      const mockNotif = { onclick: null, close: vi.fn() };
      const MockNotification = vi.fn(function () {
        Object.assign(this, mockNotif);
      });
      MockNotification.permission = "granted";
      globalThis.Notification = MockNotification;

      const result = show("Title", "Body");
      expect(MockNotification).toHaveBeenCalledWith(
        "Title",
        expect.objectContaining({ body: "Body" }),
      );
      expect(result).toBeTypeOf("object");
    });

    it("returns null when permission is not granted", () => {
      globalThis.Notification = { permission: "denied" };
      const result = show("Title", "Body");
      expect(result).toBeNull();
    });

    it("returns null when API not available", () => {
      delete globalThis.Notification;
      const result = show("Title", "Body");
      expect(result).toBeNull();
    });

    it("sets onclick callback when provided", () => {
      let instance;
      const MockNotification = vi.fn(function () {
        this.onclick = null;
        this.close = vi.fn();
        instance = this;
      });
      MockNotification.permission = "granted";
      globalThis.Notification = MockNotification;

      const onClick = vi.fn();
      show("Title", "Body", onClick);

      expect(instance.onclick).toBeTypeOf("function");
    });
  });
});
