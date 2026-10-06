/**
 * The microphone, away from LiveView.
 *
 * Recording is a small state machine over two browser objects — a media stream
 * and a MediaRecorder — and every interesting case is about letting go: the
 * ceiling that stops a recording nobody ended, the discard that throws the
 * audio away, and the teardown that has to release the microphone even when it
 * arrives in the middle of a take. A held microphone is a lit indicator on
 * somebody's phone, so "released" is the property under test throughout.
 */
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { MAX_DURATION_MS, createVoiceRecorder } from "../../../js/lib/uploads/voice_recorder.js";

function trackDouble() {
  return { kind: "audio", stop: vi.fn() };
}

function streamDouble(tracks) {
  return { getTracks: () => tracks };
}

function recorderDouble() {
  const instances = [];

  class MediaRecorderDouble {
    static isTypeSupported(type) {
      return type === "audio/webm;codecs=opus";
    }

    constructor(stream, options = {}) {
      this.stream = stream;
      this.mimeType = options.mimeType || "audio/webm";
      this.state = "inactive";
      instances.push(this);
    }

    start() {
      this.state = "recording";
    }

    stop() {
      this.state = "inactive";
      this.ondataavailable?.({ data: new Blob(["audio"], { type: this.mimeType }) });
      this.onstop?.();
    }
  }

  return { MediaRecorderDouble, instances };
}

function setup(overrides = {}) {
  const tracks = [trackDouble()];
  const stream = streamDouble(tracks);
  const { MediaRecorderDouble, instances } = recorderDouble();
  const getUserMedia = vi.fn(() => Promise.resolve(stream));
  const ports = {
    onState: vi.fn(),
    onRecorded: vi.fn(),
    onError: vi.fn(),
  };

  let clock = 1_000;

  const recorder = createVoiceRecorder({
    mediaDevices: { getUserMedia },
    Recorder: MediaRecorderDouble,
    now: () => clock,
    ...ports,
    ...overrides,
  });

  return {
    recorder,
    tracks,
    instances,
    getUserMedia,
    ...ports,
    advance(ms) {
      clock += ms;
      vi.advanceTimersByTime(ms);
    },
  };
}

beforeEach(() => {
  vi.useFakeTimers();
});

afterEach(() => {
  vi.useRealTimers();
});

describe("supported", () => {
  it("needs both a microphone and a recorder", () => {
    expect(setup().recorder.supported()).toBe(true);

    const noMic = createVoiceRecorder({ mediaDevices: null, Recorder: class {} });
    expect(noMic.supported()).toBe(false);

    const noRecorder = createVoiceRecorder({
      mediaDevices: { getUserMedia: () => {} },
      Recorder: null,
    });
    expect(noRecorder.supported()).toBe(false);
  });
});

describe("start", () => {
  it("asks for the microphone and records into a type the browser supports", async () => {
    const { recorder, getUserMedia, instances, onState } = setup();

    expect(await recorder.start()).toEqual({ ok: true });
    expect(getUserMedia).toHaveBeenCalledWith({ audio: true });
    expect(instances[0].mimeType).toBe("audio/webm;codecs=opus");
    expect(instances[0].state).toBe("recording");
    expect(onState).toHaveBeenCalledWith({ recording: true, elapsedMs: 0 });
  });

  it("reports the elapsed time while it runs", async () => {
    const { recorder, onState, advance } = setup();

    await recorder.start();
    onState.mockClear();
    advance(1_000);

    expect(onState).toHaveBeenLastCalledWith({ recording: true, elapsedMs: 1_000 });
  });

  function refused(name) {
    return () => Promise.reject(Object.assign(new Error(name), { name }));
  }

  it("says so when the person refuses the microphone", async () => {
    const { recorder, onError, onRecorded } = setup({
      mediaDevices: { getUserMedia: refused("NotAllowedError") },
    });

    expect(await recorder.start()).toEqual({ ok: false, reason: "denied" });
    expect(onError).toHaveBeenCalledWith("denied");
    expect(onRecorded).not.toHaveBeenCalled();
  });

  // No device, or one another program holds, is not the person's refusal and
  // must not send them to their permission settings.
  it.each(["NotFoundError", "NotReadableError", "AbortError"])(
    "says the microphone is unavailable on %s",
    async (name) => {
      const { recorder, onError } = setup({ mediaDevices: { getUserMedia: refused(name) } });

      expect(await recorder.start()).toEqual({ ok: false, reason: "unavailable" });
      expect(onError).toHaveBeenCalledWith("unavailable");
    },
  );

  it("gives the microphone back when the recorder refuses to start", async () => {
    class Refusing {
      static isTypeSupported() {
        return false;
      }

      constructor() {
        throw Object.assign(new Error("no"), { name: "NotSupportedError" });
      }
    }
    const { recorder, tracks, onError } = setup({ Recorder: Refusing });

    expect(await recorder.start()).toEqual({ ok: false, reason: "unsupported" });
    expect(tracks[0].stop).toHaveBeenCalledTimes(1);
    expect(onError).toHaveBeenCalledWith("unsupported");
    expect(recorder.recording()).toBe(false);
    expect(await recorder.start()).toEqual({ ok: false, reason: "unsupported" });
  });

  it("says so when the browser cannot record at all", async () => {
    const { recorder, onError } = setup({ Recorder: null });

    expect(await recorder.start()).toEqual({ ok: false, reason: "unsupported" });
    expect(onError).toHaveBeenCalledWith("unsupported");
  });

  it("does not start a second take over the first", async () => {
    const { recorder, getUserMedia } = setup();

    await recorder.start();
    expect(await recorder.start()).toEqual({ ok: false, reason: "busy" });
    expect(getUserMedia).toHaveBeenCalledTimes(1);
  });

  // The permission prompt is where a second tap lands: nothing is recording
  // yet, and a second request would open a second microphone nobody closes.
  it("does not ask twice while the browser is still asking", async () => {
    const { recorder, getUserMedia } = setup();

    const first = recorder.start();
    expect(await recorder.start()).toEqual({ ok: false, reason: "busy" });
    await first;

    expect(getUserMedia).toHaveBeenCalledTimes(1);
    expect(recorder.recording()).toBe(true);
  });

  it("can be asked again after the browser refused", async () => {
    const getUserMedia = vi
      .fn()
      .mockRejectedValueOnce(Object.assign(new Error("no"), { name: "NotAllowedError" }))
      .mockResolvedValueOnce(streamDouble([trackDouble()]));
    const { recorder } = setup({ mediaDevices: { getUserMedia } });

    await recorder.start();

    expect(await recorder.start()).toEqual({ ok: true });
  });
});

describe("a take abandoned while the browser is still asking", () => {
  // Discarded or torn down before the microphone arrived: when it does
  // arrive, it is handed straight back and nothing starts recording.
  it.each(["cancel", "destroy"])("releases the microphone that arrives after %s", async (end) => {
    const { recorder, tracks, instances, onState } = setup();

    const pending = recorder.start();
    recorder[end]();

    expect(await pending).toEqual({ ok: false, reason: "cancelled" });
    expect(tracks[0].stop).toHaveBeenCalledTimes(1);
    expect(instances).toHaveLength(0);
    expect(recorder.recording()).toBe(false);
    expect(onState).not.toHaveBeenCalledWith({ recording: true, elapsedMs: 0 });
  });
});

describe("stop", () => {
  it("hands over the recording, its length and its type", async () => {
    const { recorder, onRecorded, advance } = setup();

    await recorder.start();
    advance(7_400);
    recorder.stop();

    expect(onRecorded).toHaveBeenCalledTimes(1);
    const recorded = onRecorded.mock.calls[0][0];
    expect(recorded.durationMs).toBe(7_400);
    expect(recorded.contentType).toBe("audio/webm;codecs=opus");
    expect(recorded.file.name).toMatch(/^voice-\d{8}-\d{6}\.weba$/);
    expect(recorded.file.size).toBeGreaterThan(0);
  });

  it("releases the microphone", async () => {
    const { recorder, tracks } = setup();

    await recorder.start();
    recorder.stop();

    expect(tracks[0].stop).toHaveBeenCalledTimes(1);
    expect(recorder.recording()).toBe(false);
  });

  it("does nothing when nothing is being recorded", () => {
    const { recorder, onRecorded } = setup();

    recorder.stop();

    expect(onRecorded).not.toHaveBeenCalled();
  });
});

describe("the ceiling", () => {
  it("ends a take nobody ended, at the ceiling", async () => {
    const { recorder, instances, onRecorded, advance } = setup();

    await recorder.start();
    advance(MAX_DURATION_MS + 5_000);

    // The recorder itself is told to stop, not merely forgotten: a MediaRecorder
    // nobody stopped keeps the microphone on whatever this side believes.
    expect(instances[0].state).toBe("inactive");
    expect(onRecorded).toHaveBeenCalledTimes(1);
    expect(onRecorded.mock.calls[0][0].durationMs).toBe(MAX_DURATION_MS);
    expect(recorder.recording()).toBe(false);
  });

  // Absence: the ceiling stops the take once, not once per tick after it.
  it("stops once", async () => {
    const { recorder, onRecorded, advance } = setup();

    await recorder.start();
    advance(MAX_DURATION_MS * 2);

    expect(onRecorded).toHaveBeenCalledTimes(1);
  });
});

describe("cancel", () => {
  it("throws the audio away and still releases the microphone", async () => {
    const { recorder, tracks, onRecorded, onState, advance } = setup();

    await recorder.start();
    advance(3_000);
    recorder.cancel();

    expect(onRecorded).not.toHaveBeenCalled();
    expect(tracks[0].stop).toHaveBeenCalledTimes(1);
    expect(onState).toHaveBeenLastCalledWith({ recording: false, elapsedMs: 0 });
  });
});

describe("destroy", () => {
  // The mirror of mount: whatever a take acquired, this gives back — and it
  // arrives when the window is closing, so it hands nothing to a caller that
  // is no longer there.
  it("releases a take in progress without reporting it", async () => {
    const { recorder, tracks, onRecorded, advance } = setup();

    await recorder.start();
    advance(2_000);
    recorder.destroy();

    expect(tracks[0].stop).toHaveBeenCalledTimes(1);
    expect(onRecorded).not.toHaveBeenCalled();
    expect(recorder.recording()).toBe(false);
  });

  it("keeps the clock from ticking afterwards", async () => {
    const { recorder, onState, advance } = setup();

    await recorder.start();
    recorder.destroy();
    onState.mockClear();
    advance(5_000);

    expect(onState).not.toHaveBeenCalled();
  });

  it("is safe with nothing in flight", () => {
    expect(() => setup().recorder.destroy()).not.toThrow();
  });
});
