/**
 * Keeping the conference connection alive: reading the peer connection's
 * state, backing off and retrying, the offer watchdog, rejoining the
 * transport, and what the page is told at each step. Mixed into the
 * controller by `createConferenceConnection`; the methods share its `this`.
 */
import { t } from "../i18n.js";
import { log } from "../logger.js";
import {
  canDeferRecovery,
  hasExhaustedRecovery,
  hasExhaustedWatchdog,
  isDisconnectedReason,
  nextRecoveryAttempt,
  recoveryBackoffDelay,
  watchdogDelay,
} from "../p2p/recovery.js";
import { stringOrNull } from "./payload.js";
import { collectConnectionActivity, hasConnectionActivity } from "../p2p/media.js";

const DISCONNECTED_ACTIVITY_DEFERRAL_LIMIT = 2;
const OFFER_WATCHDOG_DELAY_MS = 1500;
const OFFER_WATCHDOG_MAX_ATTEMPTS = 3;

/** The waits between recovery attempts; their count is how many attempts there are. */
export const RECOVERY_BACKOFF_MS = [1000, 2000, 4000];

export function recoveryMethods(_el, ports) {
  return {
    _handleConnectionStateChange() {
      const state = this.pc?.connectionState || "";

      ports.pushEvent("group_call_connection_state", { state });

      if (state === "connected") {
        this._clearOfferWatchdog();
        this._clearRecovery("connected");
        return;
      }

      if (state === "connecting") {
        this._publishRecoveryState({
          state: "connecting",
          message: t("Group call media is connecting."),
        });
        return;
      }

      if (state === "disconnected" || state === "failed") {
        this._scheduleRecovery(state);
      }
    },

    _handleIceConnectionStateChange() {
      const state = this.pc?.iceConnectionState || "";

      if (state === "connected" || state === "completed") {
        this._clearRecovery("ice_connected");
        return;
      }

      if (state === "checking") {
        this._publishRecoveryState({
          state: "connecting",
          message: t("Group call media is connecting."),
        });
        return;
      }

      if (state === "disconnected" || state === "failed") {
        this._scheduleRecovery(`ice_${state}`);
      }
    },

    _scheduleRecovery(reason, { countAttempt = true } = {}) {
      if (this.recoveryTimer) return;

      if (countAttempt && hasExhaustedRecovery(this.recoveryAttempts, this.maxRecoveryAttempts)) {
        this._publishRecoveryState({
          state: "failed",
          reason,
          manual_retry: true,
          attempt: this.recoveryAttempts,
          max_attempts: this.maxRecoveryAttempts,
          message: t("Media recovery failed. Retry the media connection."),
        });
        return;
      }

      const attempt = nextRecoveryAttempt(this.recoveryAttempts, countAttempt);
      const delay = recoveryBackoffDelay(attempt, RECOVERY_BACKOFF_MS);
      if (countAttempt) this.recoveryAttempts = attempt;
      const beforeActivity = isDisconnectedReason(reason)
        ? collectConnectionActivity(this.pc)
        : null;

      this._publishRecoveryState({
        state: "reconnecting",
        reason,
        attempt,
        max_attempts: this.maxRecoveryAttempts,
        next_retry_ms: delay,
        message: t("The call's sound and video were cut off. Trying to recover."),
      });

      this.recoveryTimer = setTimeout(async () => {
        this.recoveryTimer = null;

        if (await this._deferDisconnectedRecoveryForActivity(reason, beforeActivity)) {
          return;
        }

        this.retryConnection("auto");
      }, delay);
    },

    async _deferDisconnectedRecoveryForActivity(reason, beforeActivity) {
      if (!beforeActivity || !isDisconnectedReason(reason)) return false;

      const before = await beforeActivity;
      const after = await collectConnectionActivity(this.pc);

      if (!hasConnectionActivity(before, after)) {
        this.recoveryActivityDeferrals = 0;
        return false;
      }

      const deferrals = this.recoveryActivityDeferrals || 0;

      if (!canDeferRecovery(deferrals, DISCONNECTED_ACTIVITY_DEFERRAL_LIMIT)) {
        this.recoveryActivityDeferrals = 0;
        return false;
      }

      this.recoveryActivityDeferrals = deferrals + 1;
      log.debug("[group-call] deferring recovery while media/data still moves", {
        reason,
        deferrals: this.recoveryActivityDeferrals,
      });
      this._scheduleRecovery(reason, { countAttempt: false });
      return true;
    },

    _scheduleOfferWatchdog(trigger = "join") {
      if (
        this.offerWatchdogTimer ||
        hasExhaustedWatchdog(this.offerWatchdogAttempts, OFFER_WATCHDOG_MAX_ATTEMPTS) ||
        !this._needsOfferWatchdog()
      ) {
        return;
      }

      const attempt = this.offerWatchdogAttempts + 1;
      this.offerWatchdogAttempts = attempt;

      this.offerWatchdogTimer = setTimeout(
        () => {
          this.offerWatchdogTimer = null;
          if (!this._needsOfferWatchdog()) return;

          this._requestOfferFromWatchdog(trigger, attempt);

          if (hasExhaustedWatchdog(attempt, OFFER_WATCHDOG_MAX_ATTEMPTS)) {
            this.offerWatchdogTimer = setTimeout(() => {
              this.offerWatchdogTimer = null;
              if (this._needsOfferWatchdog()) {
                this._publishRecoveryState({
                  state: "failed",
                  reason: "offer_not_received",
                  trigger: "offer_watchdog",
                  attempt,
                  max_attempts: OFFER_WATCHDOG_MAX_ATTEMPTS,
                  manual_retry: true,
                  message: t("Media offer was not received. Retry the media connection."),
                });
              }
            }, OFFER_WATCHDOG_DELAY_MS);
            return;
          }

          this._scheduleOfferWatchdog(trigger);
        },
        watchdogDelay(attempt, OFFER_WATCHDOG_DELAY_MS),
      );
    },

    _needsOfferWatchdog() {
      return !this.closing && !this.rejoining && !this.pc?.remoteDescription;
    },

    _requestOfferFromWatchdog(trigger, attempt) {
      this._publishRecoveryState({
        state: "reconnecting",
        reason: "offer_not_received",
        trigger: "offer_watchdog",
        attempt,
        max_attempts: OFFER_WATCHDOG_MAX_ATTEMPTS,
        message: t("Waiting for media offer. Requesting a fresh offer."),
      });

      const push = this.channel?.push("group_call_request_offer", {
        attempt,
        trigger: "offer_watchdog",
        reason: trigger,
      });

      if (!push?.receive) {
        this._publishRecoveryState({
          state: "failed",
          reason: "offer_not_received",
          trigger: "offer_watchdog",
          attempt,
          max_attempts: OFFER_WATCHDOG_MAX_ATTEMPTS,
          manual_retry: true,
          message: t("Media recovery failed. Retry the media connection."),
        });
        return;
      }

      push
        .receive("error", (reply) => {
          if (reply?.code === "rejoin_required") {
            this._rejoinConnection("offer_watchdog", reply);
            return;
          }

          this._publishRecoveryState({
            state: "failed",
            reason: reply?.code || "offer_not_received",
            trigger: "offer_watchdog",
            attempt,
            max_attempts: OFFER_WATCHDOG_MAX_ATTEMPTS,
            manual_retry: true,
            message: reply?.message || t("Media recovery failed. Retry the media connection."),
          });
        })
        .receive("timeout", () => {
          this._publishRecoveryState({
            state: "failed",
            reason: "offer_request_timeout",
            trigger: "offer_watchdog",
            attempt,
            max_attempts: OFFER_WATCHDOG_MAX_ATTEMPTS,
            manual_retry: true,
            message: t("Sound and video did not come back in time. Try to connect them again."),
          });
        });
    },

    retryConnection(trigger = "manual") {
      if (this.recoveryTimer) {
        clearTimeout(this.recoveryTimer);
        this.recoveryTimer = null;
      }

      if (this.recoveryAttempts < 1) this.recoveryAttempts = 1;

      const attempt = this.recoveryAttempts;

      this._publishRecoveryState({
        state: "negotiating",
        trigger,
        attempt,
        max_attempts: this.maxRecoveryAttempts,
        message: t("Requesting a fresh media offer."),
      });

      const push = this.channel?.push("group_call_request_offer", {
        attempt,
        trigger,
      });

      if (!push?.receive) {
        this._publishRecoveryState({
          state: "failed",
          trigger,
          attempt,
          max_attempts: this.maxRecoveryAttempts,
          manual_retry: true,
          message: t("Media recovery failed. Retry the media connection."),
        });
        return;
      }

      push
        .receive("error", (reply) => {
          if (reply?.code === "rejoin_required") {
            this._rejoinConnection(trigger, reply);
            return;
          }

          this._publishRecoveryState({
            state: "failed",
            trigger,
            attempt,
            max_attempts: this.maxRecoveryAttempts,
            manual_retry: true,
            message: reply?.message || t("Media recovery failed. Retry the media connection."),
          });
        })
        .receive("timeout", () => {
          this._publishRecoveryState({
            state: "failed",
            trigger,
            attempt,
            max_attempts: this.maxRecoveryAttempts,
            manual_retry: true,
            message: t("Sound and video did not come back in time. Try to connect them again."),
          });
        });
    },

    _handleRemoteVideoStalled(streamId, reason = "remote_video_stalled") {
      const key = stringOrNull(streamId);
      if (!key || this.remoteVideoStalls?.get(key) === true) return;

      this.remoteVideoStalls.set(key, true);
      this._publishRecoveryState({
        state: "reconnecting",
        reason,
        trigger: "remote_video_stalled",
        attempt: this.recoveryAttempts || 1,
        max_attempts: this.maxRecoveryAttempts,
        message: t("Remote video stopped rendering. Trying to recover the media path."),
      });
      this.retryConnection("remote_video_stalled");
    },

    _rejoinConnection(trigger = "manual", reply = {}) {
      if (this.rejoining) return;

      const previousParticipantId = this.participantId;
      this.rejoining = true;
      this.rejoinEpoch += 1;

      this._publishRecoveryState({
        state: "rejoining",
        trigger,
        attempt: this.recoveryAttempts,
        max_attempts: this.maxRecoveryAttempts,
        manual_retry: false,
        message: reply?.message || t("Rejoining the media session."),
      });

      this._prepareTransportRejoin();
      this._joinGroupCall("rejoin", { previousParticipantId });
    },

    _prepareTransportRejoin() {
      this._stopStatsPolling();
      this._clearOfferWatchdog();
      this.pendingCandidates = [];
      this.remoteCandidateFailures = 0;
      this.offerQueue = Promise.resolve();
      this.lastAnsweredOfferSdp = null;
      this.lastAnsweredOfferId = null;

      this._clearScreenShareForRejoin();

      if (this.pc) {
        this.pc.onconnectionstatechange = null;
        this.pc.onicecandidate = null;
        this.pc.ontrack = null;
        this.pc.close();
      }

      this.pc = null;
      this.localSenders = [];
      this._sendersPc = null;
      this.videoSender = null;
      this.cameraVideoTrack = this.localStream?.getVideoTracks?.()[0] || null;

      this._clearRemoteTilesForRejoin();
    },

    _clearRemoteTilesForRejoin() {
      this.tileView.removeAll();
      this.remoteVideoStalls?.clear();
      this.trackRegistry.clear();
      this._applyLayout();
    },

    _clearRecovery(reason = "connected") {
      if (this.recoveryTimer) {
        clearTimeout(this.recoveryTimer);
        this.recoveryTimer = null;
      }

      this.recoveryAttempts = 0;
      this.recoveryActivityDeferrals = 0;
      this.remoteCandidateFailures = 0;
      this._clearOfferWatchdog();
      this.remoteVideoStalls?.clear();
      this._publishRecoveryState({
        state: "connected",
        reason,
        attempt: 0,
        max_attempts: this.maxRecoveryAttempts,
        manual_retry: false,
        message: "",
      });
    },

    _publishRecoveryState(payload) {
      ports.pushEvent("group_call_recovery_state", {
        attempt: 0,
        max_attempts: this.maxRecoveryAttempts,
        manual_retry: false,
        next_retry_ms: 0,
        ...payload,
      });
    },

    _notifyError(message, code = "connection_failed") {
      ports.pushEvent("group_call_client_error", { code, message });
    },

    _notifyWarning(message, code = "media_warning") {
      ports.pushEvent("group_call_client_warning", { code, message });
    },

    _clearOfferWatchdog() {
      if (this.offerWatchdogTimer) {
        clearTimeout(this.offerWatchdogTimer);
        this.offerWatchdogTimer = null;
      }

      this.offerWatchdogAttempts = 0;
    },
  };
}
