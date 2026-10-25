import { SOUND_CATALOG, createNotificationSounds } from "../../../js/lib/input/sound.js";

/** An AudioContext that writes down every node and every scheduled value. */
function recordingContext({ state = "running" } = {}) {
  const calls = [];
  const param = (name) => ({
    setValueAtTime: (v, t) => calls.push([name, "set", v, t]),
    linearRampToValueAtTime: (v, t) => calls.push([name, "linear", v, t]),
    exponentialRampToValueAtTime: (v, t) => calls.push([name, "exp", v, t]),
  });
  const ctx = {
    state,
    currentTime: 0,
    destination: { name: "speakers" },
    calls,
    resume: vi.fn(() => Promise.resolve()),
    close: vi.fn(() => Promise.resolve()),
    createOscillator: vi.fn(() => {
      const osc = {
        frequency: param("freq"),
        connect: (node) => calls.push(["osc→", node.kind]),
        start: (t) => calls.push(["start", t]),
        stop: (t) => calls.push(["stop", t]),
      };
      Object.defineProperty(osc, "type", {
        set(wave) {
          calls.push(["wave", wave]);
        },
      });
      return osc;
    }),
    createGain: vi.fn(() => ({
      kind: "gain",
      gain: param("vol"),
      connect: (node) => calls.push(["gain→", node.name]),
    })),
  };
  return ctx;
}

describe("lib/input/sound", () => {
  let ctx;

  beforeEach(() => {
    ctx = recordingContext();
    vi.stubGlobal("AudioContext", function () {
      return ctx;
    });
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  describe("SOUND_CATALOG", () => {
    it("has 'none' as null", () => {
      expect(SOUND_CATALOG.none).toBeNull();
    });

    it("has 14 named sounds, each one voice", () => {
      const sounds = Object.entries(SOUND_CATALOG).filter(([, v]) => v !== null);
      expect(sounds).toHaveLength(14);
      for (const [, voice] of sounds) {
        expect(voice).toEqual({
          wave: expect.any(String),
          freq: expect.any(Number),
          vol: expect.any(Array),
          dur: expect.any(Number),
        });
      }
    });
  });

  describe("createNotificationSounds", () => {
    it("plays a tone that dies away exponentially, through one gain to the speakers", () => {
      createNotificationSounds().play("beep");

      expect(ctx.calls).toEqual(
        expect.arrayContaining([
          ["wave", "sine"],
          ["freq", "set", 520, 0],
          ["vol", "set", 0.2, 0],
          ["vol", "exp", 0.01, 0.1],
          ["osc→", "gain"],
          ["gain→", "speakers"],
          ["start", 0],
          ["stop", 0.1],
        ]),
      );
      expect(ctx.createOscillator).toHaveBeenCalledOnce();
    });

    it.each(["none", "nonexistent", "toString"])("plays nothing for %s", (name) => {
      createNotificationSounds().play(name);
      expect(ctx.createOscillator).not.toHaveBeenCalled();
    });

    it("wakes a context the browser has suspended", () => {
      ctx = recordingContext({ state: "suspended" });
      createNotificationSounds().play("ding_low");
      expect(ctx.resume).toHaveBeenCalled();
    });

    it("closes its context when disposed", () => {
      const sounds = createNotificationSounds();
      sounds.play("click");
      sounds.dispose();
      expect(ctx.close).toHaveBeenCalledOnce();
    });

    it("stays quiet, without throwing, where audio cannot start", () => {
      vi.stubGlobal("AudioContext", function () {
        throw new Error("no audio here");
      });
      expect(() => createNotificationSounds().play("alert")).not.toThrow();
    });
  });
});
