import { describe, expect, it, vi } from "vitest";
import { registerServiceWorker } from "../../../js/lib/system/service_worker.js";

describe("service worker registration", () => {
  it("registers at the root scope", async () => {
    const register = vi.fn(async () => "registration");
    const nav = { serviceWorker: { register } };

    expect(await registerServiceWorker({ nav })).toBe("registration");
    expect(register).toHaveBeenCalledWith("/sw.js", { scope: "/" });
  });

  it("does nothing in a browser without the API", async () => {
    expect(await registerServiceWorker({ nav: {} })).toBeNull();
  });

  // Plain http, a blocked profile, a corporate policy: none of these are
  // reasons for the chat to behave differently, but none may be silent either.
  it("survives a refused registration and says so", async () => {
    const nav = {
      serviceWorker: {
        register: vi.fn(async () => {
          throw new Error("insecure context");
        }),
      },
    };

    expect(await registerServiceWorker({ nav })).toBeNull();
  });
});
