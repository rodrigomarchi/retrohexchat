import {
  acquireMedia,
  enumerateDevices,
  getAudioConstraints,
  getVideoConstraints,
  setSinkId,
} from "../../lib/p2p/media.js";
import { t } from "../../lib/i18n.js";
import { log } from "../../lib/logger.js";

const STORAGE_KEY = "rhc:group-call:prejoin";

const GroupCallPreJoinHook = {
  mounted() {
    this.form = this.el.closest("form");
    this.video = this.el.querySelector("[data-group-call-prejoin-video]");
    this.empty = this.el.querySelector("[data-group-call-prejoin-empty]");
    this.warning = this.el.querySelector("[data-group-call-prejoin-warning]");
    this.warningText = this.el.querySelector("[data-group-call-prejoin-warning-text]");
    this.retry = this.el.querySelector("[data-group-call-prejoin-retry]");
    this.deviceState = this.el.querySelector("[data-group-call-prejoin-device-state]");
    this.deviceStateText = this.el.querySelector("[data-group-call-prejoin-device-state-text]");
    this.emptyText = this.el.querySelector("[data-group-call-prejoin-empty-text]");
    this.previewStream = null;
    this.previewKey = null;
    this.previewRun = 0;
    this.storageKey = this._storageKey();

    this._onChange = () => {
      this._savePreferences();
      this._pushPreferences();
      this._startPreview();
    };

    this._onSubmit = () => {
      this._savePreferences();
      this._stopPreview();
    };

    this._onRetry = () => this._startPreview({ force: true });

    this.form?.addEventListener("change", this._onChange);
    this.form?.addEventListener("input", this._onChange);
    this.form?.addEventListener("submit", this._onSubmit);
    this.retry?.addEventListener("click", this._onRetry);

    this._loadPreferences();
    this._pushPreferences();
    this._listDevices();
    this._startPreview();
  },

  updated() {
    this.form = this.el.closest("form");
    this.video = this.el.querySelector("[data-group-call-prejoin-video]");
    this.empty = this.el.querySelector("[data-group-call-prejoin-empty]");
    this.warning = this.el.querySelector("[data-group-call-prejoin-warning]");
    this.warningText = this.el.querySelector("[data-group-call-prejoin-warning-text]");
    this.retry = this.el.querySelector("[data-group-call-prejoin-retry]");
    this.deviceState = this.el.querySelector("[data-group-call-prejoin-device-state]");
    this.deviceStateText = this.el.querySelector("[data-group-call-prejoin-device-state-text]");
    this.emptyText = this.el.querySelector("[data-group-call-prejoin-empty-text]");
    this.storageKey = this._storageKey();
    this._loadPreferences();
    this._startPreview();
  },

  destroyed() {
    this.form?.removeEventListener("change", this._onChange);
    this.form?.removeEventListener("input", this._onChange);
    this.form?.removeEventListener("submit", this._onSubmit);
    this.retry?.removeEventListener("click", this._onRetry);
    this._stopPreview();
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

      this.pushEvent("group_call_prejoin_devices_listed", payload);
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
    const run = ++this.previewRun;
    const force = options.force === true;

    if (key === this.previewKey && !force) return;

    this.previewKey = key;
    this._clearWarning();

    if (!constraints.audio && !constraints.video) {
      this._stopPreview();
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

      this._stopPreview();
      this.previewStream = stream;

      if (this.video) {
        this.video.srcObject = stream;
        this.video.muted = true;
        this.video.playsInline = true;

        if (preferences.audio_output_id) {
          await setSinkId(this.video, preferences.audio_output_id).catch(() => false);
        }
      }

      this._showEmpty(
        stream.getVideoTracks().length === 0,
        preferences.video ? t("Camera preview unavailable") : t("Camera preview is off"),
      );
    } catch (error) {
      if (run !== this.previewRun) return;

      log.warn("[group-call-prejoin] preview failed", error);
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
      this.video.srcObject = null;
    }
  },

  _constraints(preferences) {
    return {
      audio: preferences.audio
        ? this._withDevice(getAudioConstraints(), preferences.audio_input_id)
        : false,
      video: preferences.video
        ? this._withDevice(getVideoConstraints(), preferences.video_input_id)
        : false,
    };
  },

  _withDevice(base, deviceId) {
    if (!deviceId) return base;
    return { ...base, deviceId: { exact: deviceId } };
  },

  _loadPreferences() {
    const preferences = this._readStoredPreferences();
    if (!preferences) return;

    this._setCheckbox("audio", preferences.audio);
    this._setCheckbox("video", preferences.video);
    this._setCheckbox("sidebar_open", preferences.sidebar_open);
    this._setSelect("layout_mode", preferences.layout_mode);
    this._setSelect("self_view", preferences.self_view);
    this._setSelect("audio_input_id", preferences.audio_input_id);
    this._setSelect("video_input_id", preferences.video_input_id);
    this._setSelect("audio_output_id", preferences.audio_output_id);
  },

  _savePreferences() {
    try {
      window.localStorage?.setItem(this.storageKey, JSON.stringify(this._preferencesFromForm()));
    } catch {
      // localStorage may be unavailable in private or restricted contexts.
    }
  },

  _pushPreferences() {
    this.pushEvent("group_call_prejoin_preferences_loaded", this._preferencesFromForm());
  },

  _readStoredPreferences() {
    try {
      const raw = window.localStorage?.getItem(this.storageKey);
      return raw ? JSON.parse(raw) : null;
    } catch {
      return null;
    }
  },

  _preferencesFromForm() {
    return {
      audio: this._checkbox("audio", true),
      video: this._checkbox("video", true),
      sidebar_open: this._checkbox("sidebar_open", true),
      layout_mode: this._field("layout_mode") || "auto",
      self_view: this._field("self_view") || "tile",
      audio_input_id: this._field("audio_input_id") || "",
      video_input_id: this._field("video_input_id") || "",
      audio_output_id: this._field("audio_output_id") || "",
    };
  },

  _field(name) {
    return this.form?.querySelector(`[name="group_call_prejoin[${name}]"]`)?.value || "";
  },

  _checkbox(name, defaultValue) {
    const checkbox = this.form?.querySelector(
      `[name="group_call_prejoin[${name}]"][type="checkbox"]`,
    );

    return checkbox ? checkbox.checked : defaultValue;
  },

  _setCheckbox(name, value) {
    const checkbox = this.form?.querySelector(
      `[name="group_call_prejoin[${name}]"][type="checkbox"]`,
    );

    if (checkbox && typeof value === "boolean") {
      checkbox.checked = value;
    }
  },

  _setSelect(name, value) {
    if (typeof value !== "string") return;
    const select = this.form?.querySelector(`[name="group_call_prejoin[${name}]"]`);
    if (select) select.value = value;
  },

  _devicePayload(devices, fallbackPrefix) {
    return (devices || []).map((device, index) => ({
      id: device.deviceId || "",
      label: device.label || `${fallbackPrefix} ${index + 1}`,
    }));
  },

  _storageKey() {
    const scope = this.el.dataset.preferenceScope || "anonymous";
    return `${STORAGE_KEY}:${scope}`;
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
    const preferences = this._preferencesFromForm();
    const missingAudio = preferences.audio && (payload.audioinput || []).length === 0;
    const missingVideo = preferences.video && (payload.videoinput || []).length === 0;

    if (missingAudio && missingVideo) {
      this._showWarning(t("No microphone or camera found. You can join receive-only."));
    } else if (missingAudio) {
      this._showWarning(t("No microphone found. Turn microphone off or retry."));
    } else if (missingVideo) {
      this._showWarning(t("No camera found. Turn camera off or retry."));
    }
  },

  _previewFailureMessage(error, preferences) {
    if (error?.code === "permission_denied") {
      return t("Permission denied. Retry after allowing access or join receive-only.");
    }

    switch (error?.name) {
      case "NotAllowedError":
      case "SecurityError":
        return t("Permission denied. Retry after allowing access or join receive-only.");
      case "NotFoundError":
      case "DevicesNotFoundError":
        return t("No matching microphone or camera was found. Check devices or join receive-only.");
      case "OverconstrainedError":
      case "ConstraintNotSatisfiedError":
        return t("Selected device is unavailable. Choose another device or retry.");
      case "NotReadableError":
      case "TrackStartError":
        return t("Device is already in use. Close the other app or retry.");
      default:
        if (!preferences.audio && !preferences.video) return t("Joining receive-only.");
        return error?.message || t("Could not access your microphone or camera.");
    }
  },
};

export default GroupCallPreJoinHook;
