import { createRtcMediaHook } from "../../lib/p2p/rtc_media_hook_factory.js";

/**
 * Media hook for the universal lobby.
 *
 * Reuses the shared RTC media factory but in *self-controlled* mode: each peer
 * starts/stops their own mic and camera independently (no bilateral consent),
 * reusing the persistent RTCPeerConnection owned by LobbyWebRTCHook. Adding a
 * camera track simply triggers renegotiation on the shared connection.
 */
const LobbyMediaHook = createRtcMediaHook({
  webrtcElementId: "lobby-webrtc",
  pcReadyEvent: "lobby_media_pc_ready",
  pcClosedEvent: "lobby_media_pc_closed",
  actionAttribute: "data-lobby-media-action",
  upgradeMode: "local",
  autoJoin: true,
  elementIds: {
    remoteVideo: "lobby-remote-video",
    localVideo: "lobby-local-video",
    remoteAudio: "lobby-remote-audio",
  },
  serverEvents: {
    startAudio: "lobby_media_start_audio",
    startVideo: "lobby_media_start_video",
    endCall: "lobby_media_end_call",
    peerMuted: "lobby_media_peer_muted",
    peerCamera: "lobby_media_peer_camera",
    setPreset: "lobby_media_set_preset",
    joinCall: "lobby_media_join",
  },
  clientEvents: {
    ready: "lobby_media_hook_ready",
    error: "lobby_media_error",
    callStarted: "lobby_media_call_started",
    callEnded: "lobby_media_call_ended",
    muteChanged: "lobby_media_mute_changed",
    cameraChanged: "lobby_media_camera_changed",
    qualityUpdate: "lobby_media_quality_update",
    statsUpdate: "lobby_media_stats",
    durationTick: "lobby_media_duration_tick",
    devicesListed: "lobby_media_devices_listed",
    deviceFallback: "lobby_media_device_fallback",
  },
});

export default LobbyMediaHook;
