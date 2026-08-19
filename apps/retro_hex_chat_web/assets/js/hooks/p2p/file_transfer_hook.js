/**
 * LiveView Hook: FileTransferHook
 *
 * The transfer — the DataChannel, the session, file validation, the send loop,
 * chunk receive/assemble/verify, resume, cancel, progress and download — lives
 * in the framework-free controller `lib/p2p/file_transfer_controller.js`, which
 * a test can drive without LiveView. This file only binds that controller to the
 * LiveView: it forwards `pushEvent`, registers the server events, and relays
 * lifecycle callbacks.
 */
import { createFileTransferController } from "../../lib/p2p/file_transfer_controller.js";

const FileTransferHook = {
  mounted() {
    this.transfer = createFileTransferController(this.el, {
      pushEvent: (event, payload) => this.pushEvent(event, payload),
    });
    this.transfer.mount();

    this.handleEvent("ft_channel_ready", ({ channel }) => this.transfer.setupChannel(channel));
    this.handleEvent("ft_config", (config) => this.transfer.setConfig(config));
    this.handleEvent("ft_accept", () => this.transfer.handlePeerAccept());
    this.handleEvent("ft_reject", () => this.transfer.handlePeerReject());
    this.handleEvent("ft_cancel", ({ nickname }) => this.transfer.handleCancel(nickname));
    this.handleEvent("ft_retry", () => this.transfer.handleRetryRequest());
  },

  destroyed() {
    this.transfer.destroy();
  },
};

export default FileTransferHook;
