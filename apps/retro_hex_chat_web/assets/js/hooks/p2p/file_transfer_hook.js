/**
 * LiveView Hook: FileTransferHook
 *
 * Wires DOM events (file input, drag-and-drop, buttons) to the
 * file_transfer.js pure logic module and LiveView pushEvent calls.
 * MUST NOT contain transfer protocol logic.
 */
import {
  MSG,
  STATE,
  HIGH_WATER_MARK,
  LOW_WATER_MARK,
  PROGRESS_THROTTLE_MS,
  validateFile,
  computeHash,
  encodeControlMessage,
  encodeChunk,
  decodeMessage,
  encodeHaveChunks,
  decodeHaveChunks,
  createSenderSession,
  createReceiverSession,
  getNextChunk,
  receiveChunk,
  assembleFile,
  cleanupSession,
  calculateProgress,
  recordSpeedSample,
  formatFileSize,
  formatSpeed,
  formatEta,
  markChunksReceived,
  isTransferActive,
  createQueueEntry,
} from "../../lib/p2p/file_transfer.js";

const FileTransferHook = {
  mounted() {
    this._channel = null;
    this._session = null;
    this._config = null;
    this._queue = [];
    this._sending = false;
    this._progressTimer = null;
    this._objectUrl = null;

    // Register server-pushed events
    this.handleEvent("ft_channel_ready", ({ channel }) => {
      this._setupChannel(channel);
    });

    this.handleEvent("ft_config", (config) => {
      this._config = {
        maxSizeBytes: config.max_size_mb * 1024 * 1024,
        blockedExtensions: config.blocked_extensions || [],
      };
    });

    this.handleEvent("ft_accept", () => {
      this._handlePeerAccept();
    });

    this.handleEvent("ft_reject", () => {
      this._handlePeerReject();
    });

    this.handleEvent("ft_cancel", ({ nickname }) => {
      this._handleCancel(nickname);
    });

    this.handleEvent("ft_retry", () => {
      this._handleRetryRequest();
    });

    // Set up drag-and-drop on the hook element
    this.el.addEventListener("dragover", (e) => {
      e.preventDefault();
      this.el.classList.add("file-transfer-drop-zone--active");
    });

    this.el.addEventListener("dragleave", () => {
      this.el.classList.remove("file-transfer-drop-zone--active");
    });

    this.el.addEventListener("drop", (e) => {
      e.preventDefault();
      this.el.classList.remove("file-transfer-drop-zone--active");
      if (e.dataTransfer && e.dataTransfer.files.length > 0) {
        this._enqueueOrSend(e.dataTransfer.files[0]);
      }
    });

    // Listen for file input changes
    const fileInput = this.el.querySelector(".file-transfer-input");
    if (fileInput) {
      fileInput.addEventListener("change", (e) => {
        if (e.target.files && e.target.files.length > 0) {
          this._enqueueOrSend(e.target.files[0]);
          e.target.value = "";
        }
      });
    }

    // Listen for DataChannel events from WebRTCHook (via CustomEvent)
    const webrtcEl = document.getElementById("p2p-webrtc");
    if (webrtcEl) {
      webrtcEl.addEventListener("ft_channel_ready", (e) => {
        this._setupChannel(e.detail.channel);
      });
      webrtcEl.addEventListener("ft_channel_closed", () => {
        this._handleChannelClose();
      });

      // Check for already-open channel (hook mounted after DataChannel opened)
      if (webrtcEl._fileTransferChannel && webrtcEl._fileTransferChannel.readyState === "open") {
        this._setupChannel(webrtcEl._fileTransferChannel);
      }
    }
  },

  destroyed() {
    this._stopProgressUpdates();
    if (this._objectUrl) {
      URL.revokeObjectURL(this._objectUrl);
      this._objectUrl = null;
    }
    if (this._session) {
      cleanupSession(this._session);
      this._session = null;
    }
    this._channel = null;
    this._queue = [];
  },

  // --- Channel Setup ---

  _setupChannel(channel) {
    this._channel = channel;
    channel.binaryType = "arraybuffer";

    channel.onmessage = (event) => {
      this._handleChannelMessage(event.data);
    };

    channel.onbufferedamountlow = () => {
      if (this._sending === false && this._session && this._session.state === STATE.TRANSFERRING) {
        this._resumeSending();
      }
    };

    if (channel.bufferedAmountLowThreshold !== undefined) {
      channel.bufferedAmountLowThreshold = LOW_WATER_MARK;
    }

    // If we have a pending file to send (action was accepted), send the offer now
    if (
      this._session &&
      this._session.state === STATE.OFFERING &&
      this._session.role === "sender"
    ) {
      this._sendFileOffer();
    }

    // If we were paused (resume), send have-chunks
    if (
      this._session &&
      this._session.state === STATE.PAUSED &&
      this._session.role === "receiver"
    ) {
      this._sendHaveChunks();
    }
  },

  // --- File Selection & Validation ---

  _enqueueOrSend(file) {
    if (isTransferActive(this._session)) {
      this._queue.push(createQueueEntry(file));
      this.pushEvent("ft_queued", { fileName: file.name });
      return;
    }
    this._handleFileSelected(file);
  },

  async _handleFileSelected(file) {
    if (!this._config) {
      this.pushEvent("ft_validation_error", {
        error: "Aguarde a configuracao carregar e tente novamente.",
      });
      return;
    }

    const result = validateFile(file, this._config);
    if (!result.valid) {
      this.pushEvent("ft_validation_error", { error: result.error });
      return;
    }

    // Compute hash before offering
    const buffer = await readFileAsArrayBuffer(file);
    const sha256 = await computeHash(buffer);

    this._session = createSenderSession(file, sha256);

    this.pushEvent("ft_offer_sent", {
      fileName: file.name,
      fileSize: file.size,
      formattedSize: formatFileSize(file.size),
    });

    // If channel is already open, send offer immediately
    if (this._channel && this._channel.readyState === "open") {
      this._sendFileOffer();
    }
    // Otherwise, will send when ft_channel_ready fires
  },

  _sendFileOffer() {
    if (!this._session || !this._channel) return;

    const offer = encodeControlMessage(MSG.FILE_OFFER, {
      transferId: this._session.transferId,
      fileName: this._session.fileName,
      fileSize: this._session.fileSize,
      mimeType: this._session.mimeType,
      totalChunks: this._session.totalChunks,
      sha256: this._session.expectedHash,
    });

    this._channel.send(offer);
  },

  // --- DataChannel Message Handling ---

  _handleChannelMessage(data) {
    const msg = decodeMessage(data);

    switch (msg.type) {
      case MSG.FILE_OFFER:
        this._handleIncomingOffer(msg.payload);
        break;
      case MSG.FILE_ACCEPT:
        this._handlePeerAccept();
        break;
      case MSG.FILE_REJECT:
        this._handlePeerReject();
        break;
      case MSG.CHUNK:
        this._handleIncomingChunk(msg.chunkIndex, msg.payload);
        break;
      case MSG.CANCEL:
        this._handleIncomingCancel(msg.payload);
        break;
      case MSG.HAVE_CHUNKS:
        this._handleIncomingHaveChunks(data);
        break;
      case MSG.TRANSFER_DONE:
        this._handleTransferDone();
        break;
      case MSG.HASH_RESULT:
        this._handleIncomingHashResult(msg.payload);
        break;
      case MSG.RETRY:
        this._handleIncomingRetry();
        break;
    }
  },

  // --- Receiver: Incoming Offer ---

  _handleIncomingOffer(offer) {
    this._session = createReceiverSession(offer);
    this.pushEvent("ft_offer_received", {
      fileName: offer.fileName,
      fileSize: offer.fileSize,
      formattedSize: formatFileSize(offer.fileSize),
      transferId: offer.transferId,
    });
  },

  // --- Sender: Peer Accepted ---

  _handlePeerAccept() {
    if (!this._session || this._session.role !== "sender") {
      // Receiver side — send file-accept via DataChannel
      if (this._session && this._session.role === "receiver" && this._channel) {
        this._channel.send(
          encodeControlMessage(MSG.FILE_ACCEPT, { transferId: this._session.transferId }),
        );
        this._session.startTime = Date.now();
        this._startProgressUpdates();
        this.pushEvent("ft_accepted", {});
      }
      return;
    }

    this._session.state = STATE.TRANSFERRING;
    this._session.startTime = Date.now();
    this._startProgressUpdates();
    this.pushEvent("ft_accepted", {});
    this._startSending();
  },

  // --- Sender: Peer Rejected ---

  _handlePeerReject() {
    if (this._session && this._session.role === "sender") {
      this._session.state = STATE.REJECTED;
      this.pushEvent("ft_rejected", {});
      cleanupSession(this._session);
      this._session = null;
    } else if (this._session && this._session.role === "receiver" && this._channel) {
      this._channel.send(
        encodeControlMessage(MSG.FILE_REJECT, { transferId: this._session.transferId }),
      );
      this.pushEvent("ft_rejected", {});
      cleanupSession(this._session);
      this._session = null;
    }
    this._processQueue();
  },

  // --- Sender: Chunk Sending Loop ---

  async _startSending() {
    if (!this._session || !this._channel) return;
    this._sending = true;

    while (this._session && this._session.state === STATE.TRANSFERRING) {
      // Backpressure check
      if (this._channel.bufferedAmount >= HIGH_WATER_MARK) {
        this._sending = false;
        return; // Will be resumed by onbufferedamountlow
      }

      const chunk = await getNextChunk(this._session);
      if (!chunk) {
        // All chunks sent
        this._channel.send(
          encodeControlMessage(MSG.TRANSFER_DONE, {
            transferId: this._session.transferId,
          }),
        );
        this._session.state = STATE.VERIFYING;
        this._sending = false;
        return;
      }

      const encoded = encodeChunk(chunk.index, chunk.data);
      this._channel.send(encoded);

      recordSpeedSample(this._session, this._session.bytesSent, Date.now());
    }

    this._sending = false;
  },

  _resumeSending() {
    this._startSending();
  },

  // --- Receiver: Incoming Chunk ---

  _handleIncomingChunk(chunkIndex, data) {
    if (!this._session || this._session.role !== "receiver") return;

    receiveChunk(this._session, chunkIndex, data);
    recordSpeedSample(this._session, this._session.bytesReceived, Date.now());
  },

  // --- Receiver: Transfer Done ---

  async _handleTransferDone() {
    if (!this._session || this._session.role !== "receiver") return;

    this._session.state = STATE.VERIFYING;
    this._stopProgressUpdates();
    this.pushEvent("ft_progress", { percent: 100, speed: "0 B/s", eta: "0s" });

    const blob = assembleFile(this._session);
    const buffer = await blob.arrayBuffer();
    const hash = await computeHash(buffer);
    const match = hash === this._session.expectedHash;

    // Send hash result to sender
    this._channel.send(
      encodeControlMessage(MSG.HASH_RESULT, {
        transferId: this._session.transferId,
        match,
      }),
    );

    if (match) {
      this._handleHashResult(true, blob);
    } else {
      this._handleHashResult(false);
    }
  },

  _handleHashResult(match, blob) {
    if (match && blob) {
      this._session.state = STATE.COMPLETED;
      this._triggerDownload(blob, this._session.fileName);
      this.pushEvent("ft_completed", { fileName: this._session.fileName });
      cleanupSession(this._session);
      this._session = null;
      this._processQueue();
    } else {
      this._session.state = STATE.FAILED;
      this.pushEvent("ft_failed", {
        reason: "Verificacao de integridade falhou",
      });
    }
  },

  // --- Sender: Incoming Hash Result ---

  _handleIncomingHashResult(payload) {
    if (!this._session || this._session.role !== "sender") return;

    this._stopProgressUpdates();

    if (payload.match) {
      this._session.state = STATE.COMPLETED;
      this.pushEvent("ft_completed", { fileName: this._session.fileName });
      cleanupSession(this._session);
      this._session = null;
      this._processQueue();
    } else {
      this._session.state = STATE.FAILED;
      this.pushEvent("ft_failed", {
        reason: "Verificacao de integridade falhou",
      });
    }
  },

  // --- Cancel (T032) ---

  _handleCancel(nickname) {
    if (!this._session) return;

    if (this._channel && this._channel.readyState === "open") {
      this._channel.send(
        encodeControlMessage(MSG.CANCEL, {
          transferId: this._session.transferId,
          cancelledBy: nickname,
        }),
      );
    }

    this._session.state = STATE.CANCELLED;
    this._stopProgressUpdates();
    this.pushEvent("ft_cancelled", { cancelledBy: nickname });
    cleanupSession(this._session);
    this._session = null;
    this._processQueue();
  },

  _handleIncomingCancel(payload) {
    if (!this._session) return;

    this._session.state = STATE.CANCELLED;
    this._stopProgressUpdates();
    this.pushEvent("ft_cancelled", { cancelledBy: payload.cancelledBy });
    cleanupSession(this._session);
    this._session = null;
    this._processQueue();
  },

  // --- Resume (T037) ---

  _handleChannelClose() {
    if (
      this._session &&
      (this._session.state === STATE.TRANSFERRING || this._session.state === STATE.OFFERING)
    ) {
      this._session.state = STATE.PAUSED;
      this._sending = false;
      this._stopProgressUpdates();
      this.pushEvent("ft_paused", {});
    }
  },

  _sendHaveChunks() {
    if (!this._session || !this._channel) return;

    // Encode have-chunks (without type byte — we prepend it)
    const payload = encodeHaveChunks(this._session.transferId, this._session.receivedSet);
    const msg = new ArrayBuffer(1 + payload.byteLength);
    new Uint8Array(msg)[0] = MSG.HAVE_CHUNKS;
    new Uint8Array(msg, 1).set(new Uint8Array(payload));

    this._channel.send(msg);
    this._session.state = STATE.TRANSFERRING;
    this._startProgressUpdates();
    this.pushEvent("ft_resumed", {});
  },

  _handleIncomingHaveChunks(rawData) {
    if (!this._session || this._session.role !== "sender") return;

    // Strip the type byte
    const payload = rawData.slice(1);
    const { indices } = decodeHaveChunks(payload);

    markChunksReceived(this._session, indices);
    this._session.state = STATE.TRANSFERRING;
    this._session.nextChunkIndex = 0; // Reset to scan from beginning
    this._startProgressUpdates();
    this.pushEvent("ft_resumed", {});
    this._startSending();
  },

  // --- Retry (T042) ---

  _handleRetryRequest() {
    if (!this._session || this._session.role !== "sender") return;

    // Reset session for full re-transfer
    this._session.sentSet = new Set();
    this._session.nextChunkIndex = 0;
    this._session.bytesSent = 0;
    this._session.speedSamples = [];
    this._session.state = STATE.TRANSFERRING;
    this._session.startTime = Date.now();

    if (this._channel && this._channel.readyState === "open") {
      this._channel.send(encodeControlMessage(MSG.RETRY, { transferId: this._session.transferId }));
    }

    this._startProgressUpdates();
    this._startSending();
  },

  _handleIncomingRetry() {
    if (!this._session || this._session.role !== "receiver") return;

    // Reset receiver session
    this._session.chunks = new Array(this._session.totalChunks).fill(null);
    this._session.receivedSet = new Set();
    this._session.bytesReceived = 0;
    this._session.speedSamples = [];
    this._session.state = STATE.TRANSFERRING;
    this._session.startTime = Date.now();
    this._startProgressUpdates();
    this.pushEvent("ft_progress", { percent: 0, speed: "0 B/s", eta: "--" });
  },

  // --- Progress Updates ---

  _startProgressUpdates() {
    this._stopProgressUpdates();
    this._progressTimer = setInterval(() => {
      if (!this._session) return;
      const progress = calculateProgress(this._session);
      const percent = progress.percent;
      const speed = formatSpeed(progress.speedBps);
      const eta = formatEta(progress.etaSeconds);

      this.pushEvent("ft_progress", { percent, speed, eta });
    }, PROGRESS_THROTTLE_MS);
  },

  _stopProgressUpdates() {
    if (this._progressTimer) {
      clearInterval(this._progressTimer);
      this._progressTimer = null;
    }
  },

  // --- Download ---

  _triggerDownload(blob, fileName) {
    if (this._objectUrl) {
      URL.revokeObjectURL(this._objectUrl);
    }
    this._objectUrl = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = this._objectUrl;
    a.download = fileName;
    a.className = "u-hidden";
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
  },

  // --- Queue (T047) ---

  _processQueue() {
    if (this._queue.length > 0 && !isTransferActive(this._session)) {
      const entry = this._queue.shift();
      this._handleFileSelected(entry.file);
    }
  },
};

function readFileAsArrayBuffer(file) {
  if (file.arrayBuffer) return file.arrayBuffer();
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result);
    reader.onerror = () => reject(reader.error);
    reader.readAsArrayBuffer(file);
  });
}

export default FileTransferHook;
