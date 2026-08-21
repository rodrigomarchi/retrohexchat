/**
 * @file Verifies the RUM facade stays silent until Faro exists.
 *
 * The facade's whole purpose is that call sites can instrument without knowing
 * whether the lazily-loaded SDK has arrived, so the cases that matter are the
 * absent ones: no global, a global without the API, and an API that throws.
 */
import { afterEach, describe, expect, it, vi } from "vitest";
import { recordEvent, recordMeasurement } from "../../../js/lib/telemetry/rum.js";

afterEach(() => {
  delete globalThis.faro;
  vi.restoreAllMocks();
});

/**
 * Install a stub Faro global.
 *
 * @param {object} api - The `faro.api` stub.
 */
function installFaro(api) {
  globalThis.faro = { api };
}

describe("recordMeasurement", () => {
  it("does nothing when Faro has not booted", () => {
    expect(recordMeasurement("liveview_lag", { lag_ms: 42 })).toBe(false);
  });

  it("does nothing when the global exists without the API", () => {
    globalThis.faro = {};

    expect(recordMeasurement("liveview_lag", { lag_ms: 42 })).toBe(false);
  });

  it("sends the type and values in Faro's measurement shape", () => {
    const pushMeasurement = vi.fn();
    installFaro({ pushMeasurement });

    expect(recordMeasurement("liveview_lag", { lag_ms: 42 })).toBe(true);
    expect(pushMeasurement).toHaveBeenCalledWith(
      { type: "liveview_lag", values: { lag_ms: 42 } },
      undefined,
    );
  });

  it("wraps context the way Faro expects it", () => {
    const pushMeasurement = vi.fn();
    installFaro({ pushMeasurement });

    recordMeasurement("liveview_lag", { lag_ms: 1 }, { transport: "websocket" });

    expect(pushMeasurement).toHaveBeenCalledWith(expect.anything(), {
      context: { transport: "websocket" },
    });
  });

  it("reports rather than swallows an SDK failure", () => {
    const error = vi.spyOn(console, "warn").mockImplementation(() => {});
    installFaro({
      pushMeasurement: () => {
        throw new Error("transport gone");
      },
    });

    expect(recordMeasurement("liveview_lag", { lag_ms: 1 })).toBe(false);
    expect(error).toHaveBeenCalled();
  });
});

describe("recordEvent", () => {
  it("does nothing when Faro has not booted", () => {
    expect(recordEvent("liveview_socket_lost")).toBe(false);
  });

  it("forwards the name, attributes and domain", () => {
    const pushEvent = vi.fn();
    installFaro({ pushEvent });

    expect(recordEvent("liveview_socket_lost", { reason: "timeout" }, "connection")).toBe(true);
    expect(pushEvent).toHaveBeenCalledWith(
      "liveview_socket_lost",
      { reason: "timeout" },
      "connection",
    );
  });

  it("reports rather than swallows an SDK failure", () => {
    const warn = vi.spyOn(console, "warn").mockImplementation(() => {});
    installFaro({
      pushEvent: () => {
        throw new Error("transport gone");
      },
    });

    expect(recordEvent("liveview_socket_lost")).toBe(false);
    expect(warn).toHaveBeenCalled();
  });
});
