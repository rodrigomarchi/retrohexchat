/**
 * LiveView Hook: MediaHook
 *
 * Wires LiveView server events to the media.js pure logic module.
 * Manages audio/video call lifecycle, UI controls, and device management.
 * Receives RTCPeerConnection via CustomEvent from WebRTCHook.
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
} from "../lib/media.js";

const MediaHook = {
  mounted() {
    this.pc = null;
    this.localStream = null;
    this.senders = [];
    this.callType = null;
    this.startTime = null;
    this.durationInterval = null;
    this.qualityInterval = null;
    this.muted = false;
    this.cameraOff = false;

    console.log("[Media] Hook mounted");

    // Listen for PeerConnection from WebRTCHook on #p2p-webrtc element
    // (CustomEvents have bubbles:false, so we must listen on the dispatching element)
    this._onPcReady = (e) => this._handlePcReady(e.detail.pc);
    this._onPcClosed = () => this._handlePcClosed();
    this._webrtcEl = document.getElementById("p2p-webrtc");
    if (this._webrtcEl) {
      this._webrtcEl.addEventListener("media_pc_ready", this._onPcReady);
      this._webrtcEl.addEventListener("media_pc_closed", this._onPcClosed);
      // Late mount: if PC already connected before this hook mounted
      if (this._webrtcEl._peerConnection) {
        this._handlePcReady(this._webrtcEl._peerConnection);
      }
    }

    // LiveView server events
    this.handleEvent("media_start_audio", () => this._startCall("audio"));
    this.handleEvent("media_start_video", () => this._startCall("video"));
    this.handleEvent("media_end_call", () => this._endCall("ended"));
    this.handleEvent("media_peer_muted", ({ muted }) => this._handlePeerMuted(muted));
    this.handleEvent("media_peer_camera", ({ off }) => this._handlePeerCamera(off));
    this.handleEvent("media_upgrade_accepted", () => this._handleUpgradeAccepted());
    this.handleEvent("media_upgrade_rejected", () => this._handleUpgradeRejected());
    this.handleEvent("media_set_preset", ({ preset }) => this._handleSetPreset(preset));

    // DOM event wiring
    this._wireControls();
  },

  destroyed() {
    console.log("[Media] Hook destroyed");
    this._cleanup();
    if (this._webrtcEl) {
      this._webrtcEl.removeEventListener("media_pc_ready", this._onPcReady);
      this._webrtcEl.removeEventListener("media_pc_closed", this._onPcClosed);
    }
  },

  // --- PeerConnection lifecycle ---

  _handlePcReady(pc) {
    console.log("[Media] PeerConnection ready");
    this.pc = pc;
    this.pc.ontrack = (event) => this._handleRemoteTrack(event);
  },

  _handlePcClosed() {
    console.log("[Media] PeerConnection closed");
    if (this.callType) {
      this._endCall("Peer desconectou");
    }
  },

  // --- Call start/end ---

  async _startCall(type) {
    console.log(`[Media] Starting ${type} call`);
    if (!this.pc) return;

    const constraints = {};
    constraints.audio = getAudioConstraints();
    if (type === "video") {
      constraints.video = getVideoConstraints();
    }

    try {
      this.localStream = await acquireMedia(constraints);
    } catch (error) {
      console.log(`[Media] Media error: ${error.message}`);
      this.pushEvent("media_error", error);
      return;
    }

    this.senders = addMediaTracks(this.pc, this.localStream);
    setCodecPreferences(this.pc);

    this.callType = type;
    this.startTime = Date.now();
    this.muted = false;
    this.cameraOff = false;

    // Attach local video (muted to prevent feedback)
    if (type === "video") {
      const localVideo = this.el.querySelector("#local-video");
      if (localVideo) {
        localVideo.srcObject = this.localStream;
      }
    }

    this._startDurationTimer();
    this._startQualityPolling();
    this._setupDeviceChangeListener();

    console.log(`[Media] Call started: ${type}, tracks: ${this.localStream.getTracks().length}`);
    this.pushEvent("media_call_started", { type });
  },

  _endCall(reason) {
    console.log(`[Media] Ending call: ${reason}`);
    this._stopTimers();

    if (this.localStream) {
      stopAllTracks(this.localStream);
      this.localStream = null;
    }

    if (this.pc && this.senders.length > 0) {
      removeMediaTracks(this.pc, this.senders);
      this.senders = [];
    }

    // Clear video elements
    const remoteVideo = this.el.querySelector("#remote-video");
    const localVideo = this.el.querySelector("#local-video");
    const remoteAudio = this.el.querySelector("#remote-audio");
    if (remoteVideo) remoteVideo.srcObject = null;
    if (localVideo) localVideo.srcObject = null;
    if (remoteAudio) remoteAudio.srcObject = null;

    // Exit PiP if active
    if (document.pictureInPictureElement) {
      document.exitPictureInPicture().catch(() => {});
    }

    this.callType = null;
    this.startTime = null;
    this.pushEvent("media_call_ended", { reason });
  },

  // --- Remote track handling ---

  _handleRemoteTrack(event) {
    console.log(`[Media] Remote track received: ${event.track.kind}`);
    const [stream] = event.streams;
    if (!stream) return;

    if (this.callType === "video" || event.track.kind === "video") {
      const remoteVideo = this.el.querySelector("#remote-video");
      if (remoteVideo) {
        remoteVideo.srcObject = stream;
      }
    }

    // Always set audio (for both audio and video calls)
    if (event.track.kind === "audio") {
      const remoteAudio = this.el.querySelector("#remote-audio");
      if (remoteAudio) {
        remoteAudio.srcObject = stream;
      }
    }
  },

  // --- Controls ---

  _wireControls() {
    this.el.addEventListener("click", (e) => {
      const btn = e.target.closest("[data-media-action]");
      if (!btn) return;

      const action = btn.dataset.mediaAction;
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
          this.pushEvent("media_request_upgrade", {});
          break;
        case "device-settings":
          this._openDeviceSettings();
          break;
      }
    });

    this.el.addEventListener("change", (e) => {
      const select = e.target.closest("[data-device-kind]");
      if (!select) return;

      const kind = select.dataset.deviceKind;
      const deviceId = select.value;
      this._switchDevice(kind, deviceId);
    });
  },

  _toggleMute() {
    if (!this.localStream) return;
    this.muted = !this.muted;
    console.log(`[Media] Mute toggled: ${this.muted}`);
    toggleTrack(this.localStream, "audio", !this.muted);
    this.pushEvent("media_mute_changed", { muted: this.muted });
  },

  _toggleCamera() {
    if (!this.localStream) return;
    this.cameraOff = !this.cameraOff;
    console.log(`[Media] Camera toggled: off=${this.cameraOff}`);
    toggleTrack(this.localStream, "video", !this.cameraOff);
    this.pushEvent("media_camera_changed", { off: this.cameraOff });
  },

  async _togglePiP() {
    const remoteVideo = this.el.querySelector("#remote-video");
    if (!remoteVideo || !supportsPiP()) return;
    try {
      await togglePiP(remoteVideo);
    } catch {
      // PiP may fail if video not playing yet
    }
  },

  // --- Audio-to-Video Upgrade ---

  async _handleUpgradeAccepted() {
    console.log("[Media] Upgrade to video accepted");
    if (!this.pc || !this.localStream) return;

    try {
      const videoStream = await acquireMedia({
        video: getVideoConstraints(),
        audio: false,
      });
      const videoTrack = videoStream.getVideoTracks()[0];
      this.localStream.addTrack(videoTrack);
      const sender = this.pc.addTrack(videoTrack, this.localStream);
      this.senders.push(sender);

      this.callType = "video";
      this.cameraOff = false;

      const localVideo = this.el.querySelector("#local-video");
      if (localVideo) {
        localVideo.srcObject = this.localStream;
      }

      this.pushEvent("media_call_started", { type: "video" });
    } catch (error) {
      this.pushEvent("media_error", error);
    }
  },

  _handleUpgradeRejected() {
    // Call continues as audio-only, LiveView handles notification
  },

  // --- Peer state ---

  _handlePeerMuted(_muted) {
    // DOM update handled by LiveView re-render
  },

  _handlePeerCamera(_off) {
    // DOM update handled by LiveView re-render
  },

  // --- Device management ---

  async _openDeviceSettings() {
    try {
      const devices = await enumerateDevices();
      this.pushEvent("media_devices_listed", {
        audioinput: devices.audioinput.map((d) => ({ id: d.deviceId, label: d.label })),
        audiooutput: devices.audiooutput.map((d) => ({ id: d.deviceId, label: d.label })),
        videoinput: devices.videoinput.map((d) => ({ id: d.deviceId, label: d.label })),
        supports_sink_id: supportsSetSinkId(),
      });
    } catch {
      // Device enumeration may fail
    }
  },

  async _switchDevice(kind, deviceId) {
    console.log(`[Media] Switching device: ${kind} → ${deviceId}`);
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
          const remoteAudio = this.el.querySelector("#remote-audio");
          if (remoteAudio) {
            await setSinkId(remoteAudio, deviceId);
          }
          break;
        }
      }
    } catch {
      this.pushEvent("media_device_fallback", {
        message: "Dispositivo desconectado, usando dispositivo padrao",
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
        console.log(
          `[Media] Quality: ${QUALITY_LABELS[level]} (RTT: ${snapshot.rtt}ms, loss: ${snapshot.packetLoss}%)`,
        );
        this.pushEvent("media_quality_update", {
          level,
          label: QUALITY_LABELS[level],
        });
      } catch {
        // Stats may not be available yet
      }
    }, 3000);
  },

  // --- Bitrate preset ---

  async _handleSetPreset(preset) {
    if (!this.pc) return;
    try {
      await applyBitratePreset(this.pc, preset);
    } catch {
      // Preset application may fail on some browsers
    }
  },

  // --- Duration timer ---

  _startDurationTimer() {
    this.durationInterval = setInterval(() => {
      if (!this.startTime) return;
      const formatted = formatDuration(this.startTime);
      this.pushEvent("media_duration_tick", { formatted });
    }, 1000);
  },

  // --- Device change detection ---

  _setupDeviceChangeListener() {
    this._onDeviceChange = async () => {
      if (!this.localStream) return;

      // Check if current audio device is still available
      const devices = await enumerateDevices();
      const currentAudioTrack = this.localStream.getAudioTracks()[0];
      if (currentAudioTrack) {
        const stillAvailable = devices.audioinput.some(
          (d) => d.deviceId === currentAudioTrack.getSettings().deviceId,
        );
        if (!stillAvailable) {
          // Fallback to default
          try {
            this.localStream = await switchAudioInput(this.localStream, this.senders, "default");
            this.pushEvent("media_device_fallback", {
              message: "Dispositivo desconectado, usando dispositivo padrao",
            });
          } catch {
            // Fallback failed
          }
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
    console.log("[Media] Cleanup");
    this._stopTimers();

    if (this._onDeviceChange) {
      navigator.mediaDevices.removeEventListener("devicechange", this._onDeviceChange);
      this._onDeviceChange = null;
    }

    if (this.localStream) {
      stopAllTracks(this.localStream);
      this.localStream = null;
    }

    this.senders = [];
    this.pc = null;
    this.callType = null;
    this.startTime = null;
  },
};

export default MediaHook;
