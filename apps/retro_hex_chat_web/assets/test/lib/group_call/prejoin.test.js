import { createGroupCallPreJoin } from "../../../js/lib/group_call/prejoin.js";

// Direct controller test: drive createGroupCallPreJoin without the hook wrapper.
// The seam is navigator.mediaDevices (media.js calls it), so no module mocks are
// needed. The exhaustive matrix lives in the prejoin hook test; this pins the
// standalone lib contract and the two decisions worth isolating: receive-only
// short-circuit and selected-device constraints.

function formFixture() {
  document.body.innerHTML = `
    <form id="group-call-prejoin-form">
      <section id="group-call-prejoin-preview">
        <span data-group-call-prejoin-device-state>
          <span data-group-call-prejoin-device-state-text>Checking devices</span>
        </span>
        <video data-group-call-prejoin-video></video>
        <div data-group-call-prejoin-empty>
          <span data-group-call-prejoin-empty-text></span>
        </div>
        <div data-group-call-prejoin-warning class="hidden">
          <span data-group-call-prejoin-warning-text></span>
          <button type="button" data-group-call-prejoin-retry>Retry</button>
        </div>
      </section>
      <input type="checkbox" name="group_call_prejoin[audio]" checked />
      <input type="checkbox" name="group_call_prejoin[video]" checked />
      <select name="group_call_prejoin[audio_input_id]">
        <option value="">Default</option>
        <option value="mic-1">Mic 1</option>
      </select>
      <select name="group_call_prejoin[video_input_id]">
        <option value="">Default</option>
        <option value="cam-1">Cam 1</option>
      </select>
      <select name="group_call_prejoin[audio_output_id]">
        <option value="">Default</option>
      </select>
    </form>
  `;
  return document.getElementById("group-call-prejoin-preview");
}

function streamFixture() {
  const audioTrack = { kind: "audio", stop: vi.fn() };
  const videoTrack = { kind: "video", stop: vi.fn() };
  return {
    getTracks: () => [audioTrack, videoTrack],
    getAudioTracks: () => [audioTrack],
    getVideoTracks: () => [videoTrack],
  };
}

async function flushPromises() {
  await Promise.resolve();
  await Promise.resolve();
}

describe("createGroupCallPreJoin (direct)", () => {
  let pushEvent;

  beforeEach(() => {
    pushEvent = vi.fn();
    vi.spyOn(HTMLMediaElement.prototype, "play").mockResolvedValue(undefined);
  });

  afterEach(() => {
    vi.restoreAllMocks();
    document.body.innerHTML = "";
  });

  it("pushes the server-rendered preferences and short-circuits to receive-only", async () => {
    const getUserMedia = vi.fn();
    Object.defineProperty(navigator, "mediaDevices", {
      configurable: true,
      value: { enumerateDevices: vi.fn(async () => []), getUserMedia },
    });

    const el = formFixture();
    document.querySelector('[name="group_call_prejoin[audio]"]').checked = false;
    document.querySelector('[name="group_call_prejoin[video]"]').checked = false;

    const prejoin = createGroupCallPreJoin(el, { pushEvent });
    prejoin.mount();
    await flushPromises();

    expect(pushEvent).toHaveBeenCalledWith(
      "group_call_prejoin_preferences_loaded",
      expect.objectContaining({ audio: false, video: false }),
    );
    expect(getUserMedia).not.toHaveBeenCalled();
    expect(document.querySelector("[data-group-call-prejoin-empty-text]").textContent).toBe(
      "Joining receive-only",
    );

    prejoin.destroy();
  });

  it("lists devices and previews with the selected device constraints", async () => {
    const getUserMedia = vi.fn(async () => streamFixture());
    Object.defineProperty(navigator, "mediaDevices", {
      configurable: true,
      value: {
        enumerateDevices: vi.fn(async () => [
          { kind: "audioinput", deviceId: "mic-1", label: "Desk Mic" },
          { kind: "videoinput", deviceId: "cam-1", label: "Desk Cam" },
        ]),
        getUserMedia,
      },
    });

    const el = formFixture();
    document.querySelector('[name="group_call_prejoin[audio_input_id]"]').value = "mic-1";
    document.querySelector('[name="group_call_prejoin[video_input_id]"]').value = "cam-1";

    const prejoin = createGroupCallPreJoin(el, { pushEvent });
    prejoin.mount();
    await flushPromises();

    expect(pushEvent).toHaveBeenCalledWith(
      "group_call_prejoin_devices_listed",
      expect.objectContaining({
        audioinput: [{ id: "mic-1", label: "Desk Mic" }],
        videoinput: [{ id: "cam-1", label: "Desk Cam" }],
      }),
    );
    expect(getUserMedia).toHaveBeenCalledTimes(1);
    const constraints = getUserMedia.mock.calls[0][0];
    expect(constraints.audio).toBeTruthy();
    expect(constraints.video).toBeTruthy();

    prejoin.destroy();
  });

  it("stops preview tracks on destroy", async () => {
    const stream = streamFixture();
    const stops = stream.getTracks().map((t) => t.stop);
    Object.defineProperty(navigator, "mediaDevices", {
      configurable: true,
      value: {
        enumerateDevices: vi.fn(async () => []),
        getUserMedia: vi.fn(async () => stream),
      },
    });

    const el = formFixture();
    const prejoin = createGroupCallPreJoin(el, { pushEvent });
    prejoin.mount();
    await flushPromises();

    prejoin.destroy();
    stops.forEach((stop) => expect(stop).toHaveBeenCalled());
  });

  // The choice used to survive because the chat process was still standing when
  // the antechamber closed. The chat does not host a conference any more, so a
  // terminal the server has no record of — one that was never trusted — has the
  // browser as the only memory of it, and device ids only mean anything on the
  // machine that enumerated them.
  describe("remembering the choice for this terminal", () => {
    // jsdom here has no storage of its own, and the controller has to keep
    // working where a browser refuses it — so the stub is the seam and the
    // throwing case is tested through it.
    beforeEach(() => {
      const store = new Map();
      Object.defineProperty(window, "localStorage", {
        configurable: true,
        value: {
          getItem: (key) => (store.has(key) ? store.get(key) : null),
          setItem: (key, value) => store.set(key, String(value)),
          removeItem: (key) => store.delete(key),
          clear: () => store.clear(),
        },
      });
    });

    it("writes the choice under the person at the antechamber", async () => {
      Object.defineProperty(navigator, "mediaDevices", {
        configurable: true,
        value: {
          enumerateDevices: vi.fn(async () => []),
          getUserMedia: vi.fn(async () => streamFixture()),
        },
      });

      const el = formFixture();
      el.dataset.prejoinScope = "ana";
      el.dataset.prejoinRemembered = "false";

      const prejoin = createGroupCallPreJoin(el, { pushEvent });
      prejoin.mount();
      await flushPromises();

      document.querySelector('[name="group_call_prejoin[audio]"]').checked = false;
      document.getElementById("group-call-prejoin-form").dispatchEvent(new Event("change"));
      await flushPromises();

      const stored = JSON.parse(window.localStorage.getItem("rhc:group-call:prejoin:ana"));
      expect(stored.audio).toBe(false);
      expect(stored.video).toBe(true);

      prejoin.destroy();
    });

    it("puts the antechamber back the way it was left", async () => {
      window.localStorage.setItem(
        "rhc:group-call:prejoin:ana",
        JSON.stringify({ audio: false, video: false, audio_input_id: "mic-1" }),
      );

      Object.defineProperty(navigator, "mediaDevices", {
        configurable: true,
        value: {
          enumerateDevices: vi.fn(async () => []),
          getUserMedia: vi.fn(async () => streamFixture()),
        },
      });

      const el = formFixture();
      el.dataset.prejoinScope = "ana";
      el.dataset.prejoinRemembered = "false";

      const prejoin = createGroupCallPreJoin(el, { pushEvent });
      prejoin.mount();
      await flushPromises();

      expect(document.querySelector('[name="group_call_prejoin[audio]"]').checked).toBe(false);
      expect(document.querySelector('[name="group_call_prejoin[video]"]').checked).toBe(false);
      expect(document.querySelector('[name="group_call_prejoin[audio_input_id]"]').value).toBe(
        "mic-1",
      );

      prejoin.destroy();
    });

    // A trusted terminal keeps this in its device record, and that copy is the
    // one the server rendered. Overriding it here would let a stale browser
    // copy beat the record the person actually chose to keep.
    it("leaves the server's own answer alone", async () => {
      window.localStorage.setItem(
        "rhc:group-call:prejoin:ana",
        JSON.stringify({ audio: false, video: false }),
      );

      Object.defineProperty(navigator, "mediaDevices", {
        configurable: true,
        value: {
          enumerateDevices: vi.fn(async () => []),
          getUserMedia: vi.fn(async () => streamFixture()),
        },
      });

      const el = formFixture();
      el.dataset.prejoinScope = "ana";
      el.dataset.prejoinRemembered = "true";

      const prejoin = createGroupCallPreJoin(el, { pushEvent });
      prejoin.mount();
      await flushPromises();

      expect(document.querySelector('[name="group_call_prejoin[audio]"]').checked).toBe(true);

      prejoin.destroy();
    });

    // Two people sharing one browser must not inherit each other's microphone.
    it("keeps one person's choice out of another's antechamber", async () => {
      window.localStorage.setItem(
        "rhc:group-call:prejoin:ana",
        JSON.stringify({ audio: false, video: false }),
      );

      Object.defineProperty(navigator, "mediaDevices", {
        configurable: true,
        value: {
          enumerateDevices: vi.fn(async () => []),
          getUserMedia: vi.fn(async () => streamFixture()),
        },
      });

      const el = formFixture();
      el.dataset.prejoinScope = "bob";
      el.dataset.prejoinRemembered = "false";

      const prejoin = createGroupCallPreJoin(el, { pushEvent });
      prejoin.mount();
      await flushPromises();

      expect(document.querySelector('[name="group_call_prejoin[audio]"]').checked).toBe(true);

      prejoin.destroy();
    });

    // A private window throws on read and on write. The antechamber still has
    // to open — it just does not remember, which is the state it was in before.
    it("survives a browser that refuses storage", async () => {
      Object.defineProperty(window, "localStorage", {
        configurable: true,
        value: {
          getItem: () => {
            throw new Error("denied");
          },
          setItem: () => {
            throw new Error("denied");
          },
        },
      });

      Object.defineProperty(navigator, "mediaDevices", {
        configurable: true,
        value: {
          enumerateDevices: vi.fn(async () => []),
          getUserMedia: vi.fn(async () => streamFixture()),
        },
      });

      const el = formFixture();
      el.dataset.prejoinScope = "ana";
      el.dataset.prejoinRemembered = "false";

      const prejoin = createGroupCallPreJoin(el, { pushEvent });
      prejoin.mount();
      await flushPromises();

      expect(pushEvent).toHaveBeenCalledWith(
        "group_call_prejoin_preferences_loaded",
        expect.objectContaining({ audio: true }),
      );

      prejoin.destroy();
    });
  });
});
