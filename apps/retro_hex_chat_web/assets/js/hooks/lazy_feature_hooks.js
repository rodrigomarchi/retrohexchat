import { lazyHook } from "./lazy_hook";

export const lazyFeatureHooks = {
  FileTransferHook: lazyHook(() => import("./p2p/file_transfer_hook")),
  GameCanvasHook: lazyHook(() => import("./games/game_canvas_hook")),
  GameWebRTCHook: lazyHook(() => import("./games/game_webrtc_hook")),
  MediaHook: lazyHook(() => import("./p2p/media_hook")),
  P2PDiagramHook: lazyHook(() => import("./p2p/p2p_diagram_hook")),
  WebRTCHook: lazyHook(() => import("./p2p/webrtc_hook")),
};
