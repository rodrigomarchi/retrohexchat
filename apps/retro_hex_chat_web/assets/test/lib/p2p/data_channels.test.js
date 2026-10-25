import { describe, it, expect, vi } from "vitest";
import {
  DATA_CHANNELS,
  dataChannelSpec,
  subscribeDataChannel,
} from "../../../js/lib/p2p/data_channels.js";

const open = (label) => ({ label, readyState: "open" });

describe("DATA_CHANNELS", () => {
  it("gives every channel a label, element key, events and stats key of its own", () => {
    for (const field of [
      "label",
      "property",
      "elementKey",
      "readyEvent",
      "closedEvent",
      "statsKey",
    ]) {
      const values = DATA_CHANNELS.map((spec) => spec[field]);
      expect(new Set(values).size, field).toBe(values.length);
    }
  });

  it("finds a spec by label, and nothing for a label it does not list", () => {
    expect(dataChannelSpec("gamedata").options.ordered).toBe(false);
    expect(dataChannelSpec("whiteboard")).toBeUndefined();
  });
});

describe("subscribeDataChannel", () => {
  it("hands over a channel that opened before the subscriber mounted", () => {
    const el = document.createElement("div");
    const channel = open("filetransfer");
    el._fileTransferChannel = channel;
    const onOpen = vi.fn();

    subscribeDataChannel(el, "filetransfer", { onOpen });

    expect(onOpen).toHaveBeenCalledWith(channel);
  });

  it("follows the channel's open and close events until unsubscribed", () => {
    const el = document.createElement("div");
    const onOpen = vi.fn();
    const onClose = vi.fn();
    const channel = open("gamedata");

    const unsubscribe = subscribeDataChannel(el, "gamedata", { onOpen, onClose });
    el.dispatchEvent(new CustomEvent("game_channel_ready", { detail: { channel } }));
    el.dispatchEvent(new CustomEvent("game_channel_closed", { detail: { channel: null } }));

    expect(onOpen).toHaveBeenCalledWith(channel);
    expect(onClose).toHaveBeenCalledTimes(1);

    unsubscribe();
    el.dispatchEvent(new CustomEvent("game_channel_ready", { detail: { channel } }));
    expect(onOpen).toHaveBeenCalledTimes(1);
  });

  it("refuses a label no entry declares", () => {
    expect(() =>
      subscribeDataChannel(document.createElement("div"), "whiteboard", { onOpen: () => {} }),
    ).toThrow(/unknown data channel/);
  });

  it("is a no-op without the connection's element", () => {
    const unsubscribe = subscribeDataChannel(null, "gamedata", { onOpen: vi.fn() });
    expect(() => unsubscribe()).not.toThrow();
  });
});
