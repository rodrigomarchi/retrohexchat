import { mountHook, simulateEvent, cleanupDOM } from "../../helpers/hook_helper.js";
import SoundHook from "../../../js/hooks/input/sound_hook.js";

describe("SoundHook", () => {
  let hook;
  let localStorageMock;
  let mockAudioCtx;

  beforeEach(() => {
    localStorageMock = {
      getItem: vi.fn(() => {
        throw new Error("SoundHook must not read localStorage");
      }),
      setItem: vi.fn(() => {
        throw new Error("SoundHook must not write localStorage");
      }),
      removeItem: vi.fn(() => {
        throw new Error("SoundHook must not remove localStorage");
      }),
    };

    vi.stubGlobal("localStorage", localStorageMock);

    mockAudioCtx = {
      createOscillator: vi.fn(() => ({
        connect: vi.fn(),
        type: "",
        frequency: { setValueAtTime: vi.fn() },
        start: vi.fn(),
        stop: vi.fn(),
      })),
      createGain: vi.fn(() => ({
        connect: vi.fn(),
        gain: { setValueAtTime: vi.fn(), exponentialRampToValueAtTime: vi.fn() },
      })),
      destination: {},
      currentTime: 0,
    };

    vi.stubGlobal("AudioContext", function () {
      return mockAudioCtx;
    });
  });

  afterEach(() => {
    cleanupDOM();
    vi.unstubAllGlobals();
  });

  function mountSoundHook(attrs = { "data-muted": "false" }) {
    hook = mountHook(SoundHook, { attrs });
    return hook;
  }

  // ── play_sound ─────────────────────────────────────────

  describe("play_sound", () => {
    it("creates oscillator for known sound", () => {
      mountSoundHook();

      simulateEvent(hook, "play_sound", { type: "beep" });
      expect(mockAudioCtx.createOscillator).toHaveBeenCalled();
    });

    it("does not play unknown sound", () => {
      mountSoundHook();
      mockAudioCtx.createOscillator.mockClear();

      simulateEvent(hook, "play_sound", { type: "nonexistent" });
      expect(mockAudioCtx.createOscillator).not.toHaveBeenCalled();
    });

    it("does not play 'none' sound", () => {
      mountSoundHook();
      mockAudioCtx.createOscillator.mockClear();

      simulateEvent(hook, "play_sound", { type: "none" });
      expect(mockAudioCtx.createOscillator).not.toHaveBeenCalled();
    });
  });

  // ── mute ───────────────────────────────────────────────

  describe("mute", () => {
    it("reads initial mute state from server-rendered data", () => {
      mountSoundHook({ "data-muted": "true" });

      expect(hook.muted).toBe(true);
      expect(hook.__pushEvents).toEqual([]);
      expect(localStorageMock.getItem).not.toHaveBeenCalled();
    });

    it("syncs mute state when the server patches the hook element", () => {
      mountSoundHook();

      hook.el.dataset.muted = "true";
      hook.updated();

      expect(hook.muted).toBe(true);
    });

    it("applies server mute changes without using localStorage", () => {
      mountSoundHook();

      simulateEvent(hook, "mute_state_changed", { muted: true });

      expect(hook.muted).toBe(true);
      expect(localStorageMock.setItem).not.toHaveBeenCalled();
    });

    it("ignores malformed server mute payloads", () => {
      mountSoundHook();

      simulateEvent(hook, "mute_state_changed", { muted: "true" });

      expect(hook.muted).toBe(false);
    });

    it("does not play sound when muted", () => {
      mountSoundHook();
      simulateEvent(hook, "mute_state_changed", { muted: true });

      mockAudioCtx.createOscillator.mockClear();
      simulateEvent(hook, "play_sound", { type: "beep" });
      expect(mockAudioCtx.createOscillator).not.toHaveBeenCalled();
    });
  });
});
