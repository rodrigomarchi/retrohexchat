/**
 * @file The hook is a binding, so the only thing worth testing here is the
 * binding: what it forwards to the conference controller, and what it does when
 * LiveView cannot carry it.
 */
import { mountHook, cleanupDOM } from "../../helpers/hook_helper.js";

const conn = { mount: vi.fn(), destroy: vi.fn() };
const createConferenceConnection = vi.fn(() => conn);

vi.mock("../../../js/lib/group_call/conference_connection.js", () => ({
  createConferenceConnection: (...args) => createConferenceConnection(...args),
}));

const { default: GroupCallWebRTCHook } =
  await import("../../../js/hooks/group_call/group_call_webrtc_hook.js");

describe("GroupCallWebRTCHook", () => {
  let hook;

  /**
   * The pushEvent bridge the hook hands to the controller.
   *
   * @returns {(event: string, payload: object) => void}
   */
  function forwarder() {
    return createConferenceConnection.mock.calls.at(-1)[1].pushEvent;
  }

  beforeEach(() => {
    createConferenceConnection.mockClear();
    hook = mountHook(GroupCallWebRTCHook);
  });

  afterEach(() => {
    cleanupDOM();
    vi.restoreAllMocks();
  });

  it("forwards a signal to LiveView while the socket is up", () => {
    forwarder()("group_call_offer", { sdp: "v=0" });

    expect(hook.pushEvent).toHaveBeenCalledWith("group_call_offer", { sdp: "v=0" });
  });

  it("drops the signal instead of throwing when the socket is gone", () => {
    // Regression: the controller keeps negotiating while LiveView reconnects,
    // and the raw pushEvent threw. Those throws reached RUM as unhandled
    // errors on every blip — six of them in one load run on 2026-08-21.
    hook.__connected = false;
    const warn = vi.spyOn(console, "warn").mockImplementation(() => {});

    expect(() => forwarder()("group_call_ice_candidate", {})).not.toThrow();
    expect(warn).toHaveBeenCalled();
  });
});
