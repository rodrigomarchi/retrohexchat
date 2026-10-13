import { describe, expect, it } from "vitest";

import { crc32, patchPlte } from "../../../js/lib/space/png_palette.js";

const SIGNATURE = [137, 80, 78, 71, 13, 10, 26, 10];

function chunk(type, data) {
  const body = new Uint8Array([...type].map((c) => c.charCodeAt(0)).concat(data));
  const out = new Uint8Array(12 + data.length);
  const view = new DataView(out.buffer);
  view.setUint32(0, data.length);
  out.set(body, 4);
  view.setUint32(8 + data.length, crc32(body));
  return out;
}

function png(palette) {
  const parts = [
    new Uint8Array(SIGNATURE),
    chunk("IHDR", [0, 0, 0, 1, 0, 0, 0, 1, 8, 3, 0, 0, 0]),
    chunk("PLTE", palette.flat()),
    chunk("IDAT", [1, 2, 3]),
    chunk("IEND", []),
  ];
  const out = new Uint8Array(parts.reduce((n, p) => n + p.length, 0));
  let at = 0;
  for (const p of parts) {
    out.set(p, at);
    at += p.length;
  }
  return out;
}

function plte(bytes) {
  const view = new DataView(bytes.buffer, bytes.byteOffset);
  let pos = 8;
  for (;;) {
    const length = view.getUint32(pos);
    const type = String.fromCharCode(...bytes.subarray(pos + 4, pos + 8));
    if (type === "PLTE") {
      return {
        data: [...bytes.subarray(pos + 8, pos + 8 + length)],
        crc: view.getUint32(pos + 8 + length),
      };
    }
    pos += 12 + length;
  }
}

describe("png palette", () => {
  it("computes the CRC PNG chunks carry", () => {
    // The CRC of an IEND chunk is a constant every PNG ends with.
    expect(crc32(new Uint8Array([73, 69, 78, 68]))).toBe(0xae426082);
  });

  it("rewrites the named palette entries and the chunk's CRC, and nothing else", () => {
    const original = png([
      [0, 0, 0],
      [10, 10, 10],
      [20, 20, 20],
    ]);
    const patched = patchPlte(original, [[2, [200, 100, 50]]]);

    expect(plte(patched).data).toEqual([0, 0, 0, 10, 10, 10, 200, 100, 50]);
    const body = new Uint8Array([80, 76, 84, 69, 0, 0, 0, 10, 10, 10, 200, 100, 50]);
    expect(plte(patched).crc).toBe(crc32(body));
    expect(patched.length).toBe(original.length);
    // The input is left as it was: a cached download is patched many times.
    expect(plte(original).data).toEqual([0, 0, 0, 10, 10, 10, 20, 20, 20]);
  });

  it("ignores an index past the palette", () => {
    const original = png([[1, 2, 3]]);
    expect(plte(patchPlte(original, [[5, [9, 9, 9]]])).data).toEqual([1, 2, 3]);
  });

  it("refuses a file cut short inside its palette", () => {
    const whole = png([
      [1, 2, 3],
      [4, 5, 6],
    ]);
    expect(() => patchPlte(whole.subarray(0, 45), [[0, [9, 9, 9]]])).toThrow(/past the end/);
  });

  it("refuses what is not a PNG", () => {
    expect(() => patchPlte(new Uint8Array([1, 2, 3]), [])).toThrow(/not a PNG/);
  });
});
