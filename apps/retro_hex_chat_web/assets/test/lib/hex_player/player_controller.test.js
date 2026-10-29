import { afterEach, describe, expect, it, vi } from "vitest";
import { claimSound } from "../../../js/lib/hex_device/exclusive.js";
import { createPlayer, seekTime, seekValue } from "../../../js/lib/hex_player/player_controller.js";

function fakeAudioContext() {
  const created = [];
  const Context = class {
    constructor() {
      created.push(this);
    }
    createMediaElementSource = () => ({ connect: (next) => next });
    createAnalyser = () => ({
      connect: (next) => next,
      frequencyBinCount: 512,
      getByteFrequencyData: (data) => data.fill(200),
    });
    resume = () => Promise.resolve();
    close = () => Promise.resolve();
    destination = {};
  };
  return { Context, created };
}

// The element, as the server draws it, with a media element that plays when told.
function mountPlayer({
  kind = "audio",
  AudioContext = fakeAudioContext().Context,
  duration = 42,
  lengthMs = null,
} = {}) {
  const media =
    kind === "audio"
      ? `<audio src="/chat/attachments/7/preview" crossorigin="anonymous" data-player-media></audio>`
      : `<video src="/chat/attachments/7/preview" data-player-media></video>`;
  const scope = kind === "audio" ? `<canvas data-player-scope></canvas>` : "";
  document.body.insertAdjacentHTML(
    "beforeend",
    `<div class="hex-player" data-player-state="stopped"${lengthMs ? ` data-player-length="${lengthMs}"` : ""}>
      ${media}
      <span data-player-field="elapsed">0:00</span>/<span data-player-field="length">--:--</span>
      ${scope}
      <input type="range" min="0" max="1000" value="0" data-player-seek />
      <button data-player-command="play"></button>
      <button data-player-command="pause"></button>
      <button data-player-command="stop"></button>
      <button data-player-command="mute" aria-pressed="false"></button>
    </div>`,
  );
  const el = document.body.lastElementChild;
  const canvas = el.querySelector("canvas");
  // jsdom draws nothing; the frames themselves are visualizer.test.js's.
  if (canvas) canvas.getContext = () => null;
  const element = el.querySelector("[data-player-media]");
  let time = 0;
  Object.defineProperty(element, "duration", { value: duration, configurable: true });
  Object.defineProperty(element, "currentTime", {
    get: () => time,
    set: (value) => {
      time = value;
    },
    configurable: true,
  });
  element.play = vi.fn(() => {
    element.dispatchEvent(new Event("playing"));
    return Promise.resolve();
  });
  element.pause = vi.fn(() => element.dispatchEvent(new Event("pause")));
  element.load = vi.fn();

  const player = createPlayer(el, {
    AudioContext,
    requestFrame: () => 1,
    cancelFrame: () => {},
    now: () => 0,
  });
  player.mount();
  const press = (command) => el.querySelector(`[data-player-command='${command}']`).click();
  return { el, player, media: element, press };
}

afterEach(() => {
  document.body.innerHTML = "";
});

describe("seekTime and seekValue", () => {
  it("turn the slider into a time and back", () => {
    expect(seekTime(500, 42)).toBe(21);
    expect(seekTime(2000, 42)).toBe(42);
    expect(seekTime(500, Number.NaN)).toBeNull();
    expect(seekValue(21, 42)).toBe(500);
    expect(seekValue(5, Number.POSITIVE_INFINITY)).toBe(0);
  });
});

describe("createPlayer", () => {
  it("plays, pauses where it was and stops back at the start", () => {
    const { el, media, press } = mountPlayer();
    media.dispatchEvent(new Event("loadedmetadata"));
    expect(el.querySelector("[data-player-field='length']").textContent).toBe("0:42");

    press("play");
    expect(el.dataset.playerState).toBe("playing");

    media.currentTime = 10;
    press("pause");
    expect(el.dataset.playerState).toBe("paused");

    press("stop");
    expect(el.dataset.playerState).toBe("stopped");
    expect(media.currentTime).toBe(0);
  });

  it("reads the sound through the analyser when the file shares it", () => {
    const { Context, created } = fakeAudioContext();
    const { player, press } = mountPlayer({ AudioContext: Context });
    press("play");
    expect(created).toHaveLength(1);
    expect(player.state()).toMatchObject({ graph: true, shared: true });
  });

  it("loads a file the page may not read again plainly, and plays it without the analyser", () => {
    const { Context, created } = fakeAudioContext();
    const { media, player, press } = mountPlayer({ AudioContext: Context });
    media.dispatchEvent(new Event("error"));
    expect(media.hasAttribute("crossorigin")).toBe(false);
    expect(media.load).toHaveBeenCalled();

    press("play");
    expect(created).toHaveLength(0);
    expect(player.state()).toMatchObject({ state: "playing", graph: false, shared: false });
  });

  it("moves to where the slider is dragged", () => {
    const { el, media } = mountPlayer();
    const seek = el.querySelector("[data-player-seek]");
    seek.value = "500";
    seek.dispatchEvent(new Event("input"));
    expect(media.currentTime).toBe(21);
    expect(el.querySelector("[data-player-field='elapsed']").textContent).toBe("0:21");
  });

  // A recording made in a browser reads as infinitely long; the server knows better.
  it("moves through a recording with no length of its own by the one the server knows", () => {
    const { el, media } = mountPlayer({ duration: Number.POSITIVE_INFINITY, lengthMs: 7400 });
    media.dispatchEvent(new Event("loadedmetadata"));
    const seek = el.querySelector("[data-player-seek]");
    seek.value = "500";
    seek.dispatchEvent(new Event("input"));
    expect(media.currentTime).toBeCloseTo(3.7);
    expect(el.querySelector("[data-player-field='length']").textContent).toBe("--:--");
  });

  it("mutes without stopping, and says so on its key", () => {
    const { el, media, press } = mountPlayer();
    press("play");
    press("mute");
    expect(media.muted).toBe(true);
    expect(el.querySelector("[data-player-command='mute']").getAttribute("aria-pressed")).toBe(
      "true",
    );
    expect(el.dataset.playerState).toBe("playing");
  });

  it("goes back to the start when the file ends", () => {
    const { el, media, press } = mountPlayer({ kind: "video" });
    press("play");
    media.currentTime = 42;
    media.dispatchEvent(new Event("ended"));
    expect(el.dataset.playerState).toBe("stopped");
    expect(media.currentTime).toBe(0);
  });

  it("pauses when another device starts playing", () => {
    const first = mountPlayer();
    const second = mountPlayer();
    first.press("play");
    first.media.currentTime = 3;
    second.press("play");
    expect(first.el.dataset.playerState).toBe("paused");
    expect(second.el.dataset.playerState).toBe("playing");

    const radio = claimSound(window, document.createElement("div"), () => {});
    radio.announce();
    expect(second.el.dataset.playerState).toBe("stopped");
    radio.release();
  });
});
