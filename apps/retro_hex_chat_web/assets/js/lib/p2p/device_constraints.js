/**
 * getUserMedia constraint assembly for the group call — pure, no capture.
 *
 * Both the pre-join preview and the live call build the same audio/video
 * constraint object from an enabled flag and a chosen device id; this is that
 * assembly, so neither hook carries a private copy of it.
 *
 * @module p2p/device_constraints
 */
import { getAudioConstraints, getVideoConstraints } from "./media.js";

/**
 * Pin a constraint set to a specific device, or leave it as the default.
 *
 * @param {MediaTrackConstraints|boolean} base
 * @param {string|null} deviceId
 * @returns {MediaTrackConstraints|boolean}
 */
export function withDevice(base, deviceId) {
  if (!deviceId) return base;
  return { ...base, deviceId: { exact: deviceId } };
}

/**
 * The audio/video constraints for the enabled tracks, pinned to their devices.
 *
 * @param {{audio: boolean, video: boolean}} enabled
 * @param {{audioInputId?: string|null, videoInputId?: string|null}} devices
 * @returns {{audio: MediaTrackConstraints|boolean, video: MediaTrackConstraints|boolean}}
 */
export function captureConstraints(enabled, devices) {
  return {
    audio: enabled.audio ? withDevice(getAudioConstraints(), devices.audioInputId) : false,
    video: enabled.video ? withDevice(getVideoConstraints(), devices.videoInputId) : false,
  };
}
