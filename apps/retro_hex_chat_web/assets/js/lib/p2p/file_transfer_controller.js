/**
 * File-transfer controller (framework-free).
 *
 * Owns the file-transfer DataChannel and the transfer session: file selection
 * and validation, the offer/accept handshake, the backpressure-aware send loop,
 * chunk receive/assemble/verify, resume, cancel, progress timers and the browser
 * download. Protocol transitions live in the pure reducer (`transfer_session.js`)
 * and the framing/hash/backpressure rules in `file_transfer.js`; this owns the
 * I/O. It knows nothing about LiveView: `createFileTransferController(el, ports)`
 * takes the hook element and a `{ pushEvent }` port, and a test drives it through
 * its public surface (mount/destroy, setConfig, setupChannel, the peer/cancel/
 * retry methods and the DOM events on `el`) without a LiveSocket.
 * `hooks/p2p/file_transfer_hook.js` is the thin binding that registers the
 * LiveView events onto it.
 */
import { log } from "../logger.js";
import {
  MSG,
  STATE,
  LOW_WATER_MARK,
  PROGRESS_THROTTLE_MS,
  validateFile,
  computeHash,
  encodeControlMessage,
  encodeChunk,
  decodeMessage,
  frameHaveChunks,
  unframeHaveChunks,
  isBackpressured,
  hashMatches,
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
  isTransferActive,
  createQueueEntry,
} from "./file_transfer.js";
import { EFFECT, step } from "./transfer_session.js";
import { t } from "../i18n.js";

export function createFileTransferController(el, ports) {
  return {
    mount() {
      this._channel = null;
      this._session = null;
      this._config = configFromDataset(el);
      this._queue = [];
      this._sending = false;
      this._progressTimer = null;
      this._objectUrl = null;

      // Set up drag-and-drop on the hook element
      el.addEventListener("dragover", (e) => {
        e.preventDefault();
        el.classList.add("file-transfer-drop-zone--active");
      });

      el.addEventListener("dragleave", () => {
        el.classList.remove("file-transfer-drop-zone--active");
      });

      el.addEventListener("drop", (e) => {
        e.preventDefault();
        el.classList.remove("file-transfer-drop-zone--active");
        if (e.dataTransfer && e.dataTransfer.files.length > 0) {
          this._enqueueOrSend(e.dataTransfer.files[0]);
        }
      });

      // Listen for file input changes
      const fileInput = el.querySelector(".file-transfer-input");
      if (fileInput) {
        fileInput.addEventListener("change", (e) => {
          if (e.target.files && e.target.files.length > 0) {
            this._enqueueOrSend(e.target.files[0]);
            e.target.value = "";
          }
        });
      }

      // Listen for DataChannel events from the WebRTC hook (via CustomEvent).
      // Defaults to the dedicated P2P session element, but the P2P session
      // points this at its own shared connection via `data-webrtc-id`.
      const webrtcId = el.dataset.webrtcId || "p2p-webrtc";
      const webrtcEl = document.getElementById(webrtcId);
      if (webrtcEl) {
        webrtcEl.addEventListener("ft_channel_ready", (e) => {
          this.setupChannel(e.detail.channel);
        });
        webrtcEl.addEventListener("ft_channel_closed", () => {
          this._handleChannelClose();
        });

        // Check for already-open channel (hook mounted after DataChannel opened)
        if (webrtcEl._fileTransferChannel && webrtcEl._fileTransferChannel.readyState === "open") {
          this.setupChannel(webrtcEl._fileTransferChannel);
        }
      }

      ports.pushEvent("file_transfer_ready", {});
    },

    destroy() {
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

    // --- Server-driven configuration ---

    setConfig(config) {
      this._config = {
        maxSizeBytes: config.max_size_mb * 1024 * 1024,
        blockedExtensions: config.blocked_extensions || [],
      };
    },

    // --- Channel Setup ---

    setupChannel(channel) {
      this._channel = channel;
      channel.binaryType = "arraybuffer";

      channel.onmessage = (event) => {
        this._handleChannelMessage(event.data);
      };

      channel.onbufferedamountlow = () => {
        if (
          this._sending === false &&
          this._session &&
          this._session.state === STATE.TRANSFERRING
        ) {
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
        ports.pushEvent("ft_queued", { file_name: file.name });
        return;
      }
      this._handleFileSelected(file);
    },

    async _handleFileSelected(file) {
      if (!this._config) {
        ports.pushEvent("ft_validation_error", {
          error: t("Wait for configuration to load and try again."),
        });
        return;
      }

      const result = validateFile(file, this._config);
      if (!result.valid) {
        ports.pushEvent("ft_validation_error", { error: result.error });
        return;
      }

      // Compute hash before offering
      let sha256;
      try {
        const buffer = await readFileAsArrayBuffer(file);
        sha256 = await computeHash(buffer);
      } catch (error) {
        log.error("[P2P] file read/hash failed", error);
        ports.pushEvent("ft_validation_error", {
          error: t("Could not read the selected file. Please try another file."),
        });
        return;
      }

      this._session = createSenderSession(file, sha256);

      ports.pushEvent("ft_offer_sent", {
        file_name: file.name,
        file_size: file.size,
        formatted_size: formatFileSize(file.size),
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

    _failTransfer(reason, error) {
      if (error) log.error("[P2P] file transfer error", error);
      ports.pushEvent("ft_failed", { reason });
    },

    _handleChannelMessage(data) {
      let msg;
      try {
        msg = decodeMessage(data);
      } catch (error) {
        this._failTransfer(t("Received malformed data from the peer."), error);
        return;
      }

      switch (msg.type) {
        case MSG.FILE_OFFER:
          this._handleIncomingOffer(msg.payload);
          break;
        case MSG.FILE_ACCEPT:
          this.handlePeerAccept();
          break;
        case MSG.FILE_REJECT:
          this.handlePeerReject();
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
      ports.pushEvent("ft_offer_received", {
        file_name: offer.fileName,
        file_size: offer.fileSize,
        formatted_size: formatFileSize(offer.fileSize),
        transferId: offer.transferId,
      });
    },

    // --- Sender: Peer Accepted ---

    handlePeerAccept() {
      this._applyStep({ type: "peer_accept" });
    },

    // --- Sender: Peer Rejected ---

    handlePeerReject() {
      this._applyStep({ type: "peer_reject" });
    },

    // --- Sender: Chunk Sending Loop ---

    async _startSending() {
      if (!this._session || !this._channel) return;
      this._sending = true;

      try {
        while (this._session && this._session.state === STATE.TRANSFERRING) {
          // Backpressure check
          if (isBackpressured(this._channel.bufferedAmount)) {
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
      } catch (error) {
        this._sending = false;
        this._failTransfer(t("Error reading the file while sending."), error);
        return;
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
      ports.pushEvent("ft_progress", { percent: 100, speed: "0 B/s", eta: "0s" });

      let blob;
      let hash;
      try {
        blob = assembleFile(this._session);
        const buffer = await blob.arrayBuffer();
        hash = await computeHash(buffer);
      } catch (error) {
        this._failTransfer(t("Could not verify the received file."), error);
        return;
      }
      const match = hashMatches(hash, this._session.expectedHash);

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
      this._applyStep({ type: "receiver_hash_result", match, blob });
    },

    // --- Sender: Incoming Hash Result ---

    _handleIncomingHashResult(payload) {
      this._applyStep({ type: "sender_hash_result", match: payload.match });
    },

    // --- Cancel (T032) ---

    handleCancel(nickname) {
      this._applyStep({ type: "local_cancel", nickname });
    },

    _handleIncomingCancel(payload) {
      this._applyStep({ type: "incoming_cancel", cancelledBy: payload.cancelledBy });
    },

    // --- Resume (T037) ---

    _handleChannelClose() {
      this._applyStep({ type: "channel_close" });
      if (this._session?.state === STATE.PAUSED) this._sending = false;
    },

    _sendHaveChunks() {
      if (!this._session || !this._channel) return;

      this._channel.send(frameHaveChunks(this._session.transferId, this._session.receivedSet));
      this._session.state = STATE.TRANSFERRING;
      this._startProgressUpdates();
      ports.pushEvent("ft_resumed", {});
    },

    _handleIncomingHaveChunks(rawData) {
      if (!this._session || this._session.role !== "sender") return;

      const { indices } = unframeHaveChunks(rawData);
      this._applyStep({ type: "incoming_have_chunks", indices });
    },

    // --- Retry (T042) ---

    handleRetryRequest() {
      this._applyStep({ type: "retry_request" });
    },

    _handleIncomingRetry() {
      this._applyStep({ type: "incoming_retry" });
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

        ports.pushEvent("ft_progress", { percent, speed, eta });
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

    // --- Reducer plumbing ---

    // Run one protocol event through the pure reducer and execute the effects it
    // returns. The reducer owns the transition; the hook owns the I/O.
    _applyStep(event) {
      const { session, effects } = step(this._session, event);
      this._session = session;
      this._applyEffects(effects);
    },

    _applyEffects(effects) {
      for (const eff of effects) {
        switch (eff.type) {
          case EFFECT.SEND_CONTROL: {
            const ready = this._channel && this._channel.readyState === "open";
            if (eff.requireOpen ? ready : this._channel) {
              this._channel.send(encodeControlMessage(eff.code, eff.payload));
            }
            break;
          }
          case EFFECT.PUSH:
            ports.pushEvent(eff.event, eff.payload);
            break;
          case EFFECT.START_PROGRESS:
            this._startProgressUpdates();
            break;
          case EFFECT.STOP_PROGRESS:
            this._stopProgressUpdates();
            break;
          case EFFECT.START_SENDING:
            this._startSending();
            break;
          case EFFECT.PROCESS_QUEUE:
            this._processQueue();
            break;
          case EFFECT.DOWNLOAD:
            this._triggerDownload(eff.blob, eff.fileName);
            break;
        }
      }
    },

    // --- Queue (T047) ---

    _processQueue() {
      if (this._queue.length > 0 && !isTransferActive(this._session)) {
        const entry = this._queue.shift();
        this._handleFileSelected(entry.file);
      }
    },
  };
}

function readFileAsArrayBuffer(file) {
  if (file.arrayBuffer) return file.arrayBuffer();
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result);
    reader.onerror = () => reject(reader.error);
    reader.readAsArrayBuffer(file);
  });
}

function configFromDataset(el) {
  const maxSizeMb = Number(el.dataset.maxSizeMb);

  if (!Number.isFinite(maxSizeMb) || maxSizeMb <= 0) {
    return null;
  }

  return {
    maxSizeBytes: maxSizeMb * 1024 * 1024,
    blockedExtensions: (el.dataset.blockedExtensions || "")
      .split(",")
      .map((extension) => extension.trim())
      .filter(Boolean),
  };
}
