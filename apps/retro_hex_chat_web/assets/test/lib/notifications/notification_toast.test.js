import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import {
  createNotificationToastManager,
  MAX_VISIBLE,
  DISMISS_MS,
} from "../../../js/lib/notifications/notification_toast.js";

describe("notification_toast", () => {
  let container;
  let manager;

  beforeEach(() => {
    container = document.createElement("div");
    document.body.appendChild(container);
    manager = createNotificationToastManager({ container });
  });

  afterEach(() => {
    document.body.innerHTML = "";
    vi.restoreAllMocks();
  });

  describe("MAX_VISIBLE", () => {
    it("exports MAX_VISIBLE as 3", () => {
      expect(MAX_VISIBLE).toBe(3);
    });
  });

  describe("DISMISS_MS", () => {
    it("exports DISMISS_MS as 5000", () => {
      expect(DISMISS_MS).toBe(5000);
    });
  });

  describe("show", () => {
    it("adds toast to container", () => {
      manager.show({ id: "1", title: "Test", body: "Hello" });
      expect(container.children.length).toBe(1);
    });

    it("increments visible count", () => {
      manager.show({ id: "1", title: "Test", body: "Hello" });
      expect(manager.getVisibleCount()).toBe(1);
    });

    it("displays up to MAX_VISIBLE toasts", () => {
      manager.show({ id: "1", title: "T1", body: "B1" });
      manager.show({ id: "2", title: "T2", body: "B2" });
      manager.show({ id: "3", title: "T3", body: "B3" });

      expect(manager.getVisibleCount()).toBe(3);
      expect(container.children.length).toBe(3);
    });

    it("queues beyond MAX_VISIBLE", () => {
      manager.show({ id: "1", title: "T1", body: "B1" });
      manager.show({ id: "2", title: "T2", body: "B2" });
      manager.show({ id: "3", title: "T3", body: "B3" });
      manager.show({ id: "4", title: "T4", body: "B4" });

      expect(manager.getVisibleCount()).toBe(3);
    });
  });

  describe("showBatch", () => {
    it("shows summary toast", () => {
      manager.showBatch(15, 3);
      expect(container.children.length).toBe(1);
    });
  });

  describe("click callback", () => {
    it("calls onNavigate when toast is clicked", () => {
      const onNavigate = vi.fn();
      const mgr = createNotificationToastManager({ container, onNavigate });

      mgr.show({ id: "1", title: "Test", body: "Hello", channel: "#dev", type: "mention" });

      const toastEl = container.querySelector(".notification-toast");
      expect(toastEl).not.toBeNull();
      toastEl.click();

      expect(onNavigate).toHaveBeenCalledWith({ channel: "#dev", type: "mention" });
    });
  });

  describe("clear", () => {
    it("removes all visible toasts", () => {
      manager.show({ id: "1", title: "T1", body: "B1" });
      manager.show({ id: "2", title: "T2", body: "B2" });
      manager.clear();

      expect(manager.getVisibleCount()).toBe(0);
    });
  });
});
