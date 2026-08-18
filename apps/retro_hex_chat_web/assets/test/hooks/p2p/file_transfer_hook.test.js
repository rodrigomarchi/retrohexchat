import { afterEach, beforeEach, describe, expect, it } from "vitest";

import FileTransferHook from "../../../js/hooks/p2p/file_transfer_hook.js";
import { cleanupDOM, getPushEvents, mountHook, simulateEvent } from "../../helpers/hook_helper.js";

// The protocol transitions live in lib/p2p/transfer_session.js and are covered
// by test/lib/p2p/transfer_session.test.js. This test covers only the wiring:
// server events and DOM in, pushEvents and channel sends out.

function mockChannel() {
  const sent = [];
  return {
    readyState: "open",
    bufferedAmount: 0,
    send: (data) => sent.push(data),
    _sent: sent,
    close() {
      this.readyState = "closed";
    },
  };
}

// jsdom's input.files is read-only; define it, then fire change.
function selectFile(input, file) {
  Object.defineProperty(input, "files", { value: [file], configurable: true });
  input.dispatchEvent(new Event("change", { bubbles: true }));
}

describe("FileTransferHook wiring", () => {
  let hook;
  let input;

  beforeEach(() => {
    hook = mountHook(FileTransferHook, {
      attrs: { id: "p2p-file-transfer" },
      html: '<input type="file" class="file-transfer-input u-hidden" />',
    });
    input = hook.el.querySelector(".file-transfer-input");
  });

  afterEach(() => cleanupDOM());

  describe("mount", () => {
    it("registers the server events and announces readiness", () => {
      expect(hook.handleEvent).toHaveBeenCalledWith("ft_channel_ready", expect.any(Function));
      expect(hook.handleEvent).toHaveBeenCalledWith("ft_config", expect.any(Function));
      expect(hook.pushEvent).toHaveBeenCalledWith("file_transfer_ready", {});
    });

    it("does not throw on a dragover", () => {
      expect(() => hook.el.dispatchEvent(new Event("dragover"))).not.toThrow();
    });
  });

  describe("ft_channel_ready", () => {
    it("wires the channel's onmessage", () => {
      const channel = mockChannel();
      simulateEvent(hook, "ft_channel_ready", { channel });
      expect(channel.onmessage).toBeTypeOf("function");
    });
  });

  describe("file selection", () => {
    function ready(blocked = []) {
      simulateEvent(hook, "ft_config", { max_size_mb: 500, blocked_extensions: blocked });
      simulateEvent(hook, "ft_channel_ready", { channel: mockChannel() });
    }

    it("offers a valid file", async () => {
      ready([".exe"]);
      selectFile(input, new File(["hello"], "test.txt", { type: "text/plain" }));

      await vi.waitFor(() => {
        const offers = getPushEvents(hook, "ft_offer_sent");
        expect(offers).toHaveLength(1);
        expect(offers[0].file_name).toBe("test.txt");
      });
    });

    it("rejects a blocked extension with the extension named", async () => {
      ready([".exe"]);
      selectFile(input, new File(["bad"], "virus.exe", { type: "application/octet-stream" }));

      await vi.waitFor(() => {
        const errors = getPushEvents(hook, "ft_validation_error");
        expect(errors).toHaveLength(1);
        expect(errors[0].error).toContain(".exe");
      });
    });

    it("rejects any file before config has loaded", async () => {
      selectFile(input, new File(["hi"], "test.txt", { type: "text/plain" }));

      await vi.waitFor(() => {
        expect(getPushEvents(hook, "ft_validation_error")).toHaveLength(1);
      });
    });

    it("queues a second file while the first is in flight", async () => {
      ready();
      selectFile(input, new File(["a"], "first.txt", { type: "text/plain" }));
      await vi.waitFor(() => expect(getPushEvents(hook, "ft_offer_sent")).toHaveLength(1));

      selectFile(input, new File(["b"], "second.txt", { type: "text/plain" }));
      await vi.waitFor(() => {
        const queued = getPushEvents(hook, "ft_queued");
        expect(queued).toHaveLength(1);
        expect(queued[0].file_name).toBe("second.txt");
      });
    });
  });

  describe("cancel", () => {
    it("cancels an in-flight transfer from a server ft_cancel event", async () => {
      const channel = mockChannel();
      simulateEvent(hook, "ft_config", { max_size_mb: 500, blocked_extensions: [] });
      simulateEvent(hook, "ft_channel_ready", { channel });
      selectFile(input, new File(["a"], "first.txt", { type: "text/plain" }));
      await vi.waitFor(() => expect(getPushEvents(hook, "ft_offer_sent")).toHaveLength(1));

      channel._sent.length = 0; // ignore the offer already sent
      simulateEvent(hook, "ft_cancel", { nickname: "alice" });

      const cancelled = getPushEvents(hook, "ft_cancelled");
      expect(cancelled).toHaveLength(1);
      expect(cancelled[0].cancelled_by).toBe("alice");
      expect(channel._sent.length).toBe(1); // the cancel control message
    });
  });
});
