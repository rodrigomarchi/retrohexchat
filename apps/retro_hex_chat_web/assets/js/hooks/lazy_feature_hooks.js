import { lazyFeatureHook } from "./lazy_feature_hook";

export const lazyFeatureHooks = {
  FileTransferHook: lazyFeatureHook({
    name: "FileTransferHook",
    loader: () => import("./p2p/file_transfer_hook"),
    serverEvents: [
      "ft_channel_ready",
      "ft_config",
      "ft_accept",
      "ft_reject",
      "ft_cancel",
      "ft_retry",
    ],
    safeWithoutReady: true,
    safeWithoutReadyReason:
      "FileTransferHook reads config and existing DataChannel state from DOM/peer element on mount.",
    reason: "P2P file transfer is a heavy feature not needed for the initial chat shell.",
  }),
  GameCanvasHook: lazyFeatureHook({
    name: "GameCanvasHook",
    loader: () => import("./games/game_canvas_hook"),
    serverEvents: ["game_start", "game_end"],
    safeWithoutReady: true,
    safeWithoutReadyReason:
      "GameCanvasHook reads game_id/is_host from dataset and handles game_end as a terminal cleanup event.",
    reason: "Game canvas and engine loading are heavy game-session features.",
  }),
  GameWebRTCHook: lazyFeatureHook({
    name: "GameWebRTCHook",
    loader: () => import("./games/game_webrtc_hook"),
    serverEvents: ["game_start_offer", "game_start_answer", "game_signal"],
    readyEvent: "game_webrtc_ready",
    reason: "Game WebRTC signaling is a heavy game-session feature.",
  }),
  MediaHook: lazyFeatureHook({
    name: "MediaHook",
    loader: () => import("./p2p/media_hook"),
    serverEvents: [
      "media_start_audio",
      "media_start_video",
      "media_end_call",
      "media_peer_muted",
      "media_peer_camera",
      "media_upgrade_accepted",
      "media_upgrade_rejected",
      "media_set_preset",
    ],
    safeWithoutReady: true,
    safeWithoutReadyReason:
      "MediaHook is mounted inside the media controls UI and reads the active PeerConnection from WebRTCHook.",
    reason:
      "Media capture and controls are heavy P2P features not needed for the initial chat shell.",
  }),
  P2PDiagramHook: lazyFeatureHook({
    name: "P2PDiagramHook",
    loader: () => import("./p2p/p2p_diagram_hook"),
    reason: "P2P diagram animation is visual-only and not needed for the initial chat shell.",
  }),
  WebRTCHook: lazyFeatureHook({
    name: "WebRTCHook",
    loader: () => import("./p2p/webrtc_hook"),
    serverEvents: ["p2p_start_offer", "p2p_start_answer", "p2p_signal"],
    safeWithoutReady: true,
    safeWithoutReadyReason:
      "Existing P2P WebRTC flow predates the ready protocol; Phase 4 must decide whether to add p2p_webrtc_ready.",
    reason:
      "P2P WebRTC signaling is a heavy session feature not needed for the initial chat shell.",
  }),
};
