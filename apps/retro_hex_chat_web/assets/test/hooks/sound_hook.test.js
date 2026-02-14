import { mountHook, simulateEvent, cleanupDOM, mockLocalStorage } from "../helpers/hook_helper.js";
import SoundHook from "../../js/hooks/sound_hook.js";

describe("SoundHook", () => {
  let hook;
  let storage;

  let mockAudioCtx;

  beforeEach(() => {
    storage = mockLocalStorage();

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
    hook = mountHook(SoundHook);
  });

  afterEach(() => {
    cleanupDOM();
    storage.restore();
    vi.unstubAllGlobals();
  });

  // ── play_sound ─────────────────────────────────────────

  describe("play_sound", () => {
    it("creates oscillator for known sound", () => {
      simulateEvent(hook, "play_sound", { type: "beep" });
      expect(mockAudioCtx.createOscillator).toHaveBeenCalled();
    });

    it("does not play unknown sound", () => {
      mockAudioCtx.createOscillator.mockClear();
      simulateEvent(hook, "play_sound", { type: "nonexistent" });
      expect(mockAudioCtx.createOscillator).not.toHaveBeenCalled();
    });

    it("does not play 'none' sound", () => {
      mockAudioCtx.createOscillator.mockClear();
      simulateEvent(hook, "play_sound", { type: "none" });
      expect(mockAudioCtx.createOscillator).not.toHaveBeenCalled();
    });
  });

  // ── mute ───────────────────────────────────────────────

  describe("mute", () => {
    it("does not play sound when muted", () => {
      simulateEvent(hook, "toggle_mute", {});
      expect(hook.muted).toBe(true);

      mockAudioCtx.createOscillator.mockClear();
      simulateEvent(hook, "play_sound", { type: "beep" });
      expect(mockAudioCtx.createOscillator).not.toHaveBeenCalled();
    });

    it("persists mute state to localStorage", () => {
      simulateEvent(hook, "toggle_mute", {});
      expect(storage.store["retro_hex_chat_mute"]).toBe("true");
    });
  });
});
