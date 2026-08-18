/**
 * Conference local-media state decisions — pure, no capture.
 *
 * The hook owns the RTCPeerConnection and the capture; whether a desired media
 * state is actually met by the live tracks, and whether new tracks must be
 * acquired on demand, are decided here against plain flags.
 *
 * @module group_call/media_state
 */

/** The desired media state carried on the element's dataset. */
export function mediaStateFromDataset(dataset) {
  return {
    audio: dataset.audio !== "false",
    video: dataset.video !== "false",
  };
}

/** Whether any track in the list is still live (not ended). */
export function hasLiveTrack(tracks) {
  return (tracks || []).some((track) => track.readyState !== "ended");
}

/**
 * Whether new local tracks must be captured to meet the desired state.
 *
 * @param {{audio: boolean, video: boolean}} desired
 * @param {boolean} hasAudio a live local audio track exists
 * @param {boolean} hasVideo a live local video track exists
 * @returns {boolean}
 */
export function needsOnDemandMedia(desired, hasAudio, hasVideo) {
  return (desired.audio && !hasAudio) || (desired.video && !hasVideo);
}

/**
 * The media state actually in effect: desired, narrowed to what the live tracks
 * provide.
 *
 * @param {{audio: boolean, video: boolean}} desired
 * @param {boolean} hasAudio
 * @param {boolean} hasVideo
 * @returns {{audio: boolean, video: boolean}}
 */
export function actualMediaState(desired, hasAudio, hasVideo) {
  return {
    audio: desired.audio && hasAudio,
    video: desired.video && hasVideo,
  };
}
