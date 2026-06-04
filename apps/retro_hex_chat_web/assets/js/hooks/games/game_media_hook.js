import { createRtcMediaHook } from "../../lib/p2p/rtc_media_hook_factory.js";

const GameMediaHook = createRtcMediaHook({
  webrtcElementId: "game-webrtc",
  pcReadyEvent: "game_media_pc_ready",
  pcClosedEvent: "game_media_pc_closed",
  actionAttribute: "data-game-media-action",
  upgradeMode: "local",
  elementIds: {
    remoteVideo: "game-remote-video",
    localVideo: "game-local-video",
    remoteAudio: "game-remote-audio",
  },
  serverEvents: {
    startAudio: "game_media_start_audio",
    startVideo: "game_media_start_video",
    endCall: "game_media_end_call",
    peerMuted: "game_media_peer_muted",
    peerCamera: "game_media_peer_camera",
    setPreset: "game_media_set_preset",
  },
  clientEvents: {
    ready: "game_media_hook_ready",
    error: "game_media_error",
    callStarted: "game_media_call_started",
    callEnded: "game_media_call_ended",
    muteChanged: "game_media_mute_changed",
    cameraChanged: "game_media_camera_changed",
    qualityUpdate: "game_media_quality_update",
    durationTick: "game_media_duration_tick",
    requestUpgrade: "game_media_request_upgrade",
    devicesListed: "game_media_devices_listed",
    deviceFallback: "game_media_device_fallback",
  },
});

export default GameMediaHook;
