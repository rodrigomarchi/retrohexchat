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
});
