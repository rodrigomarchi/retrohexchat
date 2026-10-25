/**
 * Screen sharing on the conference connection: starting a share in place of
 * the camera, stopping it (by the person or by a moderator), the local
 * preview, and telling the server. Mixed into the controller by
 * `createConferenceConnection`; the methods share its `this`.
 */
import { t } from "../i18n.js";
import { log } from "../logger.js";
import {
  acquireDisplayMedia,
  applySenderProfile,
  getScreenShareConstraints,
} from "../p2p/media.js";

export function screenShareMethods(el, ports) {
  return {
    async _toggleScreenShare() {
      if (this.screenShare?.active) {
        await this._stopScreenShare("local_stop");
      } else {
        await this._startScreenShare();
      }
    },

    async _startScreenShare() {
      if (this.screenShare?.active) return;

      if (this.screenShareBlocked) {
        this._notifyWarning(
          t("Screen sharing was disabled by a moderator."),
          "screen_share_moderated",
        );
        return;
      }

      if (!navigator.mediaDevices?.getDisplayMedia) {
        this._notifyWarning(
          t("Screen sharing is not supported by this browser."),
          "screen_unsupported",
        );
        return;
      }

      const sender = this._videoSender();
      if (!sender?.replaceTrack) {
        this._notifyWarning(
          t("Screen sharing will be available after media connects."),
          "screen_sender_missing",
        );
        return;
      }

      let stream;

      try {
        stream = await acquireDisplayMedia(getScreenShareConstraints());
      } catch (error) {
        log.warn("[group-call] screen capture failed", error);
        this._notifyWarning(t("Screen sharing was cancelled or denied."), "screen_capture_failed");
        return;
      }

      const track = stream.getVideoTracks()[0];

      if (!track) {
        this._stopStream(stream);
        this._notifyWarning(
          t("Screen sharing did not provide a video track."),
          "screen_track_missing",
        );
        return;
      }

      try {
        await sender.replaceTrack(track);
        await applySenderProfile(sender, "screen");
      } catch (error) {
        log.warn("[group-call] screen replaceTrack failed", error);
        this._stopStream(stream);
        this._notifyWarning(t("Could not publish the shared screen."), "screen_publish_failed");
        return;
      }

      this.videoSender = sender;
      this.screenShare = { active: true, stream, track };

      track.onended = () => {
        this._stopScreenShare("browser_ended");
      };

      this._attachLocalPreviewStream(stream);
      this._syncLocalTile();
      this._publishScreenShareState(true, track, stream);
    },

    async _stopScreenShare(reason = "local_stop") {
      if (!this.screenShare?.active) return;

      const { stream, track } = this.screenShare;
      this.screenShare = { active: false, stream: null, track: null };

      const sender = this._videoSender();

      try {
        if (sender?.replaceTrack) {
          await sender.replaceTrack(this.cameraVideoTrack || null);
          await applySenderProfile(sender);
        }
      } catch (error) {
        log.warn("[group-call] unable to restore camera track after screen share", error);
      }

      if (track) track.onended = null;
      this._stopStream(stream);
      this._attachLocalPreviewStream(this.localStream);
      this._syncLocalTile();
      this._publishScreenShareState(false, track, stream, reason);
    },

    _videoSender() {
      if (this.videoSender) return this.videoSender;
      const senders = typeof this.pc?.getSenders === "function" ? this.pc.getSenders() : [];
      this.videoSender =
        senders.find((sender) => sender.track?.kind === "video") ||
        senders.find((sender) => sender.track === null && sender.replaceTrack);

      return this.videoSender;
    },

    _attachLocalPreviewStream(stream) {
      const video = el.querySelector("[data-group-call-local-video]");
      if (!video) return;

      video.srcObject = stream || null;
      video.muted = true;
      video.playsInline = true;
    },

    _publishScreenShareState(active, track = null, stream = null, reason = null) {
      const payload = {
        active,
        participant_id: this.participantId,
        track_id: track?.id || null,
        stream_id: stream?.id || null,
        reason,
      };

      const push = this.channel?.push("group_call_screen_share_state", payload);

      if (active && push?.receive) {
        push.receive("error", (reply) => {
          this._notifyWarning(
            reply?.message || t("Screen sharing was disabled by a moderator."),
            "screen_share_rejected",
          );
          this._stopScreenShare("server_rejected");
        });
      }

      ports.pushEvent("group_call_screen_share_state", payload);
    },

    async stopScreenShareByModerator(payload = {}) {
      this.screenShareBlocked = payload.server_screen_blocked !== false;
      this._notifyWarning(
        t("Screen sharing was stopped by a moderator."),
        "screen_share_moderated",
      );
      await this._stopScreenShare(payload.reason || "moderation");
    },

    _clearScreenShareForRejoin() {
      if (!this.screenShare?.active) return;

      if (this.screenShare.track) this.screenShare.track.onended = null;
      this._stopStream(this.screenShare.stream);
      this.screenShare = { active: false, stream: null, track: null };
      this._publishScreenShareState(false, null, null);
      if (this.localStream) this._attachLocalStream(this.localStream);
      this._syncLocalTile();
    },
  };
}
