import { lazyFeatureHook } from "./lazy_feature_hook";

export const lazyFeatureHooks = {
  FileTransferHook: lazyFeatureHook({
    name: "FileTransferHook",
    loader: () => import("./p2p/file_transfer_hook"),
    serverEvents: ["ft_config", "ft_accept", "ft_reject", "ft_cancel", "ft_retry"],
    readyEvent: "file_transfer_ready",
    reason: "P2P file transfer is a heavy feature not needed for the initial chat shell.",
  }),
  P2PDiagramHook: lazyFeatureHook({
    name: "P2PDiagramHook",
    loader: () => import("./p2p/p2p_diagram_hook"),
    reason: "P2P diagram animation is visual-only and not needed for the initial chat shell.",
  }),
  LobbyWebRTCHook: lazyFeatureHook({
    name: "LobbyWebRTCHook",
    loader: () => import("./lobby/lobby_webrtc_hook"),
    serverEvents: [
      "lobby_start_offer",
      "lobby_start_answer",
      "lobby_restart",
      "lobby_signal",
      "lobby_renegotiate",
    ],
    readyEvent: "lobby_webrtc_ready",
    reason: "P2P session WebRTC signaling is a heavy session feature.",
  }),
  LobbyMediaHook: lazyFeatureHook({
    name: "LobbyMediaHook",
    loader: () => import("./lobby/lobby_media_hook"),
    serverEvents: [
      "lobby_media_start_audio",
      "lobby_media_start_video",
      "lobby_media_end_call",
      "lobby_media_peer_muted",
      "lobby_media_peer_camera",
      "lobby_media_set_preset",
      "lobby_media_join",
    ],
    readyEvent: "lobby_media_hook_ready",
    reason: "P2P session media capture is only needed inside an active lobby.",
  }),
  GroupCallWebRTCHook: lazyFeatureHook({
    name: "GroupCallWebRTCHook",
    loader: () => import("./group_call/group_call_webrtc_hook"),
    serverEvents: [],
    readyEvent: "group_call_webrtc_ready",
    reason: "Group-call SFU signaling and media capture are only needed inside a call window.",
  }),
  GroupCallPreJoinHook: lazyFeatureHook({
    name: "GroupCallPreJoinHook",
    loader: () => import("./group_call/group_call_prejoin_hook"),
    serverEvents: [],
    reason: "Group-call device preview is only needed while the pre-join dialog is open.",
  }),
  P2PSetupHook: lazyFeatureHook({
    name: "P2PSetupHook",
    loader: () => import("./group_call/group_call_prejoin_hook"),
    serverEvents: [],
    reason: "P2P setup device preview is only needed while accepting an invite.",
  }),
  LobbyGameCanvasHook: lazyFeatureHook({
    name: "LobbyGameCanvasHook",
    loader: () => import("./lobby/lobby_game_canvas_hook"),
    serverEvents: ["lobby_game_start", "lobby_game_end"],
    readyEvent: "lobby_game_canvas_ready",
    reason: "P2P session game canvas and engine loading are heavy features.",
  }),
  SpaceCanvasHook: lazyFeatureHook({
    name: "SpaceCanvasHook",
    loader: () => import("./space/space_canvas_hook"),
    serverEvents: [],
    reason: "Virtual-space canvas and engine are only needed inside a space session.",
  }),
};
