/**
 * The wiring between a finished recording and the upload that carries it.
 *
 * Two things happen and their order is the point: the length is pushed first,
 * then the file goes up. The presigned reservation is made while the upload
 * starts, and it is the only moment the server can be told how long the take
 * runs — afterwards there is just a file in a bucket.
 */
import { afterEach, describe, expect, it, vi } from "vitest";

import { createVoiceRecorderHook } from "../../../js/hooks/chat/voice_recorder_hook.js";
import { cleanupDOM, mountHook } from "../../helpers/hook_helper.js";

function panelDouble() {
  const ports = {};

  return {
    ports,
    destroy: vi.fn(),
    create(el, given) {
      Object.assign(ports, given);
      return { mount: vi.fn(), destroy: this.destroy };
    },
  };
}

function mount(double) {
  return mountHook(
    createVoiceRecorderHook({ createVoiceRecorderPanel: double.create.bind(double) }),
    {
      attrs: { "phx-target": "7", "data-voice-upload": "voice" },
    },
  );
}

afterEach(cleanupDOM);

describe("a finished recording", () => {
  it("tells the composer its length, then uploads it", () => {
    const double = panelDouble();
    const hook = mount(double);
    const file = new File(["audio"], "voice-20260927-101500.weba", { type: "audio/webm" });

    double.ports.onRecorded({ file, durationMs: 7_400, contentType: "audio/webm;codecs=opus" });

    expect(hook.pushEventTo).toHaveBeenCalledWith("7", "voice_recorded", {
      filename: "voice-20260927-101500.weba",
      duration_ms: 7_400,
      content_type: "audio/webm;codecs=opus",
    });

    expect(hook.__uploads).toEqual([{ target: "7", name: "voice", files: [file] }]);

    expect(hook.pushEventTo.mock.invocationCallOrder[0]).toBeLessThan(
      hook.uploadTo.mock.invocationCallOrder[0],
    );
  });
});

describe("a take that fails", () => {
  it("names the failure to the composer, which words it", () => {
    const double = panelDouble();
    const hook = mount(double);

    double.ports.onError("denied");

    expect(hook.pushEventTo).toHaveBeenCalledWith("7", "voice_error", { reason: "denied" });
  });
});

describe("destroyed", () => {
  it("hands the teardown to the panel", () => {
    const double = panelDouble();
    const hook = mount(double);

    hook.destroyed();

    expect(double.destroy).toHaveBeenCalledTimes(1);
  });
});
