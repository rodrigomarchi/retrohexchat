import { mountHook, cleanupDOM, simulateEvent } from "../../helpers/hook_helper.js";
import LagHook from "../../../js/hooks/connection/lag_hook.js";

describe("LagHook", () => {
  let hook;

  beforeEach(() => {
    vi.useFakeTimers();
    hook = mountHook(LagHook, {
      attrs: { id: "lag-display" },
    });
  });

  afterEach(() => {
    vi.useRealTimers();
    cleanupDOM();
  });

  it("sends ping event on mount after interval", () => {
    expect(hook.pushEvent).not.toHaveBeenCalledWith("ping", expect.anything());

    vi.advanceTimersByTime(30000);

    expect(hook.pushEvent).toHaveBeenCalledWith(
      "ping",
      expect.objectContaining({ client_time: expect.any(Number) }),
    );
  });

  it("calculates lag on pong and pushes lag_update", () => {
    const now = Date.now();
    simulateEvent(hook, "pong", { client_time: now - 45 });

    expect(hook.pushEvent).toHaveBeenCalledWith("lag_update", { lag_ms: expect.any(Number) });
  });

  it("clears timers on destroyed", () => {
    hook.destroyed();
    vi.advanceTimersByTime(60000);

    // After destroy, no more ping events should be pushed
    const pingCalls = hook.__pushEvents.filter((e) => e.event === "ping");
    expect(pingCalls).toHaveLength(0);
  });

  it("stops pinging on disconnected", () => {
    if (hook.disconnected) {
      hook.disconnected();
    }
    hook.pushEvent.mockClear();
    vi.advanceTimersByTime(60000);

    const pingCalls = hook.__pushEvents.filter((e) => e.event === "ping");
    expect(pingCalls).toHaveLength(0);
  });

  it("restarts pinging on reconnected", () => {
    if (hook.disconnected) {
      hook.disconnected();
    }
    hook.pushEvent.mockClear();
    if (hook.reconnected) {
      hook.reconnected();
    }

    vi.advanceTimersByTime(30000);

    expect(hook.pushEvent).toHaveBeenCalledWith(
      "ping",
      expect.objectContaining({ client_time: expect.any(Number) }),
    );
  });

  it("pushes lag_update with null on timeout", () => {
    // Trigger a ping
    vi.advanceTimersByTime(30000);
    hook.pushEvent.mockClear();

    // Advance past timeout without pong
    vi.advanceTimersByTime(10000);

    expect(hook.pushEvent).toHaveBeenCalledWith("lag_update", { lag_ms: null });
  });
});
