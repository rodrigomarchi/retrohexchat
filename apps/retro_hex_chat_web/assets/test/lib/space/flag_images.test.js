import { describe, it, expect, vi } from "vitest";

import { FlagImages } from "../../../js/lib/space/flag_images.js";

const PT = "data:image/svg+xml;base64,PHN2Zz48L3N2Zz4=";

function build(ready = true) {
  const makeImage = vi.fn((url) => ({ url, complete: ready, naturalWidth: ready ? 14 : 0 }));
  const flags = new FlagImages({ urls: { pt_BR: PT, xx: "javascript:alert(1)" }, makeImage });
  return { flags, makeImage };
}

describe("FlagImages", () => {
  it("hands back the flag's image once it has loaded, made once", () => {
    const { flags, makeImage } = build();

    expect(flags.get("pt_BR")?.url).toBe(PT);
    flags.get("pt_BR");
    expect(makeImage).toHaveBeenCalledTimes(1);
    expect(flags.size).toBe(14);
  });

  it("draws nothing while the image is still loading", () => {
    const { flags } = build(false);

    expect(flags.get("pt_BR")).toBe(null);
  });

  it("has no flag for a locale it was not given, for none, or for anything not an SVG image", () => {
    const { flags, makeImage } = build();

    expect(flags.get("ja")).toBe(null);
    expect(flags.get(null)).toBe(null);
    expect(flags.get("xx")).toBe(null);
    expect(makeImage).not.toHaveBeenCalled();
  });
});
