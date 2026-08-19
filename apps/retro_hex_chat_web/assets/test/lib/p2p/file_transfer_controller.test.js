import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { createFileTransferController } from "../../../js/lib/p2p/file_transfer_controller.js";

// The protocol transitions live in lib/p2p/transfer_session.js and are covered
// by test/lib/p2p/transfer_session.test.js. This test covers only the wiring:
// server-driven methods and DOM in, pushEvents and channel sends out — driven
// through the controller's public surface, no LiveView.

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

describe("createFileTransferController", () => {
  let transfer;
  let el;
  let input;
  let pushed;

  const pushesOf = (name) => pushed.filter((p) => p.event === name).map((p) => p.payload);

  function setup() {
    el = document.createElement("div");
    el.id = "p2p-file-transfer";
    el.innerHTML = '<input type="file" class="file-transfer-input u-hidden" />';
    document.body.appendChild(el);

    pushed = [];
    transfer = createFileTransferController(el, {
      pushEvent: (event, payload) => pushed.push({ event, payload }),
    });
    transfer.mount();

    input = el.querySelector(".file-transfer-input");
  }

  beforeEach(() => setup());

  afterEach(() => {
    transfer.destroy();
    document.body.innerHTML = "";
  });

  describe("mount", () => {
    it("announces readiness", () => {
      expect(pushesOf("file_transfer_ready")).toEqual([{}]);
    });

    it("does not throw on a dragover", () => {
      expect(() => el.dispatchEvent(new Event("dragover"))).not.toThrow();
    });
  });

  describe("setupChannel", () => {
    it("wires the channel's onmessage", () => {
      const channel = mockChannel();
      transfer.setupChannel(channel);
      expect(channel.onmessage).toBeTypeOf("function");
    });
  });

  describe("file selection", () => {
    function ready(blocked = []) {
      transfer.setConfig({ max_size_mb: 500, blocked_extensions: blocked });
      transfer.setupChannel(mockChannel());
    }

    it("offers a valid file", async () => {
      ready([".exe"]);
      selectFile(input, new File(["hello"], "test.txt", { type: "text/plain" }));

      await vi.waitFor(() => {
        const offers = pushesOf("ft_offer_sent");
        expect(offers).toHaveLength(1);
        expect(offers[0].file_name).toBe("test.txt");
      });
    });

    it("rejects a blocked extension with the extension named", async () => {
      ready([".exe"]);
      selectFile(input, new File(["bad"], "virus.exe", { type: "application/octet-stream" }));

      await vi.waitFor(() => {
        const errors = pushesOf("ft_validation_error");
        expect(errors).toHaveLength(1);
        expect(errors[0].error).toContain(".exe");
      });
    });

    it("rejects any file before config has loaded", async () => {
      selectFile(input, new File(["hi"], "test.txt", { type: "text/plain" }));

      await vi.waitFor(() => {
        expect(pushesOf("ft_validation_error")).toHaveLength(1);
      });
    });

    it("queues a second file while the first is in flight", async () => {
      ready();
      selectFile(input, new File(["a"], "first.txt", { type: "text/plain" }));
      await vi.waitFor(() => expect(pushesOf("ft_offer_sent")).toHaveLength(1));

      selectFile(input, new File(["b"], "second.txt", { type: "text/plain" }));
      await vi.waitFor(() => {
        const queued = pushesOf("ft_queued");
        expect(queued).toHaveLength(1);
        expect(queued[0].file_name).toBe("second.txt");
      });
    });
  });

  describe("cancel", () => {
    it("cancels an in-flight transfer from a server ft_cancel event", async () => {
      const channel = mockChannel();
      transfer.setConfig({ max_size_mb: 500, blocked_extensions: [] });
      transfer.setupChannel(channel);
      selectFile(input, new File(["a"], "first.txt", { type: "text/plain" }));
      await vi.waitFor(() => expect(pushesOf("ft_offer_sent")).toHaveLength(1));

      channel._sent.length = 0; // ignore the offer already sent
      transfer.handleCancel("alice");

      const cancelled = pushesOf("ft_cancelled");
      expect(cancelled).toHaveLength(1);
      expect(cancelled[0].cancelled_by).toBe("alice");
      expect(channel._sent.length).toBe(1); // the cancel control message
    });
  });
});
