/**
 * Which part of the composer's microphone is showing.
 *
 * Its words are all rendered by the server, so the only thing to test here is
 * the choosing: idle or recording, the clock, the flag the composer row reads
 * to put the take where the input was, where the keyboard goes, and a browser
 * that cannot record at all — which hides the microphone instead of offering a
 * button that leads to an apology. A failure leaves by name, unworded.
 */
import { afterEach, describe, expect, it, vi } from "vitest";

import { clock, createVoiceRecorderPanel } from "../../../js/lib/uploads/voice_recorder_panel.js";

function strip() {
  const el = document.createElement("div");
  el.innerHTML = `
    <span data-voice-state="idle">
      <button type="button" data-voice-action="start">Record</button>
    </span>
    <span data-voice-state="recording" hidden>
      <span data-voice-elapsed>0:00</span>
      <button type="button" data-voice-action="cancel">Discard</button>
      <button type="button" data-voice-action="stop">Send</button>
    </span>
  `;
  document.body.appendChild(el);

  return el;
}

function recorderDouble(overrides = {}) {
  const ports = {};
  const recorder = {
    supported: () => true,
    recording: () => false,
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
  const onError = vi.fn();
  const panel = createVoiceRecorderPanel(el, {
    createRecorder: double.createRecorder,
    onRecorded,
    onError,
  });

  panel.mount();

  return { el, panel, onRecorded, onError, ...double };
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
  it("hides the microphone when this browser cannot record", () => {
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
  it("swaps the microphone for the take and writes the clock", () => {
    const { el, ports } = mounted();

    ports.onState({ recording: true, elapsedMs: 7_400 });

    expect(el.querySelector('[data-voice-state="idle"]').hidden).toBe(true);
    expect(el.querySelector('[data-voice-state="recording"]').hidden).toBe(false);
    expect(el.querySelector("[data-voice-elapsed]").textContent).toBe("0:07");
  });

  // The server rewrites an ignored element's own data attributes on every
  // patch, so state kept there would be wiped mid-take; the composer row reads
  // the take's group instead.
  it("keeps no state on its own data attributes", () => {
    const { el, ports } = mounted();
    const before = { ...el.dataset };

    ports.onState({ recording: true, elapsedMs: 0 });

    expect({ ...el.dataset }).toEqual(before);
  });

  it("hands the keyboard to Send while the take runs, and back to the microphone", () => {
    const { el, ports } = mounted();

    el.querySelector('[data-voice-action="start"]').focus();
    ports.onState({ recording: true, elapsedMs: 0 });
    expect(document.activeElement).toBe(el.querySelector('[data-voice-action="stop"]'));

    ports.onState({ recording: false, elapsedMs: 0 });
    expect(document.activeElement).toBe(el.querySelector('[data-voice-action="start"]'));
  });

  // Absence: a take that ends itself at the ceiling while the reader is
  // typing elsewhere leaves their focus where it is.
  it("does not pull focus from outside the recorder", () => {
    const { ports } = mounted();
    const elsewhere = document.createElement("input");
    document.body.appendChild(elsewhere);
    elsewhere.focus();

    ports.onState({ recording: true, elapsedMs: 0 });
    ports.onState({ recording: false, elapsedMs: 0 });

    expect(document.activeElement).toBe(elsewhere);
  });

  it("comes back to the microphone when the take ends", () => {
    const { el, ports } = mounted();

    ports.onState({ recording: true, elapsedMs: 2_000 });
    ports.onState({ recording: false, elapsedMs: 0 });

    expect(el.querySelector('[data-voice-state="idle"]').hidden).toBe(false);
    expect(el.querySelector("[data-voice-elapsed]").textContent).toBe("0:00");
  });

  it("throws the take away on Escape, and nothing above it sees the press", () => {
    const { el, recorder } = mounted({ recording: () => true });
    const above = vi.fn();
    document.body.addEventListener("keydown", above);

    el.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }));
    document.body.removeEventListener("keydown", above);

    expect(recorder.cancel).toHaveBeenCalledTimes(1);
    expect(above).not.toHaveBeenCalled();
  });

  // Absence: Escape with no take running belongs to whatever else listens.
  it("leaves Escape alone when nothing is recording", () => {
    const { el, recorder } = mounted();
    const event = new KeyboardEvent("keydown", { key: "Escape", bubbles: true, cancelable: true });

    el.dispatchEvent(event);

    expect(recorder.cancel).not.toHaveBeenCalled();
    expect(event.defaultPrevented).toBe(false);
  });
});

describe("errors", () => {
  it("are passed on by name, never worded here", () => {
    const { el, ports, onError } = mounted();

    ports.onError("denied");

    expect(onError).toHaveBeenCalledWith("denied");
    expect(el.textContent).not.toMatch(/microphone/i);
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
