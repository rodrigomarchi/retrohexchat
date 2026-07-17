/**
 * Configurable LiveView hook for RTC audio/video media.
 *
 * The hook owns media capture and DOM attachment, but it does not own signaling.
 * Signaling remains on the WebRTC hook that provides the RTCPeerConnection.
 */
import { log } from "../logger.js";
import {
  acquireMedia,
  acquireDisplayMedia,
  getAudioConstraints,
  getVideoConstraints,
  getScreenShareConstraints,
  addMediaTracks,
  removeMediaTracks,
  toggleTrack,
  stopAllTracks,
  formatDuration,
  getStatsSnapshot,
  deriveStats,
  applyBitratePreset,
  applyMediaProfile,
  applySenderProfile,
  setCodecPreferences,
  enumerateDevices,
  switchAudioInput,
  switchVideoInput,
  setSinkId,
  supportsSetSinkId,
  supportsPiP,
  togglePiP,
} from "./media.js";
import { t } from "../i18n.js";

const noopEvent = null;

function isEditableTarget(target) {
  if (!(target instanceof Element)) return false;

  return !!target.closest(
    'input, textarea, select, [contenteditable=""], [contenteditable="true"], [role="textbox"]',
  );
}

function normalizeConfig(config) {
  return {
    webrtcElementId: config.webrtcElementId,
    pcReadyEvent: config.pcReadyEvent,
    pcClosedEvent: config.pcClosedEvent,
    actionAttribute: config.actionAttribute || "data-media-action",
    deviceKindAttribute: config.deviceKindAttribute || "data-device-kind",
    upgradeMode: config.upgradeMode || "request",
    // When true, this hook can be placed "in a call" by the server without
    // acquiring any media (recvonly auto-join) and runs a watchdog that recovers
    // a remote video track that negotiated but never started flowing. Lobby-only;
    // the /p2p flow leaves it off so its bilateral-consent path is untouched.
    autoJoin: config.autoJoin === true,
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
      joinCall: config.serverEvents?.joinCall,
    },
    clientEvents: {
      ready: config.clientEvents?.ready,
      error: config.clientEvents?.error,
      callStarted: config.clientEvents?.callStarted,
      callEnded: config.clientEvents?.callEnded,
      muteChanged: config.clientEvents?.muteChanged,
      cameraChanged: config.clientEvents?.cameraChanged,
      qualityUpdate: config.clientEvents?.qualityUpdate,
      statsUpdate: config.clientEvents?.statsUpdate,
      durationTick: config.clientEvents?.durationTick,
      requestUpgrade: config.clientEvents?.requestUpgrade,
      devicesListed: config.clientEvents?.devicesListed,
      deviceFallback: config.clientEvents?.deviceFallback,
      screenShareChanged: config.clientEvents?.screenShareChanged,
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
      // Self-controlled send state, tracked independently of the call presence so
      // a peer can be "in the call" (auto-joined, recvonly) while sending nothing.
      this.inCall = false;
      this.audioOn = false;
      this.videoOn = false;
      this.screenShare = { active: false, stream: null, track: null, previousVideoTrack: null };
      this.watchdogInterval = null;
      this._stalledSince = null;

      this._onPcReady = (event) => this._handlePcReady(event.detail.pc);
      this._onPcClosed = () => this._handlePcClosed();
      this._onShortcutKeydown = (event) => this._handleShortcutKeydown(event);
      this._webrtcEl = document.getElementById(config.webrtcElementId);

      if (this._webrtcEl) {
        this._webrtcEl.addEventListener(config.pcReadyEvent, this._onPcReady);
        this._webrtcEl.addEventListener(config.pcClosedEvent, this._onPcClosed);

        if (this._webrtcEl._peerConnection) {
          this._handlePcReady(this._webrtcEl._peerConnection);
        }
      }

      this._handleServerEvent(config.serverEvents.startAudio, (payload = {}) =>
        this._startCall("audio", payload),
      );
      this._handleServerEvent(config.serverEvents.startVideo, (payload = {}) =>
        this._startCall("video", payload),
      );
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
      this._handleServerEvent(config.serverEvents.joinCall, () => this._joinCall());

      this._wireControls();
      document.addEventListener("keydown", this._onShortcutKeydown, true);
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

      document.removeEventListener("keydown", this._onShortcutKeydown, true);
    },

    _handleShortcutKeydown(event) {
      if (!this._callWindowActive()) return;
      if (!event.ctrlKey || !event.shiftKey || event.altKey || event.metaKey) return;
      if (isEditableTarget(event.target)) return;

      const action = this._shortcutAction(event.key);
      if (!action) return;

      event.preventDefault();
      event.stopImmediatePropagation();

      switch (action) {
        case "audio":
          this._toggleAudioShortcut();
          break;
        case "video":
          this._toggleVideoShortcut();
          break;
        case "layout":
          this.pushEvent("cycle_call_layout", { source: "shortcut" });
          break;
        case "self-view":
          this.pushEvent("cycle_call_self_view", { source: "shortcut" });
          break;
        case "screen-share":
          this._toggleScreenShareShortcut();
          break;
        case "end-call":
          if (this.inCall) this._endCall("shortcut");
          break;
      }
    },

    _callWindowActive() {
      const windowEl = this.el.closest?.("[data-window-id]");
      if (!windowEl) return true;

      return (
        windowEl.getAttribute("data-window-id") === "p2p-call" &&
        !windowEl.classList.contains("u-hidden") &&
        !windowEl.classList.contains("desktop-window--blurred")
      );
    },

    _shortcutAction(key) {
      const normalized = key.length === 1 ? key.toLowerCase() : key;

      switch (normalized) {
        case "ArrowUp":
          return "audio";
        case "ArrowLeft":
          return "video";
        case "ArrowRight":
          return "layout";
        case "ArrowDown":
          return "self-view";
        case ".":
          return "screen-share";
        case "q":
          return "end-call";
        default:
          return null;
      }
    },

    _toggleAudioShortcut() {
      if (!this.inCall) {
        this._startCall("audio");
      } else if (!this.audioOn) {
        this._enableAudio();
      } else {
        this._toggleMute();
      }
    },

    _toggleVideoShortcut() {
      if (!this.inCall) {
        this._startCall("video");
      } else if (!this.videoOn) {
        this._enableVideo();
      } else {
        this._toggleCamera();
      }
    },

    async _toggleScreenShareShortcut() {
      if (!this.pc) return;
      await this._toggleScreenShare();
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
      this._adoptExistingRemoteTracks();
      this._attachMediaElements();
    },

    _handlePcClosed() {
      if (this.callType || this.localStream || this.remoteStream) {
        this._endCall(t("Peer disconnected"));
      }
    },

    // --- Call start/end ---

    async _startCall(type, opts = {}) {
      if (!this.pc || this.startingCall) return;

      const mediaMode = this.el?.dataset?.mediaMode || "video";

      if (opts.auto === true && mediaMode === "receive") {
        this._joinCall();
        return;
      }

      if (opts.auto === true && mediaMode === "audio" && type === "video") {
        type = "audio";
      }

      const receiverEnablingAudio =
        config.autoJoin && type === "audio" && this.callType === "receiving";

      if (this.callType && !receiverEnablingAudio) return;

      if (type === "audio" && config.autoJoin) {
        this._joinCall();
        this._enableAudioAfterReceiveReady();
        return;
      }

      this.startingCall = true;

      const preferences = opts.device_preferences || opts.devicePreferences || {};
      const audioInputId = preferences.audio_input_id || preferences.audioInputId || "";
      const videoInputId = preferences.video_input_id || preferences.videoInputId || "";
      const constraints = { audio: getAudioConstraints(audioInputId) };
      if (type === "video") {
        constraints.video = getVideoConstraints(videoInputId);
      }

      try {
        this.localStream = await acquireMedia(constraints);
      } catch (error) {
        this.startingCall = false;
        // An auto-joined receiver that cannot open its own mic/camera (e.g.
        // permission denied) still joins as a pure receiver, so the user can watch
        // and listen and retry from the enable controls. A first mover instead
        // surfaces the hard error.
        if (opts.auto) {
          this._joinCall();
          this._push(config.clientEvents.deviceFallback, {
            message: t(
              "Could not access your microphone or camera. You can still watch and listen.",
            ),
          });
        } else {
          this._push(config.clientEvents.error, error);
        }
        return;
      }

      this.senders = addMediaTracks(this.pc, this.localStream);
      setCodecPreferences(this.pc);
      await applyMediaProfile(this.pc);

      this.callType = type;
      this.inCall = true;
      this.audioOn = true;
      this.videoOn = type === "video";
      this.startTime = this.startTime || Date.now();
      this.muted = false;
      this.cameraOff = false;

      this._attachMediaElements();
      this._startDurationTimer();
      this._startQualityPolling();
      this._startMediaWatchdog();
      this._setupDeviceChangeListener();

      this._reportSendState();
      // Sync the icon to the freshly acquired (enabled) tracks instead of relying on
      // the server assigns already being false — they may be stale from a prior call.
      this._syncSendToggles();
      this.startingCall = false;
    },

    // Push the current mute / camera-off flags so the server-side icon reflects the
    // real (freshly enabled) track state when a call starts, instead of trusting the
    // server assigns to already be false — they may be stale from a prior call.
    _syncSendToggles() {
      this._push(config.clientEvents.muteChanged, { muted: this.muted });
      this._push(config.clientEvents.cameraChanged, { off: this.cameraOff });
    },

    // Enter the call as a pure receiver (auto-join), without acquiring any media.
    // The server has already marked us a participant; we just light up the call
    // surface, timers and watchdog so the incoming stream renders and recovers.
    _joinCall() {
      if (this.inCall) return;
      this.inCall = true;
      this.callType = "receiving";
      this.audioOn = false;
      this.videoOn = false;
      this.screenShare = { active: false, stream: null, track: null, previousVideoTrack: null };
      this.muted = false;
      this.cameraOff = false;
      this.startTime = this.startTime || Date.now();

      this._attachMediaElements();
      this._startDurationTimer();
      this._startQualityPolling();
      this._startMediaWatchdog();
      // No toggle sync here: a pure receiver sends nothing, so the mute/camera
      // controls stay hidden until `_enableAudio` / `_enableVideo` (which push their
      // own state) reveal them.
    },

    _enableAudioAfterReceiveReady() {
      const startedAt = Date.now();
      const shortWaitMs = 3000;
      const hardWaitMs = 25000;
      let recoveryRequested = false;

      const ready = () => {
        return this._remoteVideoFlowing();
      };

      const tick = () => {
        if (!this.inCall || this.audioOn) return;
        this._adoptExistingRemoteTracks();

        if (ready()) {
          this._enableAudio();
          return;
        }

        const elapsed = Date.now() - startedAt;
        const track = this._remoteVideoTrack();
        const stalledTrack = track?.readyState === "live" && !this._remoteVideoFlowing();

        if (elapsed > shortWaitMs && stalledTrack) {
          if (!recoveryRequested) {
            recoveryRequested = true;
            this._requestMediaRecovery({
              restart: true,
              reason: "audio_only_remote_video_stalled",
            });
          }

          if (elapsed <= hardWaitMs) {
            window.setTimeout(tick, 150);
            return;
          }
        } else if (elapsed > shortWaitMs && !track) {
          this._enableAudio();
          return;
        }

        if (elapsed > hardWaitMs) {
          this._enableAudio();
          return;
        }

        window.setTimeout(tick, 100);
      };

      tick();
    },

    // Acquire and send the microphone on demand (the auto-joined peer choosing to
    // speak). Adding the track triggers renegotiation on the shared connection.
    async _enableAudio() {
      if (!this.pc || this.audioOn || this.upgradeInProgress) return;

      try {
        const stream = await acquireMedia({ audio: getAudioConstraints() });
        const track = stream.getAudioTracks()[0];
        if (!this.localStream) this.localStream = new MediaStream();
        this.localStream.addTrack(track);
        const sender = this.pc.addTrack(track, this.localStream);
        this.senders.push(sender);
        await applySenderProfile(sender);

        this.audioOn = true;
        this.muted = false;
        this._setupDeviceChangeListener();
        this._attachMediaElements();
        this._reportSendState();
        // Sync the (un)muted state so the control reflects reality and the peer's
        // indicator clears.
        this._push(config.clientEvents.muteChanged, { muted: false });
      } catch (error) {
        this._push(config.clientEvents.error, error);
      }
    },

    // Push the current self-controlled send state. Reuses the callStarted event so
    // the server keeps one entry point for "this peer's media changed".
    _reportSendState() {
      const type = this.videoOn ? "video" : this.audioOn ? "audio" : "receiving";
      // Only the auto-join (lobby) flow carries the granular send flags; the /p2p
      // and /game flows keep their original `{type}`-only payload untouched.
      const payload = config.autoJoin
        ? { type, audio_on: this.audioOn, video_on: this.videoOn }
        : { type };
      this._push(config.clientEvents.callStarted, payload);
    },

    // Acquire and send the camera on demand. Works whether or not we already have
    // a local stream (an auto-joined receiver has none yet), so it covers both the
    // "turn my camera on" and the classic audio→video upgrade.
    async _enableVideo() {
      if (!this.pc || this.videoOn || this.upgradeInProgress) return;

      this.upgradeInProgress = true;
      this.upgradeCancelled = false;

      try {
        const stream = await acquireMedia({ video: getVideoConstraints(), audio: false });

        if (this.upgradeCancelled) {
          stopAllTracks(stream);
          return;
        }

        const track = stream.getVideoTracks()[0];
        if (!this.localStream) this.localStream = new MediaStream();
        this.localStream.addTrack(track);
        const sender = this.pc.addTrack(track, this.localStream);
        this.senders.push(sender);
        await applySenderProfile(sender);

        this.videoOn = true;
        this.cameraOff = false;
        this.callType = "video";
        this._setupDeviceChangeListener();
        this._attachMediaElements();
        this._reportSendState();
        // Sync the camera-on state so the control reflects reality and the peer's
        // camera-off placeholder clears.
        this._push(config.clientEvents.cameraChanged, { off: false });
      } catch (error) {
        this._push(config.clientEvents.error, { ...error, phase: "enable-video" });
      } finally {
        this.upgradeInProgress = false;
      }
    },

    _endCall(reason, opts = {}) {
      const notify = opts.notify !== false;

      this._stopTimers();
      this._stopMediaWatchdog();

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

      this._clearScreenShareState({ stopTrack: true, notify: false });
      this.callType = null;
      this.inCall = false;
      this.audioOn = false;
      this.videoOn = false;
      // The send-toggle flags are per-track state; clear them with the tracks so a
      // later call does not inherit a stale mute/camera-off from the previous one.
      this.muted = false;
      this.cameraOff = false;
      this.startTime = null;

      if (notify) {
        this._push(config.clientEvents.callEnded, { reason });
      }
    },

    // --- Stalled-media watchdog (autoJoin only) ---

    // A remote video track that negotiates but never starts flowing stays
    // `muted` (no RTP). When that persists past the grace window, ask the WebRTC
    // hook to recover (ICE restart / re-offer) instead of leaving a black frame.
    _startMediaWatchdog() {
      if (!config.autoJoin || this.watchdogInterval) return;

      this._stalledSince = null;
      this.watchdogInterval = setInterval(() => {
        this._adoptExistingRemoteTracks();
        const track = this._remoteVideoTrack();
        const stalledTrack = track?.readyState === "live" && !this._remoteVideoFlowing();

        if (!stalledTrack) {
          this._stalledSince = null;
          return;
        }

        if (!this._stalledSince) {
          this._stalledSince = Date.now();
        } else if (Date.now() - this._stalledSince > 3000) {
          this._stalledSince = null;
          this._requestMediaRecovery();
        }
      }, 1000);
    },

    _stopMediaWatchdog() {
      if (this.watchdogInterval) {
        clearInterval(this.watchdogInterval);
        this.watchdogInterval = null;
      }
      this._stalledSince = null;
    },

    _requestMediaRecovery(detail = {}) {
      if (this._webrtcEl) {
        this._webrtcEl.dispatchEvent(new CustomEvent("lobby_media_recover", { detail }));
      }
    },

    _remoteVideoTrack() {
      return this.remoteStream?.getVideoTracks?.()[0] || null;
    },

    _remoteVideoFlowing() {
      const track = this._remoteVideoTrack();
      if (!track || track.readyState !== "live" || track.muted === true) return false;

      const remoteVideo = this._query(config.elementIds.remoteVideo);
      if (!remoteVideo) return true;

      return (
        remoteVideo.readyState >= HTMLMediaElement.HAVE_CURRENT_DATA &&
        remoteVideo.videoWidth > 0 &&
        remoteVideo.videoHeight > 0
      );
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
      this._addRemoteTrack(event.track, stream || null);
      this._attachMediaElements();
    },

    _adoptExistingRemoteTracks() {
      if (!this.pc?.getReceivers) return;

      let adopted = false;
      for (const receiver of this.pc.getReceivers()) {
        const track = receiver.track;
        if (!track || track.readyState === "ended") continue;
        if (track.kind !== "audio" && track.kind !== "video") continue;

        adopted = this._addRemoteTrack(track, null) || adopted;
      }

      if (adopted) this._attachMediaElements();
    },

    _addRemoteTrack(track, stream) {
      if (!track || (track.kind !== "audio" && track.kind !== "video")) return false;

      if (stream) {
        this.remoteStream = stream;
      } else if (!this.remoteStream) {
        this.remoteStream = new MediaStream();
      }

      const exists = this.remoteStream.getTracks().some((candidate) => candidate.id === track.id);
      if (!exists) this.remoteStream.addTrack(track);

      this.remoteHasVideo =
        this.remoteHasVideo ||
        track.kind === "video" ||
        this.remoteStream.getVideoTracks?.().length > 0;

      return !exists;
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
          case "enable-audio":
            this._enableAudio();
            break;
          case "enable-video":
            this._enableVideo();
            break;
          case "end-call":
            this._endCall("ended");
            break;
          case "pip":
            this._togglePiP();
            break;
          case "screen-share":
            this._toggleScreenShare();
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
      } catch (error) {
        // PiP can fail before the remote video is playing — non-fatal, but log it.
        log.warn("[RtcMedia] Picture-in-Picture toggle failed", error);
      }
    },

    async _toggleScreenShare() {
      if (this.screenShare?.active) {
        await this._stopScreenShare();
      } else {
        await this._startScreenShare();
      }
    },

    async _startScreenShare() {
      if (!this.pc || this.screenShare?.active) return;

      let screenStream;
      try {
        screenStream = await acquireDisplayMedia(getScreenShareConstraints());
      } catch (error) {
        this._push(config.clientEvents.deviceFallback, {
          message: error.message || t("Screen sharing was cancelled or denied."),
        });
        return;
      }

      const screenTrack = screenStream.getVideoTracks?.()[0];
      if (!screenTrack) {
        stopAllTracks(screenStream);
        this._push(config.clientEvents.deviceFallback, {
          message: t("No screen video track was provided by the browser."),
        });
        return;
      }

      const previousVideoTrack = this.localStream?.getVideoTracks?.()[0] || null;
      const videoSender = this._videoSender();

      try {
        if (!this.localStream) this.localStream = new MediaStream();

        let sender = videoSender;
        if (videoSender) {
          await videoSender.replaceTrack(screenTrack);
        } else {
          sender = this.pc.addTrack(screenTrack, this.localStream);
          this.senders.push(sender);
        }
        await applySenderProfile(sender, "screen");

        if (previousVideoTrack) {
          this.localStream.removeTrack(previousVideoTrack);
        }
        this.localStream.addTrack(screenTrack);

        this.screenShare = {
          active: true,
          stream: screenStream,
          track: screenTrack,
          previousVideoTrack,
        };
        screenTrack.onended = () => this._stopScreenShare();
        const wasInCall = this.inCall;
        this.videoOn = true;
        this.cameraOff = false;
        this.callType = "video";
        this.inCall = true;
        this.startTime = this.startTime || Date.now();
        if (!wasInCall) {
          this._startDurationTimer();
          this._startQualityPolling();
          this._startMediaWatchdog();
          this._setupDeviceChangeListener();
        }
        this._attachMediaElements();
        this._reportSendState();
        this._reportMediaSource("screen");
        this._push(config.clientEvents.cameraChanged, { off: false });
        this._push(config.clientEvents.screenShareChanged, { active: true });
      } catch (error) {
        stopAllTracks(screenStream);
        log.warn("[RtcMedia] Screen share publish failed", error);
        this._push(config.clientEvents.deviceFallback, {
          message: t("Could not publish the shared screen."),
        });
      }
    },

    async _stopScreenShare() {
      if (!this.screenShare?.active) return;

      const { stream, track, previousVideoTrack } = this.screenShare;
      const sender = this._videoSender();

      this.screenShare = { active: false, stream: null, track: null, previousVideoTrack: null };

      try {
        if (sender && previousVideoTrack && previousVideoTrack.readyState !== "ended") {
          await sender.replaceTrack(previousVideoTrack);
          await applySenderProfile(sender);
          if (this.localStream) {
            if (track) this.localStream.removeTrack(track);
            this.localStream.addTrack(previousVideoTrack);
          }
          this.videoOn = true;
          this.callType = "video";
        } else {
          if (this.pc && sender) {
            this.pc.removeTrack(sender);
          }
          this.senders = this.senders.filter((candidate) => candidate !== sender);
          if (this.localStream && track) this.localStream.removeTrack(track);
          this.videoOn = false;
          this.callType = this.audioOn ? "audio" : "receiving";
        }
      } catch (error) {
        log.warn("[RtcMedia] Screen share restore failed", error);
        this.videoOn = false;
        this.callType = this.audioOn ? "audio" : "receiving";
      } finally {
        if (track && track.readyState !== "ended") track.stop();
        if (stream) stopAllTracks(stream);
        this._attachMediaElements();
        this._reportSendState();
        this._reportMediaSource("camera");
        this._push(config.clientEvents.screenShareChanged, { active: false });
      }
    },

    _clearScreenShareState(opts = {}) {
      const stopTrack = opts.stopTrack === true;
      const notify = opts.notify === true;
      const { stream, track, previousVideoTrack } = this.screenShare || {};

      if (stopTrack) {
        if (track && track.readyState !== "ended") {
          track.stop();
        }

        if (previousVideoTrack && previousVideoTrack.readyState !== "ended") {
          previousVideoTrack.stop();
        }

        if (stream) stopAllTracks(stream);
      }

      this.screenShare = { active: false, stream: null, track: null, previousVideoTrack: null };
      if (notify) this._push(config.clientEvents.screenShareChanged, { active: false });
      this._reportMediaSource("camera");
    },

    _reportMediaSource(source) {
      this._webrtcEl?.dispatchEvent(
        new CustomEvent("lobby_media_source_changed", {
          detail: { source },
        }),
      );
    },

    _videoSender() {
      return this.senders.find((sender) => sender.track?.kind === "video");
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
        await applySenderProfile(sender);

        this.callType = "video";
        this.videoOn = true;
        this.cameraOff = false;
        this._attachMediaElements();

        this._reportSendState();
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
      } catch (error) {
        log.warn("[RtcMedia] Failed to enumerate media devices", error);
        this._push(config.clientEvents.deviceFallback, {
          message: t("Could not list media devices. Check your browser permissions."),
        });
      }
    },

    async _switchDevice(kind, deviceId) {
      if (!this.localStream) return;

      try {
        switch (kind) {
          case "audioinput":
            this.localStream = await switchAudioInput(this.localStream, this.senders, deviceId);
            // A fresh getUserMedia track is always enabled; re-apply the mute flag so
            // switching mics does not silently un-mute the user.
            toggleTrack(this.localStream, "audio", !this.muted);
            break;
          case "videoinput":
            this.localStream = await switchVideoInput(this.localStream, this.senders, deviceId);
            toggleTrack(this.localStream, "video", !this.cameraOff);
            break;
          case "audiooutput": {
            const remoteAudio = this._query(config.elementIds.remoteAudio);
            if (remoteAudio) {
              await setSinkId(remoteAudio, deviceId);
            }
            break;
          }
        }
      } catch (error) {
        log.warn("[RtcMedia] Failed to switch media device", error);
        this._push(config.clientEvents.deviceFallback, {
          message: t("Device disconnected, using default device"),
        });
      }
    },

    // --- Quality monitoring ---

    _startQualityPolling() {
      this._prevStats = null;
      this.qualityInterval = setInterval(async () => {
        if (!this.pc) return;

        try {
          const snapshot = await getStatsSnapshot(this.pc);
          const derived = deriveStats(this._prevStats, snapshot);
          this._prevStats = snapshot;

          // Compact level/label drives the connection diagram (both hooks).
          this._push(config.clientEvents.qualityUpdate, {
            level: derived.level,
            label: derived.label,
          });

          // Full numeric telemetry feeds the network panel (P2P hook only).
          if (config.clientEvents.statsUpdate) {
            this._push(config.clientEvents.statsUpdate, derived);
          }
        } catch (error) {
          // Stats can be unavailable until RTP starts flowing — debug, not warn,
          // to avoid spamming the console on every early poll.
          log.debug("[RtcMedia] Quality stats sample failed", error);
        }
      }, 3000);
    },

    async _handleSetPreset(preset) {
      if (!this.pc) return;

      try {
        await applyBitratePreset(this.pc, preset);
      } catch (error) {
        log.warn("[RtcMedia] Failed to apply bitrate preset", error);
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
            // Preserve the mute state across the automatic fallback to the default mic.
            toggleTrack(this.localStream, "audio", !this.muted);
            this._push(config.clientEvents.deviceFallback, {
              message: t("Device disconnected, using default device"),
            });
          } catch (error) {
            // Falling back to the default mic also failed — the peer can no longer
            // hear this user. Surface it instead of leaving them silently muted.
            log.error("[RtcMedia] Audio device fallback failed", error);
            this._push(config.clientEvents.deviceFallback, {
              message: t("Your microphone is unavailable. Check your audio devices."),
            });
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
      this._stopMediaWatchdog();

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
      this.inCall = false;
      this.audioOn = false;
      this.videoOn = false;
      this._clearScreenShareState({ stopTrack: true, notify: false });
      this.muted = false;
      this.cameraOff = false;
      this.startTime = null;
      this.upgradeInProgress = false;
      this.upgradeCancelled = false;
    },
  };
}
