/**
 * Recolour an indexed PNG by rewriting its palette.
 *
 * The character creator's pieces are 8-bit indexed PNGs whose recolourable
 * parts (skin, hair, an outfit's two colours) sit at known palette indices, one
 * index per shade. Choosing a colour is writing that colour's shade ramp into
 * those indices of the PLTE chunk — bytes in, bytes out, before the browser
 * ever decodes the image. Nothing is read back off a canvas, so a browser that
 * perturbs canvas reads to resist fingerprinting cannot scramble a colour.
 *
 * The server patches the same bytes the same way for chat portraits
 * (`RetroHexChatWeb.CharacterPortrait`).
 *
 * @module space/png_palette
 */

const CRC_TABLE = (() => {
  const table = new Uint32Array(256);
  for (let n = 0; n < 256; n += 1) {
    let c = n;
    for (let k = 0; k < 8; k += 1) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    table[n] = c >>> 0;
  }
  return Object.freeze(Array.from(table));
})();

/** CRC-32 of `bytes` (a Uint8Array), as PNG chunks carry it. */
export function crc32(bytes) {
  let c = 0xffffffff;
  for (let i = 0; i < bytes.length; i += 1) c = CRC_TABLE[(c ^ bytes[i]) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

const SIGNATURE = [137, 80, 78, 71, 13, 10, 26, 10];

/**
 * A copy of `png` with palette entries replaced.
 *
 * @param {Uint8Array} png the PNG file
 * @param {Array<[number, number[]]>|Map<number, number[]>} entries palette
 *   index -> [r, g, b]; indices past the palette's end are ignored
 * @returns {Uint8Array} the patched file
 */
export function patchPlte(png, entries) {
  if (!(png instanceof Uint8Array) || !SIGNATURE.every((b, i) => png[i] === b)) {
    throw new Error("patchPlte: not a PNG");
  }
  const out = new Uint8Array(png);
  const view = new DataView(out.buffer, out.byteOffset, out.byteLength);
  let pos = 8;
  while (pos + 8 <= out.length) {
    const length = view.getUint32(pos);
    const type = String.fromCharCode(out[pos + 4], out[pos + 5], out[pos + 6], out[pos + 7]);
    if (pos + 12 + length > out.length) throw new Error("patchPlte: a chunk runs past the end");
    if (type === "PLTE") {
      const data = pos + 8;
      for (const [index, rgb] of entries) {
        const at = data + index * 3;
        if (index < 0 || index * 3 + 3 > length) continue;
        out[at] = rgb[0];
        out[at + 1] = rgb[1];
        out[at + 2] = rgb[2];
      }
      view.setUint32(data + length, crc32(out.subarray(pos + 4, data + length)));
      return out;
    }
    if (type === "IDAT" || type === "IEND") break;
    pos += 12 + length;
  }
  throw new Error("patchPlte: no palette before the image data");
}
