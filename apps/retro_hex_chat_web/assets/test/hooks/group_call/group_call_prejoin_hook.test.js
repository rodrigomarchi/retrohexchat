import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import GroupCallPreJoinHook from "../../../js/hooks/group_call/group_call_prejoin_hook.js";

let storageGetItem;
let storageSetItem;
let storageRemoveItem;

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
      <select name="group_call_prejoin[layout_mode]">
        <option value="auto" selected>Auto</option>
        <option value="focus">Focus</option>
      </select>
      <select name="group_call_prejoin[self_view]">
        <option value="tile" selected>Tile</option>
        <option value="hidden">Hidden</option>
      </select>
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
        <option value="spk-1">Speaker 1</option>
      </select>
    </form>
  `;

  const hook = Object.create(GroupCallPreJoinHook);
  hook.el = document.getElementById("group-call-prejoin-preview");
  hook.pushEvent = vi.fn();

  return hook;
}

function p2pSetupFixture() {
  document.body.innerHTML = `
    <form id="p2p-setup-form">
      <section id="p2p-setup-preview"
        data-prejoin-prefix="p2p-setup"
        data-form-name="p2p_setup"
        data-devices-event="p2p_setup_devices_listed"
        data-preferences-event="p2p_setup_preferences_loaded">
        <span data-p2p-setup-device-state>
          <span data-p2p-setup-device-state-text>Checking devices</span>
        </span>
        <video data-p2p-setup-video></video>
        <div data-p2p-setup-empty>
          <span data-p2p-setup-empty-text></span>
        </div>
        <div data-p2p-setup-warning class="hidden">
          <span data-p2p-setup-warning-text></span>
          <button type="button" data-p2p-setup-retry>Retry</button>
        </div>
      </section>
      <input type="checkbox" name="p2p_setup[audio]" checked />
      <input type="checkbox" name="p2p_setup[video]" />
      <select name="p2p_setup[audio_input_id]">
        <option value="">Default</option>
        <option value="mic-p2p" selected>Mic P2P</option>
      </select>
      <select name="p2p_setup[video_input_id]">
        <option value="">Default</option>
      </select>
      <select name="p2p_setup[audio_output_id]">
        <option value="">Default</option>
      </select>
    </form>
  `;

  const hook = Object.create(GroupCallPreJoinHook);
  hook.el = document.getElementById("p2p-setup-preview");
  hook.pushEvent = vi.fn();

  return hook;
}

function streamFixture({ video = true } = {}) {
  const audioTrack = { kind: "audio", stop: vi.fn() };
  const videoTrack = { kind: "video", stop: vi.fn() };
  const tracks = video ? [audioTrack, videoTrack] : [audioTrack];

  return {
    getTracks: vi.fn(() => tracks),
    getAudioTracks: vi.fn(() => [audioTrack]),
    getVideoTracks: vi.fn(() => (video ? [videoTrack] : [])),
  };
}

async function flushPromises() {
  await Promise.resolve();
  await Promise.resolve();
}

describe("GroupCallPreJoinHook", () => {
  beforeEach(() => {
    storageGetItem = vi.fn(() => {
      throw new Error("prejoin hook must not read localStorage");
    });
    storageSetItem = vi.fn(() => {
      throw new Error("prejoin hook must not write localStorage");
    });
    storageRemoveItem = vi.fn(() => {
      throw new Error("prejoin hook must not remove localStorage");
    });

    vi.stubGlobal("localStorage", {
      getItem: storageGetItem,
      setItem: storageSetItem,
      removeItem: storageRemoveItem,
      clear: vi.fn(),
    });

    vi.spyOn(HTMLMediaElement.prototype, "play").mockResolvedValue(undefined);
  });

  afterEach(() => {
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
    document.body.innerHTML = "";
  });

  it("uses server-rendered preferences without touching localStorage", async () => {
    const getUserMedia = vi.fn();
    Object.defineProperty(navigator, "mediaDevices", {
      configurable: true,
      value: {
        enumerateDevices: vi.fn(async () => []),
        getUserMedia,
      },
    });

    const hook = formFixture();
    document.querySelector('[name="group_call_prejoin[audio]"]').checked = false;
    document.querySelector('[name="group_call_prejoin[video]"]').checked = false;
    document.querySelector('[name="group_call_prejoin[layout_mode]"]').value = "focus";
    document.querySelector('[name="group_call_prejoin[self_view]"]').value = "hidden";
    document.querySelector('[name="group_call_prejoin[audio_input_id]"]').value = "mic-1";
    document.querySelector('[name="group_call_prejoin[video_input_id]"]').value = "cam-1";
    document.querySelector('[name="group_call_prejoin[audio_output_id]"]').value = "spk-1";

    hook.mounted();
    await flushPromises();

    expect(hook.pushEvent).toHaveBeenCalledWith("group_call_prejoin_preferences_loaded", {
      audio: false,
      video: false,
      layout_mode: "focus",
      self_view: "hidden",
      audio_input_id: "mic-1",
      video_input_id: "cam-1",
      audio_output_id: "spk-1",
    });
    expect(getUserMedia).not.toHaveBeenCalled();
    expect(document.querySelector("[data-group-call-prejoin-empty-text]").textContent).toBe(
      "Joining receive-only",
    );
    expect(storageGetItem).not.toHaveBeenCalled();
    expect(storageSetItem).not.toHaveBeenCalled();
    expect(storageRemoveItem).not.toHaveBeenCalled();
  });

  it("lists devices and previews with selected device constraints", async () => {
    const stream = streamFixture();
    const getUserMedia = vi.fn(async () => stream);

    Object.defineProperty(navigator, "mediaDevices", {
      configurable: true,
      value: {
        enumerateDevices: vi.fn(async () => [
          { kind: "audioinput", deviceId: "mic-1", label: "Desk Mic" },
          { kind: "videoinput", deviceId: "cam-1", label: "Desk Cam" },
          { kind: "audiooutput", deviceId: "spk-1", label: "Desk Speakers" },
        ]),
        getUserMedia,
      },
    });

    const hook = formFixture();
    document.querySelector('[name="group_call_prejoin[audio_input_id]"]').value = "mic-1";
    document.querySelector('[name="group_call_prejoin[video_input_id]"]').value = "cam-1";

    hook.mounted();
    await flushPromises();

    expect(hook.pushEvent).toHaveBeenCalledWith("group_call_prejoin_devices_listed", {
      audioinput: [{ id: "mic-1", label: "Desk Mic" }],
      videoinput: [{ id: "cam-1", label: "Desk Cam" }],
      audiooutput: [{ id: "spk-1", label: "Desk Speakers" }],
    });

    expect(getUserMedia).toHaveBeenCalledWith({
      audio: expect.objectContaining({ deviceId: { exact: "mic-1" } }),
      video: expect.objectContaining({ deviceId: { exact: "cam-1" } }),
    });
    expect(
      document.querySelector("[data-group-call-prejoin-empty]").classList.contains("hidden"),
    ).toBe(true);
  });

  it("keeps the active camera preview visible after LiveView refreshes preview markup", async () => {
    const stream = streamFixture();
    const getUserMedia = vi.fn(async () => stream);

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

    const hook = formFixture();
    hook.mounted();
    await flushPromises();

    expect(document.querySelector("[data-group-call-prejoin-video]").srcObject).toBe(stream);
    expect(
      document.querySelector("[data-group-call-prejoin-empty]").classList.contains("hidden"),
    ).toBe(true);

    hook.el.innerHTML = `
      <span data-group-call-prejoin-device-state>
        <span data-group-call-prejoin-device-state-text>Checking devices</span>
      </span>
      <video data-group-call-prejoin-video></video>
      <div data-group-call-prejoin-empty>
        <span data-group-call-prejoin-empty-text>Camera preview is off</span>
      </div>
      <div data-group-call-prejoin-warning class="hidden">
        <span data-group-call-prejoin-warning-text></span>
        <button type="button" data-group-call-prejoin-retry>Retry</button>
      </div>
    `;

    hook.updated();
    await flushPromises();

    expect(getUserMedia).toHaveBeenCalledTimes(1);
    expect(document.querySelector("[data-group-call-prejoin-video]").srcObject).toBe(stream);
    expect(
      document.querySelector("[data-group-call-prejoin-empty]").classList.contains("hidden"),
    ).toBe(true);
  });

  it("keeps a pending permission prompt alive across LiveView refreshes", async () => {
    const stream = streamFixture();
    let resolveMedia;
    const pendingMedia = new Promise((resolve) => {
      resolveMedia = resolve;
    });
    const getUserMedia = vi.fn(() => pendingMedia);

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

    const hook = formFixture();
    hook.mounted();
    await flushPromises();

    hook.updated();
    await flushPromises();

    expect(getUserMedia).toHaveBeenCalledTimes(1);

    resolveMedia(stream);
    await flushPromises();

    expect(document.querySelector("[data-group-call-prejoin-video]").srcObject).toBe(stream);
    expect(stream.getTracks()[0].stop).not.toHaveBeenCalled();
    expect(stream.getTracks()[1].stop).not.toHaveBeenCalled();
  });

  it("shows an actionable permission warning and retries the same preview constraints", async () => {
    const stream = streamFixture();
    const permissionError = new Error("Permission denied");
    permissionError.name = "NotAllowedError";

    const getUserMedia = vi
      .fn()
      .mockRejectedValueOnce(permissionError)
      .mockResolvedValueOnce(stream);

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

    const hook = formFixture();
    hook.mounted();
    await flushPromises();

    expect(document.querySelector("[data-group-call-prejoin-warning-text]").textContent).toContain(
      "Permission denied",
    );
    expect(
      document.querySelector("[data-group-call-prejoin-warning]").classList.contains("flex"),
    ).toBe(true);

    document.querySelector("[data-group-call-prejoin-retry]").click();
    await flushPromises();

    expect(getUserMedia).toHaveBeenCalledTimes(2);
    expect(
      document.querySelector("[data-group-call-prejoin-warning]").classList.contains("hidden"),
    ).toBe(true);
    expect(document.querySelector("[data-group-call-prejoin-video]").srcObject).toBe(stream);
  });

  it("can be configured for the P2P setup dialog", async () => {
    const stream = streamFixture({ video: false });
    const getUserMedia = vi.fn(async () => stream);

    Object.defineProperty(navigator, "mediaDevices", {
      configurable: true,
      value: {
        enumerateDevices: vi.fn(async () => [
          { kind: "audioinput", deviceId: "mic-p2p", label: "P2P Mic" },
        ]),
        getUserMedia,
      },
    });

    const hook = p2pSetupFixture();
    hook.mounted();
    await flushPromises();

    expect(hook.pushEvent).toHaveBeenCalledWith("p2p_setup_devices_listed", {
      audioinput: [{ id: "mic-p2p", label: "P2P Mic" }],
      videoinput: [],
      audiooutput: [],
    });
    expect(hook.pushEvent).toHaveBeenCalledWith("p2p_setup_preferences_loaded", {
      audio: true,
      video: false,
      layout_mode: "auto",
      self_view: "tile",
      audio_input_id: "mic-p2p",
      video_input_id: "",
      audio_output_id: "",
    });
    expect(getUserMedia).toHaveBeenCalledWith({
      audio: expect.objectContaining({ deviceId: { exact: "mic-p2p" } }),
      video: false,
    });

    document
      .querySelector('[name="p2p_setup[audio_input_id]"]')
      .dispatchEvent(new Event("change", { bubbles: true }));
    await flushPromises();

    expect(hook.pushEvent).toHaveBeenLastCalledWith("p2p_setup_preferences_loaded", {
      audio: true,
      video: false,
      layout_mode: "auto",
      self_view: "tile",
      audio_input_id: "mic-p2p",
      video_input_id: "",
      audio_output_id: "",
    });
    expect(storageGetItem).not.toHaveBeenCalled();
    expect(storageSetItem).not.toHaveBeenCalled();
    expect(storageRemoveItem).not.toHaveBeenCalled();
  });
});
