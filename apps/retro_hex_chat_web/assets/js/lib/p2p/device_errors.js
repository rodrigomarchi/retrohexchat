/**
 * Turning a getUserMedia failure or an empty device list into a user message.
 *
 * Pure but translated: the returned strings go through `t()` so a locale that
 * is loaded reads them in its own language. No DOM — the pre-join hook writes
 * the result into its warning panel.
 *
 * @module p2p/device_errors
 */
import { t } from "../i18n.js";

/**
 * Why a preview or capture failed, phrased for someone who can retry or join
 * receive-only.
 *
 * @param {(Error & {code?: string, name?: string})|null} error
 * @param {{audio: boolean, video: boolean}} preferences
 * @returns {string}
 */
export function mediaErrorMessage(error, preferences) {
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
}

/**
 * A warning when a wanted device is missing from the enumerated list, or null
 * when everything wanted is present.
 *
 * @param {{audio: boolean, video: boolean}} preferences
 * @param {{audioinput?: unknown[], videoinput?: unknown[]}} devices
 * @returns {string|null}
 */
export function missingDeviceWarning(preferences, devices) {
  const missingAudio = preferences.audio && (devices.audioinput || []).length === 0;
  const missingVideo = preferences.video && (devices.videoinput || []).length === 0;

  if (missingAudio && missingVideo) {
    return t("No microphone or camera found. You can join receive-only.");
  }
  if (missingAudio) {
    return t("No microphone found. Turn microphone off or retry.");
  }
  if (missingVideo) {
    return t("No camera found. Turn camera off or retry.");
  }
  return null;
}
