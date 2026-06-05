import { createRtcMediaHook } from "../../lib/p2p/rtc_media_hook_factory.js";

const MediaHook = createRtcMediaHook({
  webrtcElementId: "p2p-webrtc",
  pcReadyEvent: "media_pc_ready",
  pcClosedEvent: "media_pc_closed",
  actionAttribute: "data-media-action",
  upgradeMode: "request",
  elementIds: {
    remoteVideo: "remote-video",
    localVideo: "local-video",
    remoteAudio: "remote-audio",
  },
  serverEvents: {
    startAudio: "media_start_audio",
    startVideo: "media_start_video",
    endCall: "media_end_call",
    peerMuted: "media_peer_muted",
    peerCamera: "media_peer_camera",
    upgradeAccepted: "media_upgrade_accepted",
    upgradeRejected: "media_upgrade_rejected",
    upgradeFailed: "media_upgrade_failed",
    setPreset: "media_set_preset",
  },
  clientEvents: {
    ready: "media_hook_ready",
    error: "media_error",
    callStarted: "media_call_started",
    callEnded: "media_call_ended",
    muteChanged: "media_mute_changed",
    cameraChanged: "media_camera_changed",
    qualityUpdate: "media_quality_update",
    durationTick: "media_duration_tick",
    requestUpgrade: "media_request_upgrade",
    devicesListed: "media_devices_listed",
    deviceFallback: "media_device_fallback",
  },
});

export default MediaHook;
