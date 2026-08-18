/**
 * Conference tile copy and state decisions — pure, no DOM.
 *
 * The hook owns the tile elements and the participant maps; the decisions it
 * used to make inline while writing them — which empty state the local tile is
 * in, what that state reads, and the media flags and labels a participant tile
 * shows — live here so they can be tested without a grid.
 *
 * Strings that were translated in the hook stay translated; the aria labels
 * that were literal template strings stay literal.
 *
 * @module group_call/tiles
 */
import { t } from "../i18n.js";

/**
 * Which empty state the local tile is in.
 *
 * @param {object} params
 * @param {boolean} params.screenShareActive
 * @param {boolean} params.audioEnabled
 * @param {boolean} params.videoEnabled
 * @returns {"screen-share"|"receive-only"|"camera-off"|"starting"}
 */
export function localEmptyState({ screenShareActive, audioEnabled, videoEnabled }) {
  if (screenShareActive === true) return "screen-share";
  if (audioEnabled === false && videoEnabled === false) return "receive-only";
  if (videoEnabled === false) return "camera-off";
  return "starting";
}

/**
 * The title and detail for a local empty state.
 *
 * @param {string} state
 * @returns {{title: string, detail: string}}
 */
export function localEmptyStateCopy(state) {
  switch (state) {
    case "screen-share":
      return {
        title: t("Sharing screen"),
        detail: t("Your screen is replacing the camera feed."),
      };
    case "receive-only":
      return {
        title: t("Receive-only mode"),
        detail: t("Your microphone and camera are off."),
      };
    case "camera-off":
      return {
        title: t("Camera off"),
        detail: t("Your camera is not being sent."),
      };
    default:
      return {
        title: t("Camera preview starting"),
        detail: t("Your local preview appears here when the camera is ready."),
      };
  }
}

/**
 * The media flags, name and focus label a participant tile shows.
 *
 * @param {object} participant the participant record
 * @param {string|null} [screenSource] the tile's `data-track-source`
 * @returns {{audio: boolean, video: boolean, screen: boolean, name: string, label: string}}
 */
export function participantTileMedia(participant, screenSource = null) {
  const media = participant.media_state || {};
  const audio = media.audio !== false;
  const video = media.video !== false;
  const screen = media.screen === true || screenSource === "screen";
  const nickname = participant.nickname || t("Remote");

  const name = screen ? t("%{nickname}'s screen", { nickname }) : nickname;
  const label = screen ? `Focus ${nickname}'s shared screen` : `Focus ${nickname}`;

  return { audio, video, screen, name, label };
}
