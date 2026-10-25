/**
 * The local microphone and camera on the conference connection: turning them
 * on and off, capturing a track only when it is first needed, push-to-talk,
 * the server's holds, and telling the room. Mixed into the controller by
 * `createConferenceConnection`; the methods share its `this`.
 */
import { t } from "../i18n.js";
import { log } from "../logger.js";
import { isEditableTarget } from "../ui/dom.js";
import { captureConstraints } from "../p2p/device_constraints.js";
import { hasOwn } from "./payload.js";
import { actualMediaState, hasLiveTrack, needsOnDemandMedia } from "./media_state.js";
import { applyMediaProfile, applyTrackHints } from "../p2p/media.js";

const PUSH_TO_TALK_KEYS = new Set(["z", "Z"]);

export function localMediaMethods(_el, ports) {
  return {
    setMediaState(payload) {
      if (hasOwn(payload, "server_audio_muted")) {
        this.serverAudioMuted = payload.server_audio_muted === true;
      }

      if (hasOwn(payload, "server_video_blocked")) {
        this.serverVideoBlocked = payload.server_video_blocked === true;
      }

      if (hasOwn(payload, "server_screen_blocked")) {
        this.screenShareBlocked = payload.server_screen_blocked === true;
      }

      if (this.screenShareBlocked && this.screenShare?.active) {
        this._stopScreenShare("moderation");
      }

      this._publishLocalMediaState({
        audio: payload.audio !== false,
        video: payload.video !== false,
      });
    },

    _publishLocalMediaState(media, { mirrorToLiveView = false } = {}) {
      const desired = {
        audio: media.audio !== false && !this.serverAudioMuted,
        video: media.video !== false && !this.serverVideoBlocked,
      };

      this.mediaEnabled = desired;
      this._applyMediaEnabled();
      this._syncLocalTile();

      if (this._needsOnDemandMedia(desired)) {
        this._ensureRequestedLocalTracks(desired)
          .catch((error) => {
            log.warn("[group-call] on-demand media capture failed", error);
            this._notifyWarning(
              t("Could not access your microphone or camera."),
              "media_capture_failed",
            );
          })
          .finally(() => {
            this.mediaEnabled = this._actualMediaState(desired);
            this._applyMediaEnabled();
            this._syncLocalTile();
            this._pushLocalMediaState(mirrorToLiveView);
          });
        return;
      }

      this._pushLocalMediaState(mirrorToLiveView);
    },

    _pushLocalMediaState(mirrorToLiveView = false) {
      if (this.participantId) {
        this.channel?.push("group_call_media_state", this.mediaEnabled);
      }

      if (mirrorToLiveView) {
        ports.pushEvent("group_call_media_state_forced", this.mediaEnabled);
      }
    },

    _needsOnDemandMedia(desired) {
      if (!this.pc) return false;
      return needsOnDemandMedia(desired, this._hasLocalAudioTrack(), this._hasLocalVideoTrack());
    },

    async _ensureRequestedLocalTracks(desired) {
      if (!this.pc) return;

      const needsAudio = desired.audio && !this._hasLocalAudioTrack();
      const needsVideo = desired.video && !this._hasLocalVideoTrack();
      if (!needsAudio && !needsVideo) return;

      const stream = await navigator.mediaDevices.getUserMedia(
        captureConstraints({ audio: needsAudio, video: needsVideo }, this.devicePreferences),
      );

      applyTrackHints(stream);
      this._mergeLocalStream(stream);

      for (const track of stream.getTracks()) {
        const sender = this.pc.addTrack(track, this.localStream || stream);
        this.localSenders.push(sender);

        if (track.kind === "video") {
          this.videoSender = sender;
          this.cameraVideoTrack = track;
        }
      }

      await applyMediaProfile(this.pc);
      this._sendersPc = this.pc;
      this._attachLocalStream(this.localStream || stream);
      this._requestOfferAfterLocalMediaChange();
    },

    _mergeLocalStream(stream) {
      if (!this.localStream || !this.localStream.getTracks) {
        this.localStream = stream;
        return;
      }

      if (typeof this.localStream.addTrack !== "function") {
        if ((this.localStream.getTracks?.() || []).length === 0) this.localStream = stream;
        return;
      }

      for (const track of stream.getTracks()) {
        this.localStream.addTrack(track);
      }
    },

    _actualMediaState(desired) {
      return actualMediaState(desired, this._hasLocalAudioTrack(), this._hasLocalVideoTrack());
    },

    _requestOfferAfterLocalMediaChange() {
      const push = this.channel?.push("group_call_request_offer", {
        attempt: this.recoveryAttempts,
        trigger: "local_media_added",
      });

      push?.receive?.("error", (reply) => {
        if (reply?.code === "rejoin_required") this._rejoinConnection("local_media_added", reply);
      });
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

    _handlePushToTalkKeydown(event) {
      if (!this._isPushToTalkEvent(event)) return;
      if (event.defaultPrevented || event.repeat || this.pushToTalkActive) return;
      if (isEditableTarget(event.target)) return;
      if (this.mediaEnabled.audio === true || this.serverAudioMuted) return;

      if (!this._hasLocalAudioTrack()) {
        this._notifyWarning(
          t("Microphone is not available for push-to-talk."),
          "ptt_audio_missing",
        );
        return;
      }

      event.preventDefault();
      event.stopPropagation();

      this.pushToTalkActive = true;
      this.pushToTalkRestoreAudio = this.mediaEnabled.audio;
      this._publishLocalMediaState(
        { ...this.mediaEnabled, audio: true },
        { mirrorToLiveView: true },
      );
    },

    _handlePushToTalkKeyup(event) {
      if (!this.pushToTalkActive || !this._isPushToTalkEvent(event)) return;

      event.preventDefault();
      event.stopPropagation();

      const restoreAudio = this.pushToTalkRestoreAudio === true;
      this.pushToTalkActive = false;
      this.pushToTalkRestoreAudio = null;

      this._publishLocalMediaState(
        { ...this.mediaEnabled, audio: restoreAudio },
        { mirrorToLiveView: true },
      );
    },

    _isPushToTalkEvent(event) {
      return (
        event.ctrlKey === true &&
        event.shiftKey === true &&
        event.altKey !== true &&
        event.metaKey !== true &&
        PUSH_TO_TALK_KEYS.has(event.key)
      );
    },

    _hasLocalAudioTrack() {
      return hasLiveTrack(this.localStream?.getAudioTracks?.());
    },

    _hasLocalVideoTrack() {
      return hasLiveTrack(this.localStream?.getVideoTracks?.());
    },
  };
}
