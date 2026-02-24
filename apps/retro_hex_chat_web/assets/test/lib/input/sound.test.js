import { SOUND_CATALOG, synthesizeSound } from "../../../js/lib/input/sound.js";

describe("lib/sound", () => {
  describe("SOUND_CATALOG", () => {
    it("has 'none' as null", () => {
      expect(SOUND_CATALOG.none).toBeNull();
    });

    it("has 14 named sounds", () => {
      const sounds = Object.entries(SOUND_CATALOG).filter(([, v]) => v !== null);
      expect(sounds).toHaveLength(14);
    });

    it("each sound has required fields", () => {
      Object.entries(SOUND_CATALOG).forEach(([_name, config]) => {
        if (config === null) return;
        expect(config).toHaveProperty("frequency");
        expect(config).toHaveProperty("duration");
        expect(config).toHaveProperty("volume");
        expect(config).toHaveProperty("waveType");
      });
    });
  });

  describe("synthesizeSound", () => {
    function mockCtx() {
      return {
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
    }

    it("creates oscillator for known sound", () => {
      const ctx = mockCtx();
      synthesizeSound(ctx, "beep");
      expect(ctx.createOscillator).toHaveBeenCalled();
    });

    it("does not create oscillator for unknown sound", () => {
      const ctx = mockCtx();
      synthesizeSound(ctx, "nonexistent");
      expect(ctx.createOscillator).not.toHaveBeenCalled();
    });

    it("does not create oscillator for 'none'", () => {
      const ctx = mockCtx();
      synthesizeSound(ctx, "none");
      expect(ctx.createOscillator).not.toHaveBeenCalled();
    });
  });
});
