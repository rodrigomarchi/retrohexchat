/**
 * @file Verifies console arguments survive the trip to RUM.
 *
 * The regression this pins: a Phoenix channel reply logged as an object reached
 * Grafana as `[object Object]`, which is a log line carrying no information.
 */
import { afterEach, describe, expect, it, vi } from "vitest";
import { log } from "../../js/lib/logger.js";

afterEach(() => vi.restoreAllMocks());

/**
 * Capture the arguments the console actually received.
 *
 * @param {"debug"|"error"|"warn"} level - Console method to spy on.
 * @returns {import("vitest").MockInstance} The spy.
 */
function spyOn(level) {
  return vi.spyOn(console, level).mockImplementation(() => {});
}

describe("log", () => {
  it("serialises an object argument instead of losing it", () => {
    const error = spyOn("error");

    log.error("[space] channel join rejected", { reason: "invalid_token" });

    expect(error).toHaveBeenCalledWith(
      "[space] channel join rejected",
      '{"reason":"invalid_token"}',
    );
  });

  it("passes Error through untouched, so stacks still deobfuscate", () => {
    const error = spyOn("error");
    const boom = new Error("boom");

    log.error("failed", boom);

    expect(error).toHaveBeenCalledWith("failed", boom);
  });

  it("leaves strings, numbers, booleans and null alone", () => {
    const warn = spyOn("warn");

    log.warn("msg", 42, true, null, undefined);

    expect(warn).toHaveBeenCalledWith("msg", 42, true, null, undefined);
  });

  it("survives a circular structure rather than throwing", () => {
    const warn = spyOn("warn");
    const cyclic = { name: "loop" };
    cyclic.self = cyclic;

    log.warn(cyclic);

    expect(warn).toHaveBeenCalledWith('{"name":"loop","self":"[circular]"}');
  });

  it("truncates a payload too large to belong in a log line", () => {
    const debug = spyOn("debug");

    log.debug({ blob: "x".repeat(5000) });

    const [rendered] = debug.mock.calls[0];
    expect(rendered).toHaveLength(1001);
    expect(rendered.endsWith("…")).toBe(true);
  });

  it("falls back to a string when serialisation throws", () => {
    const error = spyOn("error");
    const hostile = {
      get boom() {
        throw new Error("no inspection");
      },
      toString: () => "<hostile>",
    };

    log.error(hostile);

    expect(error).toHaveBeenCalledWith("<hostile>");
  });

  it("serialises arrays too", () => {
    const error = spyOn("error");

    log.error([1, { a: 2 }]);

    expect(error).toHaveBeenCalledWith('[1,{"a":2}]');
  });
});
