import { acquireMedia, attachMediaStream, enumerateDevices, setSinkId } from "../p2p/media.js";
import { captureConstraints } from "../p2p/device_constraints.js";
import { mediaErrorMessage, missingDeviceWarning } from "../p2p/device_errors.js";
import { t } from "../i18n.js";
import { log } from "../logger.js";

/**
 * The group-call pre-join device preview — controller, no LiveView. Enumerates
 * devices, previews the camera, and reports preferences and device lists back
 * through the pushEvent port. Bound by hooks/group_call/group_call_prejoin_hook.js.
 */
export function createGroupCallPreJoin(el, { pushEvent }) {
  const prejoin = {
    el,
    pushEvent,

    mount() {
      this.config = this._config();
      this.form = this.el.closest("form");
      this._refreshElements();
      this.previewStream = null;
      this.previewKey = null;
      this.previewPendingKey = null;
      this.previewRun = 0;

      this._onChange = () => {
        this._pushPreferences();
        this._startPreview();
      };

      this._onSubmit = () => {
        this._cancelPreview();
      };

      this._onRetry = () => this._startPreview({ force: true });

      this.form?.addEventListener("change", this._onChange);
      this.form?.addEventListener("input", this._onChange);
      this.form?.addEventListener("submit", this._onSubmit);
      this.retry?.addEventListener("click", this._onRetry);

      this._restore();
      this._pushPreferences();
      this._listDevices();
      this._startPreview();
    },

    reconcile() {
      this.config = this._config();
      this.form = this.el.closest("form");
      this._refreshElements();
      this._startPreview();
    },

    destroy() {
      this.form?.removeEventListener("change", this._onChange);
      this.form?.removeEventListener("input", this._onChange);
      this.form?.removeEventListener("submit", this._onSubmit);
      this.retry?.removeEventListener("click", this._onRetry);
      this._cancelPreview();
    },

    async _listDevices() {
      if (!navigator.mediaDevices?.enumerateDevices) {
        this._setDeviceState(t("Device selection unavailable"));
        return;
      }

      try {
        const devices = await enumerateDevices();
        const payload = {
          audioinput: this._devicePayload(devices.audioinput, t("Microphone")),
          videoinput: this._devicePayload(devices.videoinput, t("Camera")),
          audiooutput: this._devicePayload(devices.audiooutput, t("Speaker")),
        };

        this.pushEvent(this.config.devicesEvent, payload);
        this._setDeviceState(t("Devices ready"));
        this._showDeviceAvailabilityWarning(payload);
      } catch (error) {
        log.warn("[group-call-prejoin] failed to enumerate devices", error);
        this._setDeviceState(t("Device list failed"));
      }
    },

    async _startPreview(options = {}) {
      const preferences = this._preferencesFromForm();
      const constraints = this._constraints(preferences);
      const key = JSON.stringify(constraints);
      const force = options.force === true;

      if (key === this.previewKey && !force) {
        if (this.previewPendingKey === key) return;
        this._syncPreviewDom(preferences);
        return;
      }

      const run = ++this.previewRun;
      this.previewKey = key;
      this.previewPendingKey = key;
      this._clearWarning();

      if (!constraints.audio && !constraints.video) {
        this._stopPreview();
        this.previewPendingKey = null;
        this._setDeviceState(t("Receive-only"));
        this._showEmpty(true, t("Joining receive-only"));
        return;
      }

      try {
        const stream = await acquireMedia(constraints);
        if (run !== this.previewRun) {
          stream.getTracks().forEach((track) => track.stop());
          return;
        }

        this.previewPendingKey = null;
        this._stopPreview();
        this.previewStream = stream;

        await this._attachPreviewStream(stream, preferences);
      } catch (error) {
        if (run !== this.previewRun) return;

        log.warn("[group-call-prejoin] preview failed", error);
        this.previewPendingKey = null;
        this._stopPreview();
        this._showEmpty(true, t("Camera preview unavailable"));
        this._showWarning(this._previewFailureMessage(error, preferences));
      }
    },

    _stopPreview() {
      if (this.previewStream) {
        this.previewStream.getTracks().forEach((track) => track.stop());
        this.previewStream = null;
      }

      if (this.video) {
        attachMediaStream(this.video, null);
      }
    },

    _cancelPreview() {
      this.previewRun += 1;
      this.previewPendingKey = null;
      this._stopPreview();
    },

    async _attachPreviewStream(stream, preferences) {
      if (this.video) {
        attachMediaStream(this.video, stream, {
          muted: true,
          onPlaybackError: (error) => {
            log.warn("[group-call-prejoin] preview playback failed", error);
            this._showWarning(t("Camera preview is blocked by the browser. Retry the preview."));
          },
          onVideoStalled: ({ reason }) => {
            log.warn("[group-call-prejoin] preview video stalled", { reason });
          },
        });

        if (preferences.audio_output_id) {
          await setSinkId(this.video, preferences.audio_output_id).catch(() => false);
        }
      }

      this._showEmpty(
        stream.getVideoTracks().length === 0,
        preferences.video ? t("Camera preview unavailable") : t("Camera preview is off"),
      );
    },

    _syncPreviewDom(preferences) {
      if (this.previewStream) {
        this._attachPreviewStream(this.previewStream, preferences);
        return;
      }

      if (!preferences.audio && !preferences.video) {
        this._showEmpty(true, t("Joining receive-only"));
      }
    },

    _constraints(preferences) {
      return captureConstraints(
        { audio: preferences.audio, video: preferences.video },
        { audioInputId: preferences.audio_input_id, videoInputId: preferences.video_input_id },
      );
    },

    _pushPreferences() {
      const preferences = this._preferencesFromForm();
      this._remember(preferences);
      this.pushEvent(this.config.preferencesEvent, preferences);
    },

    /**
     * Put the antechamber back the way this person left it.
     *
     * Only when the server had nothing to render: a trusted terminal keeps this
     * choice in its device record and that copy wins. Everyone else has no
     * record on the server at all, and the choice is per *terminal* anyway —
     * a camera id only means something on the machine that enumerated it — so
     * the browser is the honest place for it. It used to survive because the
     * chat process was still standing when the antechamber closed; the chat
     * does not host a conference any more, and nothing was left holding it.
     */
    _restore() {
      if (this.el.dataset.prejoinRemembered === "true") return;

      const stored = this._stored();
      if (!stored) return;

      this._setCheckbox("audio", stored.audio);
      this._setCheckbox("video", stored.video);

      for (const name of [
        "layout_mode",
        "self_view",
        "audio_input_id",
        "video_input_id",
        "audio_output_id",
      ]) {
        this._setField(name, stored[name]);
      }
    },

    _remember(preferences) {
      const key = this._storageKey();
      if (!key) return;

      try {
        window.localStorage.setItem(key, JSON.stringify(preferences));
      } catch (error) {
        // A private window, or site data blocked. The antechamber still works;
        // it just will not remember, which is the state it was already in.
        log.debug("[group-call-prejoin] could not remember the choice", error);
      }
    },

    _stored() {
      const key = this._storageKey();
      if (!key) return null;

      try {
        const raw = window.localStorage.getItem(key);
        return raw ? JSON.parse(raw) : null;
      } catch (error) {
        log.debug("[group-call-prejoin] could not read the remembered choice", error);
        return null;
      }
    },

    // Keyed by who is at the antechamber: one browser is one terminal, and two
    // people sharing it must not inherit each other's microphone.
    _storageKey() {
      const scope = this.el.dataset.prejoinScope;
      return scope ? `rhc:group-call:prejoin:${scope}` : null;
    },

    _setCheckbox(name, value) {
      if (typeof value !== "boolean") return;

      const checkbox = this.form?.querySelector(
        `[name="${this.config.formName}[${name}]"][type="checkbox"]`,
      );

      if (checkbox) checkbox.checked = value;
    },

    _setField(name, value) {
      if (typeof value !== "string") return;

      const field = this.form?.querySelector(`[name="${this.config.formName}[${name}]"]`);
      if (field) field.value = value;
    },

    _preferencesFromForm() {
      return {
        audio: this._checkbox("audio", true),
        video: this._checkbox("video", true),
        layout_mode: this._field("layout_mode") || "auto",
        self_view: this._field("self_view") || "tile",
        audio_input_id: this._field("audio_input_id") || "",
        video_input_id: this._field("video_input_id") || "",
        audio_output_id: this._field("audio_output_id") || "",
      };
    },

    _field(name) {
      return this.form?.querySelector(`[name="${this.config.formName}[${name}]"]`)?.value || "";
    },

    _checkbox(name, defaultValue) {
      const checkbox = this.form?.querySelector(
        `[name="${this.config.formName}[${name}]"][type="checkbox"]`,
      );

      return checkbox ? checkbox.checked : defaultValue;
    },

    _devicePayload(devices, fallbackPrefix) {
      return (devices || []).map((device, index) => ({
        id: device.deviceId || "",
        label: device.label || `${fallbackPrefix} ${index + 1}`,
      }));
    },

    _config() {
      return {
        prefix: this.el.dataset.prejoinPrefix || "group-call-prejoin",
        formName: this.el.dataset.formName || "group_call_prejoin",
        devicesEvent: this.el.dataset.devicesEvent || "group_call_prejoin_devices_listed",
        preferencesEvent:
          this.el.dataset.preferencesEvent || "group_call_prejoin_preferences_loaded",
      };
    },

    _refreshElements() {
      this.video = this.el.querySelector(this._selector("video"));
      this.empty = this.el.querySelector(this._selector("empty"));
      this.warning = this.el.querySelector(this._selector("warning"));
      this.warningText = this.el.querySelector(this._selector("warning-text"));
      this.retry = this.el.querySelector(this._selector("retry"));
      this.deviceState = this.el.querySelector(this._selector("device-state"));
      this.deviceStateText = this.el.querySelector(this._selector("device-state-text"));
      this.emptyText = this.el.querySelector(this._selector("empty-text"));
    },

    _selector(suffix) {
      return `[data-${this.config.prefix}-${suffix}]`;
    },

    _showEmpty(show, label = t("Camera preview is off")) {
      if (this.emptyText) this.emptyText.textContent = label;
      this.empty?.classList.toggle("hidden", !show);
    },

    _showWarning(message) {
      if (this.warningText) this.warningText.textContent = message;
      this.warning?.classList.remove("hidden");
      this.warning?.classList.add("flex");
    },

    _clearWarning() {
      if (this.warningText) this.warningText.textContent = "";
      this.warning?.classList.add("hidden");
      this.warning?.classList.remove("flex");
    },

    _setDeviceState(label) {
      if (this.deviceStateText) this.deviceStateText.textContent = label;
    },

    _showDeviceAvailabilityWarning(payload) {
      const warning = missingDeviceWarning(this._preferencesFromForm(), payload);
      if (warning) this._showWarning(warning);
    },

    _previewFailureMessage(error, preferences) {
      return mediaErrorMessage(error, preferences);
    },
  };

  return prejoin;
}
