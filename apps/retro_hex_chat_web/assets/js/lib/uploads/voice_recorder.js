/**
 * Recording a voice message, with nothing of LiveView in it.
 *
 * Two browser objects do the work — a media stream and a MediaRecorder — and
 * everything here is about giving them back. A stream left open is a lit
 * recording indicator on somebody's phone, so the stream is released on every
 * exit: the take that finished, the take that was discarded, the take that ran
 * into the ceiling, and the window that closed in the middle of one — or while
 * the browser was still asking for permission, which is when a second tap or a
 * discard lands before there is anything recording to stop.
 *
 * The ceiling is the same minute the server enforces. The recorder stops
 * itself there rather than letting a take run until the upload is refused,
 * because the person holding the phone should hear the end from the interface,
 * not from an error afterwards.
 */

import { log } from "../logger.js";

export const MAX_DURATION_MS = 60_000;

const TICK_MS = 250;

// Chromium and Firefox record WebM/Opus, Safari MP4/AAC. The browser picks the
// first of these it can actually produce; an empty answer means it has its own
// default and asking for one would only fail.
const PREFERRED_TYPES = [
  "audio/webm;codecs=opus",
  "audio/webm",
  "audio/mp4",
  "audio/ogg;codecs=opus",
];

// A recording is named for what it is and when it happened, and the extension
// has to match the container or the file is filed as a video: `.webm` holds
// either, `.weba` holds only audio.
const EXTENSIONS = {
  "audio/webm": "weba",
  "audio/ogg": "ogg",
  "audio/mp4": "m4a",
  "audio/mpeg": "mp3",
  "audio/wav": "wav",
};

function baseType(contentType) {
  return String(contentType || "")
    .split(";")[0]
    .trim()
    .toLowerCase();
}

function extensionFor(contentType) {
  return EXTENSIONS[baseType(contentType)] || "weba";
}

function pad(value, size = 2) {
  return String(value).padStart(size, "0");
}

// The browser names why it gave no microphone. Only a refusal is the person's
// answer; everything else — no device, a device another program holds — is
// the machine's, and saying "you refused" there sends them to the wrong fix.
const REFUSALS = new Set(["NotAllowedError", "SecurityError"]);

function refusal(error) {
  return REFUSALS.has(error?.name) ? "denied" : "unavailable";
}

function recordingName(date, contentType) {
  const stamp =
    `${date.getFullYear()}${pad(date.getMonth() + 1)}${pad(date.getDate())}` +
    `-${pad(date.getHours())}${pad(date.getMinutes())}${pad(date.getSeconds())}`;

  return `voice-${stamp}.${extensionFor(contentType)}`;
}

export function createVoiceRecorder(deps = {}) {
  const mediaDevices =
    deps.mediaDevices ?? (typeof navigator === "undefined" ? null : navigator.mediaDevices);
  const Recorder = deps.Recorder ?? globalThis.MediaRecorder ?? null;
  const FileClass = deps.File ?? globalThis.File;
  const now = deps.now ?? (() => Date.now());
  const onState = deps.onState ?? (() => {});
  const onRecorded = deps.onRecorded ?? (() => {});
  const onError = deps.onError ?? (() => {});

  let recorder = null;
  let stream = null;
  let ticker = null;
  let chunks = [];
  let startedAt = 0;
  let stoppedAt = 0;
  let discarding = false;
  let asking = false;
  let abandoned = false;

  function supported() {
    return Boolean(mediaDevices?.getUserMedia && Recorder);
  }

  function recording() {
    return recorder !== null;
  }

  function preferredType() {
    if (typeof Recorder?.isTypeSupported !== "function") return "";

    return PREFERRED_TYPES.find((type) => Recorder.isTypeSupported(type)) || "";
  }

  function releaseStream() {
    stream?.getTracks?.().forEach((track) => track.stop());
    stream = null;
  }

  function stopTicking() {
    if (ticker !== null) {
      clearInterval(ticker);
      ticker = null;
    }
  }

  function elapsed() {
    const end = stoppedAt || now();
    return Math.min(Math.max(end - startedAt, 0), MAX_DURATION_MS);
  }

  function tick() {
    onState({ recording: true, elapsedMs: elapsed() });

    if (now() - startedAt >= MAX_DURATION_MS) stop();
  }

  function finish() {
    const duration = elapsed();
    const contentType = recorder?.mimeType || baseType(chunks[0]?.type) || "audio/webm";
    const collected = chunks;
    const discarded = discarding;

    recorder = null;
    chunks = [];
    stopTicking();
    releaseStream();
    onState({ recording: false, elapsedMs: 0 });

    if (discarded || collected.length === 0) return;

    const blob = new Blob(collected, { type: contentType });
    const file = new FileClass([blob], recordingName(new Date(now()), contentType), {
      type: contentType,
    });

    onRecorded({ file, durationMs: duration, contentType });
  }

  function endTake(discard) {
    // Still waiting on the permission prompt: there is nothing to stop yet, so
    // the microphone is handed back the moment it arrives.
    if (asking) abandoned = true;
    if (!recorder) return;

    discarding = discard;
    stoppedAt = now();
    stopTicking();

    // A recorder that never started leaves `onstop` unfired, so the take is
    // closed here rather than waiting for an event that is not coming.
    if (recorder.state === "inactive") finish();
    else recorder.stop();
  }

  function stop() {
    endTake(false);
  }

  async function start() {
    if (recorder || asking) return { ok: false, reason: "busy" };

    if (!supported()) {
      onError("unsupported");
      return { ok: false, reason: "unsupported" };
    }

    asking = true;
    abandoned = false;

    try {
      stream = await mediaDevices.getUserMedia({ audio: true });
    } catch (error) {
      stream = null;
      const reason = refusal(error);
      onError(reason);
      return { ok: false, reason };
    } finally {
      asking = false;
    }

    if (abandoned) {
      releaseStream();
      return { ok: false, reason: "cancelled" };
    }

    const mimeType = preferredType();

    chunks = [];
    discarding = false;
    startedAt = now();
    stoppedAt = 0;

    // A recorder that refuses to be built or started has the microphone in
    // hand already; it is given back and the failure said, never swallowed.
    try {
      recorder = new Recorder(stream, mimeType ? { mimeType } : {});
      recorder.ondataavailable = (event) => {
        if (event?.data?.size !== 0) chunks.push(event.data);
      };
      recorder.onstop = () => finish();
      recorder.start();
    } catch (error) {
      log.error("voice recorder could not start", error);
      recorder = null;
      releaseStream();
      onError("unsupported");
      return { ok: false, reason: "unsupported" };
    }

    ticker = setInterval(tick, TICK_MS);
    onState({ recording: true, elapsedMs: 0 });

    return { ok: true };
  }

  return {
    supported,
    recording,
    start,
    stop,
    cancel() {
      endTake(true);
    },
    destroy() {
      endTake(true);
      stopTicking();
      releaseStream();
    },
  };
}
