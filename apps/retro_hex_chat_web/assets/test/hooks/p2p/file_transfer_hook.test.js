import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import FileTransferHook from "../../../js/hooks/p2p/file_transfer_hook.js";
import { mountHook, simulateEvent, cleanupDOM } from "../../helpers/hook_helper.js";
import { STATE } from "../../../js/lib/p2p/file_transfer.js";

function createMockChannel() {
  const sent = [];
  return {
    readyState: "open",
    bufferedAmount: 0,
    bufferedAmountLowThreshold: 0,
    onmessage: null,
    onopen: null,
    onclose: null,
    onbufferedamountlow: null,
    send(data) {
      sent.push(data);
    },
    _sent: sent,
    close() {
      this.readyState = "closed";
    },
  };
}

describe("FileTransferHook", () => {
  let hook;

  beforeEach(() => {
    hook = mountHook(FileTransferHook, {
      attrs: { id: "p2p-file-transfer" },
      html: '<input type="file" class="file-transfer-input u-hidden" />',
    });
  });

  afterEach(() => {
    cleanupDOM();
  });

  // --- T016: mounted/destroyed lifecycle ---

  describe("mounted", () => {
    it("registers ft_channel_ready handleEvent", () => {
      expect(hook.handleEvent).toHaveBeenCalledWith("ft_channel_ready", expect.any(Function));
    });

    it("registers ft_config handleEvent", () => {
      expect(hook.handleEvent).toHaveBeenCalledWith("ft_config", expect.any(Function));
    });

    it("pushes file_transfer_ready after mounting", () => {
      expect(hook.pushEvent).toHaveBeenCalledWith("file_transfer_ready", {});
    });

    it("sets up drag-and-drop listeners on the element", () => {
      const dragEvent = new Event("dragover");
      hook.el.dispatchEvent(dragEvent);
      // Should not throw
    });
  });

  describe("late mount — picks up existing open channel", () => {
    it("sets up channel from webrtc element when already open", () => {
      // Clean up the hook from beforeEach
      cleanupDOM();

      // Create a mock webrtc element with an already-open channel
      const webrtcEl = document.createElement("div");
      webrtcEl.id = "p2p-webrtc";
      document.body.appendChild(webrtcEl);

      const channel = createMockChannel();
      webrtcEl._fileTransferChannel = channel;

      // Mount hook — should pick up existing channel
      const lateHook = mountHook(FileTransferHook, {
        attrs: { id: "p2p-file-transfer" },
        html: '<input type="file" class="file-transfer-input u-hidden" />',
      });

      expect(lateHook._channel).toBe(channel);
      expect(channel.onmessage).toBeTypeOf("function");
    });
  });

  describe("ft_config event", () => {
    it("stores validation config", () => {
      simulateEvent(hook, "ft_config", {
        max_size_mb: 500,
        blocked_extensions: [".exe", ".bat"],
      });
      expect(hook._config).toBeTruthy();
      expect(hook._config.maxSizeBytes).toBe(500 * 1024 * 1024);
    });
  });

  describe("ft_channel_ready event", () => {
    it("stores channel reference and sets up onmessage", () => {
      const channel = createMockChannel();
      simulateEvent(hook, "ft_channel_ready", { channel });

      expect(hook._channel).toBe(channel);
      expect(channel.onmessage).toBeTypeOf("function");
    });
  });

  // --- T016: file input wiring ---

  describe("file selection", () => {
    it("validates file and pushes ft_offer_sent on valid file", async () => {
      const channel = createMockChannel();
      simulateEvent(hook, "ft_config", {
        max_size_mb: 500,
        blocked_extensions: [".exe"],
      });
      simulateEvent(hook, "ft_channel_ready", { channel });

      // Simulate file selection
      const file = new File(["hello"], "test.txt", { type: "text/plain" });
      await hook._handleFileSelected(file);

      // Should have pushed ft_offer_sent
      await vi.waitFor(() => {
        const offerEvents = hook.__pushEvents.filter((e) => e.event === "ft_offer_sent");
        expect(offerEvents.length).toBe(1);
        expect(offerEvents[0].payload.file_name).toBe("test.txt");
      });
    });

    it("pushes ft_validation_error on blocked extension", async () => {
      simulateEvent(hook, "ft_config", {
        max_size_mb: 500,
        blocked_extensions: [".exe"],
      });
      const channel = createMockChannel();
      simulateEvent(hook, "ft_channel_ready", { channel });

      const file = new File(["bad"], "virus.exe", { type: "application/octet-stream" });
      await hook._handleFileSelected(file);

      const errors = hook.__pushEvents.filter((e) => e.event === "ft_validation_error");
      expect(errors.length).toBe(1);
      expect(errors[0].payload.error).toContain(".exe");
    });
  });

  describe("file selection without config", () => {
    it("pushes ft_validation_error when config not loaded", async () => {
      // No ft_config event — _config is null
      const file = new File(["hello"], "test.txt", { type: "text/plain" });
      await hook._handleFileSelected(file);

      const errors = hook.__pushEvents.filter((e) => e.event === "ft_validation_error");
      expect(errors.length).toBe(1);
      expect(errors[0].payload.error).toBeTruthy();
    });
  });

  // --- T030: cancel ---

  describe("cancel flow", () => {
    it("sends cancel message via DataChannel and pushes ft_cancelled", () => {
      const channel = createMockChannel();
      simulateEvent(hook, "ft_config", { max_size_mb: 500, blocked_extensions: [] });
      simulateEvent(hook, "ft_channel_ready", { channel });

      // Set up an active session
      hook._session = {
        transferId: "t1",
        state: STATE.TRANSFERRING,
        role: "sender",
      };

      hook._handleCancel("alice");

      expect(channel._sent.length).toBe(1);
      const cancelled = hook.__pushEvents.filter((e) => e.event === "ft_cancelled");
      expect(cancelled.length).toBe(1);
      expect(cancelled[0].payload.cancelled_by).toBe("alice");
    });
  });

  // --- T035: resume ---

  describe("resume flow", () => {
    it("pauses session on channel close", () => {
      const channel = createMockChannel();
      simulateEvent(hook, "ft_config", { max_size_mb: 500, blocked_extensions: [] });
      simulateEvent(hook, "ft_channel_ready", { channel });

      hook._session = {
        transferId: "t1",
        state: STATE.TRANSFERRING,
        role: "receiver",
        receivedSet: new Set([0, 1, 2]),
      };

      hook._handleChannelClose();
      expect(hook._session.state).toBe(STATE.PAUSED);
    });
  });

  // --- T040: hash failure ---

  describe("hash failure flow", () => {
    it("pushes ft_failed on hash mismatch", () => {
      hook._session = {
        transferId: "t1",
        state: STATE.VERIFYING,
        role: "receiver",
      };

      hook._handleHashResult(false);

      const failed = hook.__pushEvents.filter((e) => e.event === "ft_failed");
      expect(failed.length).toBe(1);
      expect(failed[0].payload.reason).toContain("Integrity");
    });
  });

  // --- T045: queue ---

  describe("queue behavior", () => {
    it("queues a file when transfer is active", () => {
      hook._session = {
        state: STATE.TRANSFERRING,
        transferId: "t1",
      };

      const file = new File(["data"], "queued.txt", { type: "text/plain" });
      hook._enqueueOrSend(file);

      expect(hook._queue.length).toBe(1);
      expect(hook._queue[0].file).toBe(file);
    });
  });
});
