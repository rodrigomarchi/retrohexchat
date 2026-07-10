/**
 * LiveView Hook: GroupCallWebRTCHook
 *
 * Minimal browser-side SFU client. It uses a raw Phoenix Channel so SDP/ICE do
 * not travel through the ChatLive process.
 */
import { Socket } from "phoenix";
import { log } from "../../lib/logger.js";

const DEFAULT_CONSTRAINTS = { audio: true, video: true };

const GroupCallWebRTCHook = {
  mounted() {
    this.roomToken = this.el.dataset.groupCallToken;
    this.joinToken = this.el.dataset.joinToken;
    this.localStream = null;
    this.pc = null;
    this.socket = null;
    this.channel = null;
    this.pendingCandidates = [];
    this.participantId = null;
    this.mediaEnabled = this._mediaConstraints();
    this.closing = false;
    this.offerQueue = Promise.resolve();
    this.lastAnsweredOfferSdp = null;

    if (!this.roomToken || !this.joinToken) {
      log.warn("[group-call] missing room token or join token");
      return;
    }

    this.handleEvent("group_call_set_media_state", (payload) => {
      this._setMediaState(payload || {});
    });

    this._connect();
    this.pushEvent("group_call_webrtc_ready", {});
  },

  destroyed() {
    this._cleanup();
  },

  _connect() {
    this.socket = new Socket("/socket");
    this.socket.connect();

    this.channel = this.socket.channel(`group_call:${this.roomToken}`, {
      join_token: this.joinToken,
    });

    this.channel.on("group_call_joined", (payload) => {
      this.participantId = payload?.participant?.id || null;
      this.pushEvent("group_call_client_joined", payload);
      this.channel?.push("group_call_media_state", this.mediaEnabled);
    });
    this.channel.on("group_call_offer", (payload) => {
      this.pushEvent("group_call_offer_received", {
        participant_id: payload?.participant_id,
      });
      this._handleOffer(payload);
    });
    this.channel.on("group_call_ice_candidate", (payload) => {
      this._handleRemoteCandidate(payload.candidate);
    });
    this.channel.on("group_call_peer_joined", (payload) => {
      this.pushEvent("group_call_peer_joined", payload);
    });
    this.channel.on("group_call_peer_left", (payload) => {
      this.pushEvent("group_call_peer_left", payload);
    });
    this.channel.on("group_call_track_added", (payload) => {
      this.pushEvent("group_call_track_added", payload);
    });
    this.channel.on("group_call_media_state", (payload) => {
      this.pushEvent("group_call_media_state", payload);
    });
    this.channel.on("group_call_set_media_state", (payload) => {
      this._setMediaState(payload || {});
      this.pushEvent("group_call_media_state_forced", payload || {});
    });
    this.channel.on("group_call_track_updated", (payload) => {
      this.pushEvent("group_call_track_updated", payload);
    });
    this.channel.on("group_call_track_removed", (payload) => {
      this.pushEvent("group_call_track_removed", payload);
    });
    this.channel.on("group_call_closed", (payload) => {
      this.pushEvent("group_call_closed", payload);
      this._cleanup();
    });
    this.channel.on("group_call_error", (payload) => {
      log.warn("[group-call] signaling error", payload);
      this.pushEvent("group_call_client_error", payload);
    });
    this.channel.onError(() => {
      if (!this.closing) {
        this._notifyError("Group call signaling connection failed", "signaling_failed");
      }
    });
    this.channel.onClose(() => {
      if (!this.closing && this.participantId) {
        this._notifyWarning("Group call signaling channel closed", "signaling_closed");
      }
    });

    this.channel
      .join()
      .receive("ok", () => {
        this.channel
          .push("group_call_join", {
            client_info: this._clientInfo(),
            media_constraints: this.mediaEnabled,
          })
          .receive("error", (reply) => {
            this._notifyError(reply?.message || "Unable to join group call", "join_failed");
          })
          .receive("timeout", () => {
            this._notifyError("Group call join timed out", "join_timeout");
          });
      })
      .receive("error", (reply) => {
        log.warn("[group-call] channel join rejected", reply);
        this._notifyError(
          reply?.reason || "Group call channel rejected the join",
          "channel_join_rejected",
        );
      })
      .receive("timeout", () => {
        log.warn("[group-call] channel join timed out");
        this._notifyError("Group call channel join timed out", "channel_join_timeout");
      });
  },

  _handleOffer(payload) {
    this.offerQueue = this.offerQueue.catch(() => {}).then(() => this._processOffer(payload || {}));

    return this.offerQueue;
  },

  async _processOffer({ sdp, ice_servers }) {
    if (!sdp) {
      this._notifyError("Group call media negotiation failed", "media_negotiation_failed");
      return;
    }

    if (this.lastAnsweredOfferSdp === sdp) {
      return;
    }

    try {
      await this._ensurePeerConnection(ice_servers || []);
      await this.pc.setRemoteDescription({ type: "offer", sdp });
      await this._ensureLocalTracks();
      await this._flushPendingCandidates();

      const answer = await this.pc.createAnswer();
      await this.pc.setLocalDescription(answer);

      this.channel.push("group_call_answer", {
        sdp: this.pc.localDescription.sdp,
      });
      this.lastAnsweredOfferSdp = sdp;
    } catch (error) {
      log.warn("[group-call] failed to handle offer", error);
      this._notifyError("Group call media negotiation failed", "media_negotiation_failed");
    }
  },

  async _ensurePeerConnection(iceServers) {
    if (this.pc) return;

    this.pc = new RTCPeerConnection({ iceServers });

    this.pc.onconnectionstatechange = () => {
      this.pushEvent("group_call_connection_state", {
        state: this.pc.connectionState,
      });
    };

    this.pc.onicecandidate = (event) => {
      if (!event.candidate) return;
      this.channel?.push("group_call_ice_candidate", {
        candidate: event.candidate.toJSON(),
      });
    };

    this.pc.ontrack = (event) => {
      this._attachRemoteStream(event.streams[0]);
    };
  },

  async _ensureLocalTracks() {
    if (this.localStream) return;

    try {
      this.localStream = await navigator.mediaDevices.getUserMedia(this.mediaEnabled);
    } catch (error) {
      log.warn("[group-call] media capture failed, answering recvonly", error);
      this._notifyWarning(
        "Could not access your microphone or camera. You joined receive-only.",
        "media_capture_failed",
      );
      return;
    }

    for (const track of this.localStream.getTracks()) {
      this.pc.addTrack(track, this.localStream);
    }

    this._attachLocalStream(this.localStream);
    this._applyMediaEnabled();
  },

  async _handleRemoteCandidate(candidate) {
    if (!candidate) return;

    if (!this.pc || !this.pc.remoteDescription) {
      this.pendingCandidates.push(candidate);
      return;
    }

    try {
      await this.pc.addIceCandidate(candidate);
    } catch (error) {
      log.warn("[group-call] failed to add ICE candidate", error);
    }
  },

  async _flushPendingCandidates() {
    const candidates = this.pendingCandidates.splice(0);

    for (const candidate of candidates) {
      await this._handleRemoteCandidate(candidate);
    }
  },

  _attachLocalStream(stream) {
    const video = this.el.querySelector("[data-group-call-local-video]");
    if (video) {
      video.srcObject = stream;
      video.muted = true;
      video.playsInline = true;
    }
  },

  _attachRemoteStream(stream) {
    if (!stream) return;

    const host = this.el.querySelector("[data-group-call-remote-videos]") || this.el;
    const streamId = stream.id || `remote-${Date.now()}`;
    let video = host.querySelector(`[data-stream-id="${streamId}"]`);

    if (!video) {
      video = document.createElement("video");
      video.dataset.streamId = streamId;
      video.autoplay = true;
      video.playsInline = true;
      video.className = "h-full min-h-0 w-full bg-black object-cover";
      host.appendChild(video);
    }

    const placeholder = host.querySelector("[data-group-call-remote-placeholder]");
    placeholder?.classList.add("hidden");

    video.srcObject = stream;
  },

  _mediaConstraints() {
    const audio = this.el.dataset.audio !== "false";
    const video = this.el.dataset.video !== "false";
    return { ...DEFAULT_CONSTRAINTS, audio, video };
  },

  _setMediaState(payload) {
    this.mediaEnabled = {
      audio: payload.audio !== false,
      video: payload.video !== false,
    };

    this._applyMediaEnabled();

    if (this.participantId) {
      this.channel?.push("group_call_media_state", this.mediaEnabled);
    }
  },

  _applyMediaEnabled() {
    if (!this.localStream) return;

    for (const track of this.localStream.getAudioTracks()) {
      track.enabled = this.mediaEnabled.audio;
    }

    for (const track of this.localStream.getVideoTracks()) {
      track.enabled = this.mediaEnabled.video;
    }
  },

  _notifyError(message, code = "connection_failed") {
    this.pushEvent("group_call_client_error", { code, message });
  },

  _notifyWarning(message, code = "media_warning") {
    this.pushEvent("group_call_client_warning", { code, message });
  },

  _clientInfo() {
    return {
      user_agent: navigator.userAgent,
      platform: navigator.platform,
      language: navigator.language,
    };
  },

  _cleanup() {
    this.closing = true;
    this.channel?.push("group_call_leave", {});
    this.channel?.leave();
    this.socket?.disconnect();

    this.localStream?.getTracks()?.forEach((track) => track.stop());
    this.pc?.close();

    this.channel = null;
    this.socket = null;
    this.localStream = null;
    this.pc = null;
    this.pendingCandidates = [];
    this.participantId = null;
    this.offerQueue = Promise.resolve();
    this.lastAnsweredOfferSdp = null;
  },
};

export default GroupCallWebRTCHook;
