import { describe, it, expect, vi, beforeEach } from "vitest";
import {
  getAudioConstraints,
  getVideoConstraints,
  categorizeMediaError,
  acquireMedia,
  addMediaTracks,
  toggleTrack,
  stopAllTracks,
  formatDuration,
  mapQualityLevel,
  BITRATE_PRESETS,
  QUALITY_LABELS,
  applyBitratePreset,
  enumerateDevices,
  switchAudioInput,
  switchVideoInput,
  supportsSetSinkId,
  supportsPiP,
  togglePiP,
  setCodecPreferences,
} from "../../../js/lib/p2p/media.js";

// --- Media Acquisition (T009) ---

describe("Media Acquisition", () => {
  describe("getAudioConstraints", () => {
    it("returns echo cancellation and noise suppression", () => {
      const constraints = getAudioConstraints();
      expect(constraints).toEqual({
        echoCancellation: true,
        noiseSuppression: true,
      });
    });
  });

  describe("getVideoConstraints", () => {
    it("returns 640x480 user-facing camera constraints", () => {
      const constraints = getVideoConstraints();
      expect(constraints).toEqual({
        width: { ideal: 640 },
        height: { ideal: 480 },
        facingMode: "user",
      });
    });
  });

  describe("categorizeMediaError", () => {
    it("maps NotAllowedError to permission_denied", () => {
      const error = new DOMException("Permission denied", "NotAllowedError");
      const result = categorizeMediaError(error);
      expect(result.code).toBe("permission_denied");
      expect(result.message).toContain("Microphone permission denied");
    });

    it("maps video NotAllowedError to camera permission guidance", () => {
      const error = new DOMException("Permission denied", "NotAllowedError");
      const result = categorizeMediaError(error, { audio: true, video: true });
      expect(result.code).toBe("permission_denied");
      expect(result.message).toContain("Camera permission denied");
    });

    it("maps NotReadableError to not_readable", () => {
      const error = new DOMException("Device in use", "NotReadableError");
      const result = categorizeMediaError(error);
      expect(result.code).toBe("not_readable");
      expect(result.message).toContain("Camera in use");
    });

    it("maps audio NotReadableError to microphone guidance", () => {
      const error = new DOMException("Device in use", "NotReadableError");
      const result = categorizeMediaError(error, { audio: true });
      expect(result.code).toBe("not_readable");
      expect(result.message).toContain("Microphone in use");
    });

    it("maps NotFoundError to not_found", () => {
      const error = new DOMException("No device", "NotFoundError");
      const result = categorizeMediaError(error);
      expect(result.code).toBe("not_found");
      expect(result.message).toContain("No camera found");
    });

    it("maps audio NotFoundError to missing microphone guidance", () => {
      const error = new DOMException("No device", "NotFoundError");
      const result = categorizeMediaError(error, { audio: true });
      expect(result.code).toBe("not_found");
      expect(result.message).toContain("No microphone found");
    });

    it("maps unknown errors with original message", () => {
      const error = new Error("Something broke");
      const result = categorizeMediaError(error);
      expect(result.code).toBe("unknown");
      expect(result.message).toContain("Something broke");
    });
  });

  describe("acquireMedia", () => {
    it("returns media stream on success", async () => {
      const mockStream = { getTracks: () => [] };
      navigator.mediaDevices = {
        getUserMedia: vi.fn().mockResolvedValue(mockStream),
      };

      const stream = await acquireMedia({ audio: true });
      expect(stream).toBe(mockStream);
      expect(navigator.mediaDevices.getUserMedia).toHaveBeenCalledWith({
        audio: true,
      });
    });

    it("throws categorized error on failure", async () => {
      navigator.mediaDevices = {
        getUserMedia: vi.fn().mockRejectedValue(new DOMException("Denied", "NotAllowedError")),
      };

      await expect(acquireMedia({ audio: true })).rejects.toEqual({
        code: "permission_denied",
        message: expect.stringContaining("Microphone permission denied"),
      });
    });

    it("throws camera guidance when video acquisition is denied", async () => {
      navigator.mediaDevices = {
        getUserMedia: vi.fn().mockRejectedValue(new DOMException("Denied", "NotAllowedError")),
      };

      await expect(acquireMedia({ audio: true, video: true })).rejects.toEqual({
        code: "permission_denied",
        message: expect.stringContaining("Camera permission denied"),
      });
    });

    it("throws microphone missing guidance for audio-only NotFoundError", async () => {
      navigator.mediaDevices = {
        getUserMedia: vi.fn().mockRejectedValue(new DOMException("Missing", "NotFoundError")),
      };

      await expect(acquireMedia({ audio: true })).rejects.toEqual({
        code: "not_found",
        message: expect.stringContaining("No microphone found"),
      });
    });
  });
});

// --- Track Management (T010) ---

describe("Track Management", () => {
  describe("addMediaTracks", () => {
    it("adds all tracks from stream to peer connection", () => {
      const track1 = { kind: "audio" };
      const track2 = { kind: "video" };
      const sender1 = { track: track1 };
      const sender2 = { track: track2 };
      const stream = { getTracks: () => [track1, track2] };
      const pc = {
        addTrack: vi.fn().mockReturnValueOnce(sender1).mockReturnValueOnce(sender2),
      };

      const senders = addMediaTracks(pc, stream);
      expect(pc.addTrack).toHaveBeenCalledTimes(2);
      expect(senders).toEqual([sender1, sender2]);
    });
  });

  describe("toggleTrack", () => {
    it("enables audio tracks", () => {
      const track = { kind: "audio", enabled: false };
      const stream = {
        getAudioTracks: () => [track],
        getVideoTracks: () => [],
      };

      const result = toggleTrack(stream, "audio", true);
      expect(track.enabled).toBe(true);
      expect(result).toBe(true);
    });

    it("disables video tracks", () => {
      const track = { kind: "video", enabled: true };
      const stream = {
        getAudioTracks: () => [],
        getVideoTracks: () => [track],
      };

      const result = toggleTrack(stream, "video", false);
      expect(track.enabled).toBe(false);
      expect(result).toBe(false);
    });
  });

  describe("stopAllTracks", () => {
    it("stops all tracks in the stream", () => {
      const track1 = { stop: vi.fn() };
      const track2 = { stop: vi.fn() };
      const stream = { getTracks: () => [track1, track2] };

      stopAllTracks(stream);
      expect(track1.stop).toHaveBeenCalled();
      expect(track2.stop).toHaveBeenCalled();
    });
  });

  describe("formatDuration", () => {
    it("formats 0 seconds as 00:00:00", () => {
      const now = Date.now();
      expect(formatDuration(now)).toBe("00:00:00");
    });

    it("formats 15 seconds correctly", () => {
      const start = Date.now() - 15000;
      expect(formatDuration(start)).toBe("00:00:15");
    });

    it("formats 65 seconds as 00:01:05", () => {
      const start = Date.now() - 65000;
      expect(formatDuration(start)).toBe("00:01:05");
    });

    it("formats 3661 seconds as 01:01:01", () => {
      const start = Date.now() - 3661000;
      expect(formatDuration(start)).toBe("01:01:01");
    });
  });
});

// --- Quality Monitoring (T030) ---

describe("Quality Monitoring", () => {
  describe("mapQualityLevel", () => {
    it("returns excellent for low loss and rtt", () => {
      expect(mapQualityLevel({ packetLoss: 0.5, roundTripTime: 0.05 })).toBe("excellent");
    });

    it("returns good for moderate loss and rtt", () => {
      expect(mapQualityLevel({ packetLoss: 2, roundTripTime: 0.15 })).toBe("good");
    });

    it("returns fair for higher loss and rtt", () => {
      expect(mapQualityLevel({ packetLoss: 5, roundTripTime: 0.3 })).toBe("fair");
    });

    it("returns poor for worst conditions", () => {
      expect(mapQualityLevel({ packetLoss: 15, roundTripTime: 0.5 })).toBe("poor");
    });
  });

  describe("BITRATE_PRESETS", () => {
    it("has high preset with 1.5Mbps video", () => {
      expect(BITRATE_PRESETS.high.video).toBe(1_500_000);
      expect(BITRATE_PRESETS.high.audio).toBe(128_000);
    });

    it("has medium preset with 500Kbps video", () => {
      expect(BITRATE_PRESETS.medium.video).toBe(500_000);
    });

    it("has low preset with 150Kbps video", () => {
      expect(BITRATE_PRESETS.low.video).toBe(150_000);
    });
  });

  describe("QUALITY_LABELS", () => {
    it("has English labels for all levels", () => {
      expect(QUALITY_LABELS.excellent).toBe("Excellent");
      expect(QUALITY_LABELS.good).toBe("Good");
      expect(QUALITY_LABELS.fair).toBe("Fair");
      expect(QUALITY_LABELS.poor).toBe("Poor");
    });
  });

  describe("applyBitratePreset", () => {
    it("sets maxBitrate on all senders", async () => {
      const params = { encodings: [{}] };
      const sender = {
        track: { kind: "video" },
        getParameters: () => params,
        setParameters: vi.fn(),
      };
      const pc = { getSenders: () => [sender] };

      await applyBitratePreset(pc, "low");
      expect(sender.setParameters).toHaveBeenCalled();
      const setParams = sender.setParameters.mock.calls[0][0];
      expect(setParams.encodings[0].maxBitrate).toBe(150_000);
    });
  });
});

// --- Device Management (T041) ---

describe("Device Management", () => {
  beforeEach(() => {
    navigator.mediaDevices = {
      getUserMedia: vi.fn(),
      enumerateDevices: vi.fn(),
    };
  });

  describe("enumerateDevices", () => {
    it("groups devices by kind", async () => {
      navigator.mediaDevices.enumerateDevices.mockResolvedValue([
        { deviceId: "1", kind: "audioinput", label: "Mic" },
        { deviceId: "2", kind: "audiooutput", label: "Speaker" },
        { deviceId: "3", kind: "videoinput", label: "Camera" },
      ]);

      const result = await enumerateDevices();
      expect(result.audioinput).toHaveLength(1);
      expect(result.audiooutput).toHaveLength(1);
      expect(result.videoinput).toHaveLength(1);
    });
  });

  describe("switchAudioInput", () => {
    it("replaces audio track on sender", async () => {
      const newTrack = { kind: "audio" };
      const newStream = { getAudioTracks: () => [newTrack] };
      navigator.mediaDevices.getUserMedia.mockResolvedValue(newStream);

      const oldTrack = {
        kind: "audio",
        stop: vi.fn(),
        getSettings: () => ({ deviceId: "old" }),
      };
      const stream = {
        getAudioTracks: () => [oldTrack],
        removeTrack: vi.fn(),
        addTrack: vi.fn(),
      };
      const sender = {
        track: { kind: "audio" },
        replaceTrack: vi.fn().mockResolvedValue(undefined),
      };

      const result = await switchAudioInput(stream, [sender], "new-device");
      expect(sender.replaceTrack).toHaveBeenCalledWith(newTrack);
      expect(oldTrack.stop).toHaveBeenCalled();
      expect(result).toBe(stream);
    });
  });

  describe("switchVideoInput", () => {
    it("replaces video track on sender", async () => {
      const newTrack = { kind: "video" };
      const newStream = { getVideoTracks: () => [newTrack] };
      navigator.mediaDevices.getUserMedia.mockResolvedValue(newStream);

      const oldTrack = { kind: "video", stop: vi.fn() };
      const stream = {
        getVideoTracks: () => [oldTrack],
        removeTrack: vi.fn(),
        addTrack: vi.fn(),
      };
      const sender = {
        track: { kind: "video" },
        replaceTrack: vi.fn().mockResolvedValue(undefined),
      };

      const result = await switchVideoInput(stream, [sender], "new-camera");
      expect(sender.replaceTrack).toHaveBeenCalledWith(newTrack);
      expect(result).toBe(stream);
    });
  });

  describe("supportsSetSinkId", () => {
    it("returns boolean based on HTMLMediaElement support", () => {
      const result = supportsSetSinkId();
      expect(typeof result).toBe("boolean");
    });
  });
});

// --- Picture-in-Picture (T047) ---

describe("Picture-in-Picture", () => {
  describe("supportsPiP", () => {
    it("returns boolean based on document.pictureInPictureEnabled", () => {
      const result = supportsPiP();
      expect(typeof result).toBe("boolean");
    });
  });

  describe("togglePiP", () => {
    it("calls requestPictureInPicture when not in PiP", async () => {
      const videoEl = {
        requestPictureInPicture: vi.fn().mockResolvedValue({}),
      };
      // No current PiP element
      Object.defineProperty(document, "pictureInPictureElement", {
        value: null,
        writable: true,
        configurable: true,
      });

      await togglePiP(videoEl);
      expect(videoEl.requestPictureInPicture).toHaveBeenCalled();
    });

    it("calls exitPictureInPicture when already in PiP", async () => {
      const videoEl = {};
      Object.defineProperty(document, "pictureInPictureElement", {
        value: videoEl,
        writable: true,
        configurable: true,
      });
      document.exitPictureInPicture = vi.fn().mockResolvedValue(undefined);

      await togglePiP(videoEl);
      expect(document.exitPictureInPicture).toHaveBeenCalled();
    });
  });
});

// --- Codec Preferences (T053) ---

describe("Codec Preferences", () => {
  describe("setCodecPreferences", () => {
    it("orders H.264 before VP8 for video transceivers", () => {
      const codecs = [
        { mimeType: "video/VP8" },
        { mimeType: "video/H264" },
        { mimeType: "video/VP9" },
      ];
      const transceiver = {
        sender: { track: { kind: "video" } },
        receiver: { track: { kind: "video" } },
        setCodecPreferences: vi.fn(),
      };

      // Mock RTCRtpReceiver.getCapabilities
      globalThis.RTCRtpReceiver = {
        getCapabilities: vi.fn().mockReturnValue({ codecs }),
      };

      const pc = { getTransceivers: () => [transceiver] };
      setCodecPreferences(pc);

      expect(transceiver.setCodecPreferences).toHaveBeenCalled();
      const ordered = transceiver.setCodecPreferences.mock.calls[0][0];
      expect(ordered[0].mimeType).toBe("video/H264");
    });

    it("no-ops when setCodecPreferences not supported", () => {
      const transceiver = {
        sender: { track: { kind: "audio" } },
        receiver: { track: { kind: "audio" } },
        // No setCodecPreferences method
      };
      const pc = { getTransceivers: () => [transceiver] };

      // Should not throw
      setCodecPreferences(pc);
    });
  });
});
