import { afterEach, describe, expect, it, vi } from "vitest";
import { claimSound } from "../../../js/lib/hex_device/exclusive.js";
import { createRadio } from "../../../js/lib/radio/radio_controller.js";

// An <audio> that plays or fails when the test says so.
function fakeAudio() {
  return {
    crossOrigin: null,
    preload: null,
    volume: 1,
    src: "",
    onplaying: null,
    onerror: null,
    played: 0,
    play: vi.fn(function () {
      this.played += 1;
      return Promise.resolve();
    }),
    pause: vi.fn(),
    load: vi.fn(),
    getAttribute(name) {
      return name === "src" ? this.src || null : null;
    },
    removeAttribute(name) {
      if (name === "src") this.src = "";
    },
  };
}

function fakeAudioContext() {
  const node = () => ({ connect: (next) => next, gain: { value: 1 } });
  return class {
    createMediaElementSource = () => node();
    createGain = () => node();
    createAnalyser = () => ({
      ...node(),
      fftSize: 2048,
      frequencyBinCount: 1024,
      getByteFrequencyData: (data) => data.fill(200),
      getByteTimeDomainData: (data) => data.fill(128),
    });
    createBiquadFilter = () => ({
      frequency: { value: 0 },
      Q: { value: 0 },
      gain: { value: 0 },
      connect: (next) => next,
    });
    resume = () => Promise.resolve();
    close = () => Promise.resolve();
    destination = {};
  };
}

const STATION = { id: "s1", name: "Pixel Wave FM", stream: "https://radio.test/s1.mp3" };

function mountRadio({ AudioContext = fakeAudioContext() } = {}) {
  document.body.innerHTML = `
    <div id="hex-radio">
      <span data-radio-field="time"></span>
      <canvas data-radio-scope></canvas>
      <button data-radio-toggle="mute" aria-pressed="false"></button>
      <button data-radio-toggle="eq-power" aria-pressed="true"></button>
      <input type="range" data-radio-volume value="80" />
      <div id="hex-radio-equalizer" data-open="false">
        <input type="range" data-radio-band="preamp" value="0" />
        <input type="range" data-radio-band="0" value="0" />
        <span data-radio-field="eq-note"></span>
      </div>
    </div>`;
  const el = document.getElementById("hex-radio");
  // jsdom draws nothing; the frames themselves are visualizer.test.js's.
  el.querySelector("canvas").getContext = () => null;
  const audios = [];
  const status = {};
  const radio = createRadio(el, {
    status: (name, text) => (status[name] = text),
    createAudio: () => {
      const audio = fakeAudio();
      audios.push(audio);
      return audio;
    },
    AudioContext,
    requestFrame: () => 1,
    cancelFrame: () => {},
    now: () => 0,
  });
  radio.mount();
  const [shared, plain] = audios;
  return { el, radio, shared, plain, status };
}

afterEach(() => {
  document.body.innerHTML = "";
});

describe("createRadio", () => {
  it("plays a station that shares its sound through the equalizer", () => {
    const { el, radio, shared, plain, status } = mountRadio();
    radio.play(STATION);
    expect(shared.crossOrigin).toBe("anonymous");
    expect(shared.src).toBe(STATION.stream);
    expect(status.state).toBe("Connecting…");

    shared.onplaying();
    expect(radio.state()).toMatchObject({ state: "playing", mode: "shared", station: "s1" });
    expect(el.dataset.radioMode).toBe("shared");
    expect(plain.src).toBe("");
  });

  it("stops when another device starts playing, and stays quiet while stopped", () => {
    const { radio, shared } = mountRadio();
    const message = claimSound(window, document.createElement("div"), () => {});
    radio.play(STATION);
    shared.onplaying();

    message.announce();
    expect(radio.state().state).toBe("stopped");
    expect(shared.src).toBe("");
    message.release();
  });

  it("plays a station that does not share its sound on the plain element", () => {
    const { el, radio, shared, plain } = mountRadio();
    radio.play(STATION);
    shared.onerror();
    expect(shared.src).toBe("");
    expect(plain.src).toBe(STATION.stream);
    expect(plain.crossOrigin).toBe(null);

    plain.onplaying();
    expect(radio.state()).toMatchObject({ state: "playing", mode: "plain" });
    expect(el.dataset.radioMode).toBe("plain");
    expect(el.querySelector("[data-radio-field='eq-note']").textContent).toMatch(/equalizer/);
    expect(el.querySelector("[data-radio-band]").disabled).toBe(true);
  });

  it("says so when the station answers in neither way", () => {
    const { radio, shared, plain, status } = mountRadio();
    radio.play(STATION);
    shared.onerror();
    plain.onerror();
    expect(radio.state().state).toBe("failed");
    expect(status.state).toBe("No sound is coming from this radio.");
  });

  it("plays plain when the browser has no audio graph", () => {
    const { radio, plain } = mountRadio({ AudioContext: null });
    radio.play(STATION);
    expect(plain.src).toBe(STATION.stream);
  });

  it("ignores a late answer from a station it moved on from", () => {
    const { radio, shared } = mountRadio();
    radio.play(STATION);
    const stale = shared.onplaying;
    radio.play({ ...STATION, id: "s2", stream: "https://radio.test/s2.mp3" });
    stale();
    expect(radio.state().state).toBe("connecting");
  });

  it("stops, mutes and opens the equalizer from its commands", () => {
    const { el, radio, shared, status } = mountRadio();
    const send = (command, detail = {}) =>
      el.dispatchEvent(new CustomEvent("radio:command", { detail: { command, ...detail } }));

    radio.play(STATION);
    shared.onplaying();
    send("mute");
    expect(radio.state().muted).toBe(true);
    expect(status.state).toBe("Sound muted");

    expect(el.querySelector("[data-radio-toggle='mute']").getAttribute("aria-pressed")).toBe(
      "true",
    );

    send("visual", { visual: "scope" });
    expect(radio.state().visual).toBe("scope");
    // A click on the display turns to the other one.
    send("visual");
    expect(radio.state().visual).toBe("spectrum");

    const drawn = [];
    el.querySelector("canvas").getContext = () => ({
      clearRect: () => drawn.push("clear"),
      fillRect: () => drawn.push("bar"),
    });
    send("stop");
    expect(radio.state().state).toBe("stopped");
    // The display is cleared and nothing is drawn on it once stopped.
    expect(drawn.at(-1)).toBe("clear");
    expect(shared.load).toHaveBeenCalled();
  });

  it("lights SIM for a station that keeps its sound, and puts it out on stop", () => {
    const { el, radio, shared, plain } = mountRadio();
    radio.play(STATION);
    shared.onerror();
    plain.onplaying();
    expect(el.dataset.radioMode).toBe("plain");
    expect(el.dataset.radioState).toBe("playing");
    radio.play(STATION);
    expect(el.dataset.radioMode).toBe("none");
  });

  it("moves the preamp and the bands, switches the equalizer off and back to flat", () => {
    const { el, radio } = mountRadio();
    const slide = (band, value) => {
      const slider = el.querySelector(`[data-radio-band='${band}']`);
      slider.value = String(value);
      slider.dispatchEvent(new Event("input", { bubbles: true }));
    };
    const send = (command) =>
      el.dispatchEvent(new CustomEvent("radio:command", { detail: { command } }));

    slide("preamp", 6);
    slide(0, 40);
    expect(radio.state()).toMatchObject({ preamp: 6, bands: [12, 0, 0, 0, 0, 0, 0, 0, 0, 0] });

    send("eq-power");
    expect(radio.state().equalizerOn).toBe(false);
    expect(el.querySelector("[data-radio-toggle='eq-power']").getAttribute("aria-pressed")).toBe(
      "false",
    );

    send("flat");
    expect(radio.state()).toMatchObject({ preamp: 0, bands: new Array(10).fill(0) });
    expect(el.querySelector("[data-radio-band='0']").value).toBe("0");
  });

  it("keeps the volume the slider sets", () => {
    const { el, radio, shared } = mountRadio();
    const slider = el.querySelector("[data-radio-volume]");
    slider.value = "30";
    slider.dispatchEvent(new Event("input", { bubbles: true }));
    expect(radio.state().volume).toBe(30);
    radio.play(STATION);
    shared.onerror();
    expect(radio.state().volume).toBe(30);
  });

  it("toggles playing with Space and muting with M", () => {
    const { el, radio, shared } = mountRadio();
    radio.play(STATION);
    shared.onplaying();
    el.dispatchEvent(new KeyboardEvent("keydown", { key: " ", bubbles: true }));
    expect(radio.state().state).toBe("stopped");
    el.dispatchEvent(new KeyboardEvent("keydown", { key: "m", bubbles: true }));
    expect(radio.state().muted).toBe(true);
  });
});
