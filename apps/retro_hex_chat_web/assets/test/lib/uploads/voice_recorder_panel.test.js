/**
 * Which part of the recording strip is showing.
 *
 * The strip's words are all rendered by the server, so the only thing to test
 * here is the choosing: idle or recording, the clock, the one error message out
 * of several, and a browser that cannot record at all — which hides the strip
 * instead of offering a button that leads to an apology.
 */
import { afterEach, describe, expect, it, vi } from "vitest";

import { clock, createVoiceRecorderPanel } from "../../../js/lib/uploads/voice_recorder_panel.js";

function strip() {
  const el = document.createElement("div");
  el.innerHTML = `
    <div data-voice-state="idle">
      <button type="button" data-voice-action="start">Record</button>
    </div>
    <div data-voice-state="recording" hidden>
      <span data-voice-elapsed>0:00</span>
      <button type="button" data-voice-action="stop">Attach</button>
      <button type="button" data-voice-action="cancel">Discard</button>
    </div>
    <p data-voice-error="denied" hidden>No microphone</p>
    <p data-voice-error="unsupported" hidden>Cannot record</p>
  `;
  document.body.appendChild(el);

  return el;
}

function recorderDouble(overrides = {}) {
  const ports = {};
  const recorder = {
    supported: () => true,
    start: vi.fn(),
    stop: vi.fn(),
    cancel: vi.fn(),
    destroy: vi.fn(),
    ...overrides,
  };

  return {
    recorder,
    ports,
    createRecorder(given) {
      Object.assign(ports, given);
      return recorder;
    },
  };
}

function mounted(overrides = {}) {
  const el = strip();
  const double = recorderDouble(overrides);
  const onRecorded = vi.fn();
  const panel = createVoiceRecorderPanel(el, {
    createRecorder: double.createRecorder,
    onRecorded,
  });

  panel.mount();

  return { el, panel, onRecorded, ...double };
}

function click(el, action) {
  el.querySelector(`[data-voice-action="${action}"]`).dispatchEvent(
    new MouseEvent("click", { bubbles: true, cancelable: true }),
  );
}

afterEach(() => {
  document.body.innerHTML = "";
});

describe("clock", () => {
  it("reads as a clock, not a number of milliseconds", () => {
    expect(clock(0)).toBe("0:00");
    expect(clock(7_400)).toBe("0:07");
    expect(clock(61_000)).toBe("1:01");
    expect(clock(undefined)).toBe("0:00");
  });
});

describe("mount", () => {
  it("shows the microphone and nothing else", () => {
    const { el } = mounted();

    expect(el.hidden).toBe(false);
    expect(el.querySelector('[data-voice-state="idle"]').hidden).toBe(false);
    expect(el.querySelector('[data-voice-state="recording"]').hidden).toBe(true);
  });

  // Absence: a browser that cannot record is offered nothing, rather than a
  // button that asks for a microphone and then explains itself.
  it("hides the strip when this browser cannot record", () => {
    const { el } = mounted({ supported: () => false });

    expect(el.hidden).toBe(true);
  });

  it("binds nothing when it hid itself", () => {
    const { el, recorder } = mounted({ supported: () => false });

    click(el, "start");

    expect(recorder.start).not.toHaveBeenCalled();
  });
});

describe("the three buttons", () => {
  it("each drive the recorder", () => {
    const { el, recorder } = mounted();

    click(el, "start");
    click(el, "stop");
    click(el, "cancel");

    expect(recorder.start).toHaveBeenCalledTimes(1);
    expect(recorder.stop).toHaveBeenCalledTimes(1);
    expect(recorder.cancel).toHaveBeenCalledTimes(1);
  });
});

describe("while recording", () => {
  it("swaps the strip over and writes the clock", () => {
    const { el, ports } = mounted();

    ports.onState({ recording: true, elapsedMs: 7_400 });

    expect(el.querySelector('[data-voice-state="idle"]').hidden).toBe(true);
    expect(el.querySelector('[data-voice-state="recording"]').hidden).toBe(false);
    expect(el.querySelector("[data-voice-elapsed]").textContent).toBe("0:07");
  });

  it("comes back to the microphone when the take ends", () => {
    const { el, ports } = mounted();

    ports.onState({ recording: true, elapsedMs: 2_000 });
    ports.onState({ recording: false, elapsedMs: 0 });

    expect(el.querySelector('[data-voice-state="idle"]').hidden).toBe(false);
    expect(el.querySelector("[data-voice-elapsed]").textContent).toBe("0:00");
  });
});

describe("errors", () => {
  it("shows the one the recorder named", () => {
    const { el, ports } = mounted();

    ports.onError("denied");

    expect(el.querySelector('[data-voice-error="denied"]').hidden).toBe(false);
    expect(el.querySelector('[data-voice-error="unsupported"]').hidden).toBe(true);
  });

  it("clears it when a take starts", () => {
    const { el, ports } = mounted();

    ports.onError("denied");
    ports.onState({ recording: true, elapsedMs: 0 });

    expect(el.querySelector('[data-voice-error="denied"]').hidden).toBe(true);
  });
});

describe("destroy", () => {
  it("releases the recorder and unbinds the buttons", () => {
    const { el, panel, recorder } = mounted();

    panel.destroy();
    click(el, "start");

    expect(recorder.destroy).toHaveBeenCalledTimes(1);
    expect(recorder.start).not.toHaveBeenCalled();
  });
});
