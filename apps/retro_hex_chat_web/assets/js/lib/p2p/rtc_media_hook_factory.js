/**
 * Configurable LiveView hook for RTC audio/video media.
 *
 * The hook owns media capture and DOM attachment, but it does not own signaling.
 * Signaling remains on the WebRTC hook that provides the RTCPeerConnection.
 */
import {
  acquireMedia,
  getAudioConstraints,
  getVideoConstraints,
  addMediaTracks,
  removeMediaTracks,
  toggleTrack,
  stopAllTracks,
  formatDuration,
  getQualitySnapshot,
  mapQualityLevel,
  applyBitratePreset,
  setCodecPreferences,
  enumerateDevices,
  switchAudioInput,
  switchVideoInput,
  setSinkId,
  supportsSetSinkId,
  supportsPiP,
  togglePiP,
  QUALITY_LABELS,
} from "./media.js";
import { t } from "../i18n.js";

const noopEvent = null;

function normalizeConfig(config) {
  return {
    webrtcElementId: config.webrtcElementId,
    pcReadyEvent: config.pcReadyEvent,
    pcClosedEvent: config.pcClosedEvent,
    actionAttribute: config.actionAttribute || "data-media-action",
    deviceKindAttribute: config.deviceKindAttribute || "data-device-kind",
    upgradeMode: config.upgradeMode || "request",
    elementIds: {
      remoteVideo: config.elementIds?.remoteVideo,
      localVideo: config.elementIds?.localVideo,
      remoteAudio: config.elementIds?.remoteAudio,
    },
    serverEvents: {
      startAudio: config.serverEvents?.startAudio,
      startVideo: config.serverEvents?.startVideo,
      endCall: config.serverEvents?.endCall,
      peerMuted: config.serverEvents?.peerMuted,
      peerCamera: config.serverEvents?.peerCamera,
      upgradeAccepted: config.serverEvents?.upgradeAccepted,
      upgradeRejected: config.serverEvents?.upgradeRejected,
      upgradeFailed: config.serverEvents?.upgradeFailed,
      setPreset: config.serverEvents?.setPreset,
    },
    clientEvents: {
      ready: config.clientEvents?.ready,
      error: config.clientEvents?.error,
      callStarted: config.clientEvents?.callStarted,
      callEnded: config.clientEvents?.callEnded,
      muteChanged: config.clientEvents?.muteChanged,
      cameraChanged: config.clientEvents?.cameraChanged,
      qualityUpdate: config.clientEvents?.qualityUpdate,
      durationTick: config.clientEvents?.durationTick,
      requestUpgrade: config.clientEvents?.requestUpgrade,
      devicesListed: config.clientEvents?.devicesListed,
      deviceFallback: config.clientEvents?.deviceFallback,
    },
  };
}

function selectorForId(id) {
  return id ? `#${id}` : null;
}

export function createRtcMediaHook(configInput) {
  const config = normalizeConfig(configInput);

  return {
    mounted() {
      this.pc = null;
      this.localStream = null;
      this.remoteStream = null;
      this.remoteHasVideo = false;
      this.senders = [];
      this.callType = null;
      this.startingCall = false;
      this.startTime = null;
      this.durationInterval = null;
      this.qualityInterval = null;
      this.muted = false;
      this.cameraOff = false;
      this.upgradeInProgress = false;
      this.upgradeCancelled = false;

      this._onPcReady = (event) => this._handlePcReady(event.detail.pc);
      this._onPcClosed = () => this._handlePcClosed();
      this._webrtcEl = document.getElementById(config.webrtcElementId);

      if (this._webrtcEl) {
        this._webrtcEl.addEventListener(config.pcReadyEvent, this._onPcReady);
        this._webrtcEl.addEventListener(config.pcClosedEvent, this._onPcClosed);

        if (this._webrtcEl._peerConnection) {
          this._handlePcReady(this._webrtcEl._peerConnection);
        }
      }

      this._handleServerEvent(config.serverEvents.startAudio, () => this._startCall("audio"));
      this._handleServerEvent(config.serverEvents.startVideo, () => this._startCall("video"));
      this._handleServerEvent(config.serverEvents.endCall, (payload = {}) =>
        this._endCall(payload.reason || "ended", { notify: payload.notify === true }),
      );
      this._handleServerEvent(config.serverEvents.peerMuted, ({ muted }) =>
        this._handlePeerMuted(muted),
      );
      this._handleServerEvent(config.serverEvents.peerCamera, ({ off }) =>
        this._handlePeerCamera(off),
      );
      this._handleServerEvent(config.serverEvents.upgradeAccepted, () =>
        this._handleUpgradeAccepted(),
      );
      this._handleServerEvent(config.serverEvents.upgradeRejected, () =>
        this._handleUpgradeRejected(),
      );
      this._handleServerEvent(config.serverEvents.upgradeFailed, () => this._handleUpgradeFailed());
      this._handleServerEvent(config.serverEvents.setPreset, ({ preset }) =>
        this._handleSetPreset(preset),
      );

      this._wireControls();
      this._push(config.clientEvents.ready, {});
    },

    updated() {
      this._attachMediaElements();
    },

    destroyed() {
      this._cleanup();

      if (this._webrtcEl) {
        this._webrtcEl.removeEventListener(config.pcReadyEvent, this._onPcReady);
        this._webrtcEl.removeEventListener(config.pcClosedEvent, this._onPcClosed);
      }
    },

    _handleServerEvent(eventName, handler) {
      if (eventName && eventName !== noopEvent) {
        this.handleEvent(eventName, handler);
      }
    },

    _push(eventName, payload) {
      if (eventName && eventName !== noopEvent) {
        this.pushEvent(eventName, payload);
      }
    },

    _query(id) {
      const selector = selectorForId(id);
      return selector ? this.el.querySelector(selector) : null;
    },

    // --- PeerConnection lifecycle ---

    _handlePcReady(pc) {
      this.pc = pc;
      this.pc.ontrack = (event) => this._handleRemoteTrack(event);
      this._attachMediaElements();
    },

    _handlePcClosed() {
      if (this.callType || this.localStream || this.remoteStream) {
        this._endCall(t("Peer disconnected"));
      }
    },

    // --- Call start/end ---

    async _startCall(type) {
      if (!this.pc || this.callType || this.startingCall) return;
      this.startingCall = true;

      const constraints = { audio: getAudioConstraints() };
      if (type === "video") {
        constraints.video = getVideoConstraints();
      }

      try {
        this.localStream = await acquireMedia(constraints);
      } catch (error) {
        this.startingCall = false;
        this._push(config.clientEvents.error, error);
        return;
      }

      this.senders = addMediaTracks(this.pc, this.localStream);
      setCodecPreferences(this.pc);

      this.callType = type;
      this.startTime = Date.now();
      this.muted = false;
      this.cameraOff = false;

      this._attachMediaElements();
      this._startDurationTimer();
      this._startQualityPolling();
      this._setupDeviceChangeListener();

      this._push(config.clientEvents.callStarted, { type });
      this.startingCall = false;
    },

    _endCall(reason, opts = {}) {
      const notify = opts.notify !== false;

      this._stopTimers();

      if (this.localStream) {
        stopAllTracks(this.localStream);
        this.localStream = null;
      }

      if (this.pc && this.senders.length > 0) {
        removeMediaTracks(this.pc, this.senders);
        this.senders = [];
      }

      this.remoteStream = null;
      this._clearMediaElements();

      if (document.pictureInPictureElement) {
        document.exitPictureInPicture().catch(() => {});
      }

      this.callType = null;
      this.startTime = null;

      if (notify) {
        this._push(config.clientEvents.callEnded, { reason });
      }
    },

    _clearMediaElements() {
      const remoteVideo = this._query(config.elementIds.remoteVideo);
      const localVideo = this._query(config.elementIds.localVideo);
      const remoteAudio = this._query(config.elementIds.remoteAudio);

      if (remoteVideo) remoteVideo.srcObject = null;
      if (localVideo) localVideo.srcObject = null;
      if (remoteAudio) remoteAudio.srcObject = null;
    },

    _attachMediaElements() {
      if (this.localStream) {
        const localVideo = this._query(config.elementIds.localVideo);
        this._setSrcObject(localVideo, this.localStream);
      }

      if (this.remoteStream) {
        const remoteVideo = this._query(config.elementIds.remoteVideo);
        const remoteAudio = this._query(config.elementIds.remoteAudio);

        if (
          remoteVideo &&
          (this.remoteHasVideo || this.remoteStream.getVideoTracks?.().length > 0)
        ) {
          this._setSrcObject(remoteVideo, this.remoteStream);
        }

        this._setSrcObject(remoteAudio, this.remoteStream);
      }
    },

    // Assign a stream only when it actually changed. updated() runs on every
    // LiveView patch to #media-call (e.g. the 1s duration tick), and reassigning
    // the same MediaStream tears down and rebuilds the media pipeline, which the
    // user sees as a constant video flicker.
    _setSrcObject(el, stream) {
      if (el && el.srcObject !== stream) {
        el.srcObject = stream;
      }
    },

    // --- Remote track handling ---

    _handleRemoteTrack(event) {
      const [stream] = event.streams;
      if (!stream) return;

      this.remoteStream = stream;
      this.remoteHasVideo =
        this.remoteHasVideo ||
        event.track?.kind === "video" ||
        stream.getVideoTracks?.().length > 0;
      this._attachMediaElements();
    },

    // --- Controls ---

    _wireControls() {
      this.el.addEventListener("click", (event) => {
        const button = event.target.closest(`[${config.actionAttribute}]`);
        if (!button) return;

        const action = button.getAttribute(config.actionAttribute);
        switch (action) {
          case "mute":
            this._toggleMute();
            break;
          case "camera":
            this._toggleCamera();
            break;
          case "end-call":
            this._endCall("ended");
            break;
          case "pip":
            this._togglePiP();
            break;
          case "upgrade":
            if (config.upgradeMode === "local") {
              this._handleUpgradeAccepted();
            } else {
              this._push(config.clientEvents.requestUpgrade, {});
            }
            break;
          case "device-settings":
            this._openDeviceSettings();
            break;
        }
      });

      this.el.addEventListener("change", (event) => {
        const select = event.target.closest(`[${config.deviceKindAttribute}]`);
        if (!select) return;

        const kind = select.getAttribute(config.deviceKindAttribute);
        const deviceId = select.value;
        this._switchDevice(kind, deviceId);
      });
    },

    _toggleMute() {
      if (!this.localStream) return;
      this.muted = !this.muted;
      toggleTrack(this.localStream, "audio", !this.muted);
      this._push(config.clientEvents.muteChanged, { muted: this.muted });
    },

    _toggleCamera() {
      if (!this.localStream) return;
      this.cameraOff = !this.cameraOff;
      toggleTrack(this.localStream, "video", !this.cameraOff);
      this._push(config.clientEvents.cameraChanged, { off: this.cameraOff });
    },

    async _togglePiP() {
      const remoteVideo = this._query(config.elementIds.remoteVideo);
      if (!remoteVideo || !supportsPiP()) return;

      try {
        await togglePiP(remoteVideo);
      } catch {
        // PiP can fail before the remote video is playing.
      }
    },

    // --- Audio-to-video upgrade ---

    async _handleUpgradeAccepted() {
      if (!this.pc || !this.localStream || this.callType === "video" || this.upgradeInProgress) {
        return;
      }

      this.upgradeInProgress = true;
      this.upgradeCancelled = false;

      try {
        const videoStream = await acquireMedia({
          video: getVideoConstraints(),
          audio: false,
        });

        if (this.upgradeCancelled) {
          stopAllTracks(videoStream);
          return;
        }

        const videoTrack = videoStream.getVideoTracks()[0];
        this.localStream.addTrack(videoTrack);
        const sender = this.pc.addTrack(videoTrack, this.localStream);
        this.senders.push(sender);

        this.callType = "video";
        this.cameraOff = false;
        this._attachMediaElements();

        this._push(config.clientEvents.callStarted, { type: "video" });
      } catch (error) {
        this._push(config.clientEvents.error, { ...error, phase: "upgrade" });
      } finally {
        this.upgradeInProgress = false;
      }
    },

    _handleUpgradeRejected() {
      // LiveView owns any rejection message.
    },

    _handleUpgradeFailed() {
      this.upgradeCancelled = true;
      this._removeLocalVideoTracks();
      this.callType = this.localStream ? "audio" : null;
      this.cameraOff = false;
      this.remoteHasVideo = false;

      const remoteVideo = this._query(config.elementIds.remoteVideo);
      const localVideo = this._query(config.elementIds.localVideo);
      if (remoteVideo) remoteVideo.srcObject = null;
      if (localVideo) localVideo.srcObject = null;
    },

    _removeLocalVideoTracks() {
      if (!this.localStream) return;

      const videoTracks = this.localStream.getVideoTracks();
      videoTracks.forEach((track) => {
        const sender = this.senders.find((candidate) => candidate.track === track);
        if (this.pc && sender) {
          this.pc.removeTrack(sender);
        }
        track.stop();
        this.localStream.removeTrack(track);
      });

      this.senders = this.senders.filter((sender) => sender.track?.kind !== "video");
    },

    // --- Peer state ---

    _handlePeerMuted(_muted) {
      // LiveView re-renders the indicator.
    },

    _handlePeerCamera(_off) {
      // LiveView re-renders the indicator.
    },

    // --- Device management ---

    async _openDeviceSettings() {
      try {
        const devices = await enumerateDevices();
        this._push(config.clientEvents.devicesListed, {
          audioinput: devices.audioinput.map((device) => ({
            id: device.deviceId,
            label: device.label,
          })),
          audiooutput: devices.audiooutput.map((device) => ({
            id: device.deviceId,
            label: device.label,
          })),
          videoinput: devices.videoinput.map((device) => ({
            id: device.deviceId,
            label: device.label,
          })),
          supports_sink_id: supportsSetSinkId(),
        });
      } catch {
        // Device enumeration can fail before permissions are granted.
      }
    },

    async _switchDevice(kind, deviceId) {
      if (!this.localStream) return;

      try {
        switch (kind) {
          case "audioinput":
            this.localStream = await switchAudioInput(this.localStream, this.senders, deviceId);
            break;
          case "videoinput":
            this.localStream = await switchVideoInput(this.localStream, this.senders, deviceId);
            break;
          case "audiooutput": {
            const remoteAudio = this._query(config.elementIds.remoteAudio);
            if (remoteAudio) {
              await setSinkId(remoteAudio, deviceId);
            }
            break;
          }
        }
      } catch {
        this._push(config.clientEvents.deviceFallback, {
          message: t("Device disconnected, using default device"),
        });
      }
    },

    // --- Quality monitoring ---

    _startQualityPolling() {
      this.qualityInterval = setInterval(async () => {
        if (!this.pc) return;

        try {
          const snapshot = await getQualitySnapshot(this.pc);
          const level = mapQualityLevel(snapshot);
          this._push(config.clientEvents.qualityUpdate, {
            level,
            label: QUALITY_LABELS[level],
          });
        } catch {
          // Stats can be unavailable until RTP starts flowing.
        }
      }, 3000);
    },

    async _handleSetPreset(preset) {
      if (!this.pc) return;

      try {
        await applyBitratePreset(this.pc, preset);
      } catch {
        // Preset application can fail on older browsers.
      }
    },

    // --- Duration timer ---

    _startDurationTimer() {
      this.durationInterval = setInterval(() => {
        if (!this.startTime) return;
        this._push(config.clientEvents.durationTick, {
          formatted: formatDuration(this.startTime),
        });
      }, 1000);
    },

    // --- Device change detection ---

    _setupDeviceChangeListener() {
      if (!navigator.mediaDevices?.addEventListener) return;

      this._onDeviceChange = async () => {
        if (!this.localStream) return;

        const devices = await enumerateDevices();
        const currentAudioTrack = this.localStream.getAudioTracks()[0];
        if (!currentAudioTrack) return;

        const currentDeviceId = currentAudioTrack.getSettings?.().deviceId;
        const stillAvailable = devices.audioinput.some(
          (device) => device.deviceId === currentDeviceId,
        );

        if (!stillAvailable) {
          try {
            this.localStream = await switchAudioInput(this.localStream, this.senders, "default");
            this._push(config.clientEvents.deviceFallback, {
              message: t("Device disconnected, using default device"),
            });
          } catch {
            // Fallback failed; keep the current UI state.
          }
        }
      };

      navigator.mediaDevices.addEventListener("devicechange", this._onDeviceChange);
    },

    // --- Timers ---

    _stopTimers() {
      if (this.durationInterval) {
        clearInterval(this.durationInterval);
        this.durationInterval = null;
      }

      if (this.qualityInterval) {
        clearInterval(this.qualityInterval);
        this.qualityInterval = null;
      }
    },

    // --- Cleanup ---

    _cleanup() {
      this._stopTimers();

      if (this._onDeviceChange && navigator.mediaDevices?.removeEventListener) {
        navigator.mediaDevices.removeEventListener("devicechange", this._onDeviceChange);
        this._onDeviceChange = null;
      }

      if (this.localStream) {
        stopAllTracks(this.localStream);
        this.localStream = null;
      }

      this.remoteStream = null;
      this.remoteHasVideo = false;
      this.senders = [];
      this.pc = null;
      this.callType = null;
      this.startTime = null;
      this.upgradeInProgress = false;
      this.upgradeCancelled = false;
    },
  };
}
