/**
 * Binary messages described as data.
 *
 * A game lists the fields of a message once, in wire order, and gets both the
 * encoder and the decoder from that one list — so the two can never disagree
 * about a field's size, order or scale. Every value is written exactly as a
 * DataView call would write it: little-endian, integers wrapping around on
 * overflow, a missing integer as 0 and a missing float as NaN.
 *
 * ```js
 * const SNAPSHOT = schema(MSG.GAME_STATE, [
 *   f32("ballX"),
 *   u16("paddle1Y", { round: true }),
 *   i16("x", { scale: 10 }),          // round(x * 10) on the wire, x / 10 back
 *   list("aliens", { capacity: 36, fixed: true, count: "alienCount" }, [u8("type")]),
 * ]);
 * SNAPSHOT.encode(state);             // ArrayBuffer
 * SNAPSHOT.decode(buf);               // object, or null for a short or foreign buffer
 * ```
 *
 * @module games/core/codec
 */

/**
 * @typedef {object} Field
 * @property {object} [spec] - what the field is (kind, name, options), for
 *   tools that generate or inspect messages
 * @property {(obj: object) => number} size - bytes this field takes for `obj`
 * @property {(view: DataView, offset: number, obj: object) => number} write -
 *   returns the offset after the field
 * @property {(view: DataView, offset: number, out: object) => number} read -
 *   returns the offset after the field, or -1 when the buffer ends first
 */

/**
 * A message: its type byte followed by `fields`.
 * @param {number} type
 * @param {Field[]} fields
 */
export function schema(type, fields) {
  const body = sequence(fields);

  const byteLength = (obj) => 1 + body.size(obj);

  const decodeInto = (buf, target) => {
    if (!(buf instanceof ArrayBuffer) || buf.byteLength < 1) return false;
    const view = new DataView(buf);
    if (view.getUint8(0) !== type) return false;
    const out = {};
    if (body.read(view, 1, out) < 0) return false;
    Object.assign(target, out);
    return true;
  };

  return {
    type,
    fields,
    byteLength,

    /** @returns {ArrayBuffer} */
    encode(obj) {
      const buf = new ArrayBuffer(byteLength(obj));
      const view = new DataView(buf);
      view.setUint8(0, type);
      body.write(view, 1, obj);
      return buf;
    },

    /** @returns {object|null} */
    decode(buf) {
      const out = {};
      return decodeInto(buf, out) ? out : null;
    },

    decodeInto,
  };
}

/**
 * @param {Field[]} fields
 * @returns {Field}
 */
function sequence(fields) {
  return {
    size: (obj) => fields.reduce((total, field) => total + field.size(obj), 0),
    write(view, offset, obj) {
      let at = offset;
      for (const field of fields) at = field.write(view, at, obj);
      return at;
    },
    read(view, offset, out) {
      let at = offset;
      for (const field of fields) {
        at = field.read(view, at, out);
        if (at < 0) return -1;
      }
      return at;
    },
  };
}

const SCALARS = {
  u8: { size: 1, set: "setUint8", get: "getUint8" },
  i8: { size: 1, set: "setInt8", get: "getInt8" },
  u16: { size: 2, set: "setUint16", get: "getUint16" },
  i16: { size: 2, set: "setInt16", get: "getInt16" },
  u32: { size: 4, set: "setUint32", get: "getUint32" },
  i32: { size: 4, set: "setInt32", get: "getInt32" },
  f32: { size: 4, set: "setFloat32", get: "getFloat32" },
};

/**
 * @typedef {object} ScalarOptions
 * @property {boolean} [round] - `Math.round` the value before writing it
 * @property {number} [scale] - write `round(value * scale)`, read `value / scale`
 * @property {[number, number]} [clamp] - limit the value to `[min, max]` first
 * @property {number} [or] - write this in place of a falsy value
 *   (`value || or`)
 */

/**
 * @param {keyof SCALARS} kind
 * @param {string} name
 * @param {ScalarOptions} [options]
 * @returns {Field}
 */
function scalar(kind, name, { round = false, scale = null, clamp = null, or = null } = {}) {
  const { size, set, get } = SCALARS[kind];

  const prepare = (value) => {
    let v = or !== null ? value || or : value;
    if (clamp) v = Math.min(Math.max(v, clamp[0]), clamp[1]);
    if (scale !== null) return Math.round(v * scale);
    return round ? Math.round(v) : v;
  };

  return {
    spec: { kind, name, round, scale, clamp, or },
    size: () => size,
    write(view, offset, obj) {
      view[set](offset, prepare(obj[name]), true);
      return offset + size;
    },
    read(view, offset, out) {
      if (offset + size > view.byteLength) return -1;
      const raw = view[get](offset, true);
      out[name] = scale !== null ? raw / scale : raw;
      return offset + size;
    },
  };
}

/** @type {(name: string, options?: ScalarOptions) => Field} */
export const u8 = (name, options) => scalar("u8", name, options);
/** @type {(name: string, options?: ScalarOptions) => Field} */
export const i8 = (name, options) => scalar("i8", name, options);
/** @type {(name: string, options?: ScalarOptions) => Field} */
export const u16 = (name, options) => scalar("u16", name, options);
/** @type {(name: string, options?: ScalarOptions) => Field} */
export const i16 = (name, options) => scalar("i16", name, options);
/** @type {(name: string, options?: ScalarOptions) => Field} */
export const u32 = (name, options) => scalar("u32", name, options);
/** @type {(name: string, options?: ScalarOptions) => Field} */
export const i32 = (name, options) => scalar("i32", name, options);
/** @type {(name: string, options?: ScalarOptions) => Field} */
export const f32 = (name, options) => scalar("f32", name, options);

/**
 * One byte: 1 for anything truthy, 0 otherwise; read back as a boolean.
 * @param {string} name
 * @returns {Field}
 */
export function bool(name) {
  return {
    spec: { kind: "bool", name },
    size: () => 1,
    write(view, offset, obj) {
      view.setUint8(offset, obj[name] ? 1 : 0);
      return offset + 1;
    },
    read(view, offset, out) {
      if (offset + 1 > view.byteLength) return -1;
      out[name] = view.getUint8(offset) === 1;
      return offset + 1;
    },
  };
}

/**
 * Up to eight booleans in one byte, the first name in bit 0.
 * @param {string[]} names
 * @returns {Field}
 */
export function flags(names) {
  return {
    spec: { kind: "flags", names },
    size: () => 1,
    write(view, offset, obj) {
      let byte = 0;
      names.forEach((name, bit) => {
        if (obj[name]) byte |= 1 << bit;
      });
      view.setUint8(offset, byte);
      return offset + 1;
    },
    read(view, offset, out) {
      if (offset + 1 > view.byteLength) return -1;
      const byte = view.getUint8(offset);
      names.forEach((name, bit) => {
        out[name] = (byte & (1 << bit)) !== 0;
      });
      return offset + 1;
    },
  };
}

/**
 * An array of `count` booleans, packed eight to a byte, most significant bit
 * first.
 * @param {string} name
 * @param {number} count
 * @returns {Field}
 */
export function bitmap(name, count) {
  const size = Math.ceil(count / 8);
  return {
    spec: { kind: "bitmap", name, count },
    size: () => size,
    write(view, offset, obj) {
      const values = obj[name] || [];
      for (let byte = 0; byte < size; byte++) {
        let packed = 0;
        for (let bit = 0; bit < 8; bit++) {
          if (values[byte * 8 + bit]) packed |= 1 << (7 - bit);
        }
        view.setUint8(offset + byte, packed);
      }
      return offset + size;
    },
    read(view, offset, out) {
      if (offset + size > view.byteLength) return -1;
      const values = [];
      for (let i = 0; i < count; i++) {
        values.push((view.getUint8(offset + (i >> 3)) & (1 << (7 - (i & 7)))) !== 0);
      }
      out[name] = values;
      return offset + size;
    },
  };
}

/**
 * The fields of a nested object, written in place.
 * @param {string} name
 * @param {Field[]} fields
 * @returns {Field}
 */
export function struct(name, fields) {
  const body = sequence(fields);
  return {
    spec: { kind: "struct", name, fields: fields.map((field) => field.spec) },
    size: (obj) => body.size(obj[name] || {}),
    write: (view, offset, obj) => body.write(view, offset, obj[name] || {}),
    read(view, offset, out) {
      const nested = {};
      const at = body.read(view, offset, nested);
      if (at >= 0) out[name] = nested;
      return at;
    },
  };
}

/**
 * A list of entries with the same fields.
 *
 * - `fixed: true` always writes `capacity` entries; those past the count are
 *   written as zeros, and decoding returns all `capacity` of them.
 * - Otherwise a u8 count comes first, then that many entries.
 *
 * The count is `obj[count]` when `count` names a field, else the number of
 * items; either way it is capped at `capacity` when written. A variable list
 * with a named count also reads that count back into the object, and a
 * message claiming more than `capacity` entries is refused.
 *
 * @param {string} name
 * @param {{ capacity: number, fixed?: boolean, count?: string }} options
 * @param {Field[]} fields
 * @returns {Field}
 */
export function list(name, { capacity, fixed = false, count = null }, fields) {
  const entry = sequence(fields);
  const empty = {};

  const length = (obj) => {
    const items = obj[name] || [];
    const wanted = count ? obj[count] : items.length;
    return Math.min(Number(wanted) || 0, capacity);
  };

  return {
    spec: { kind: "list", name, capacity, fixed, count, fields: fields.map((field) => field.spec) },
    size(obj) {
      const items = obj[name] || [];
      const n = fixed ? capacity : length(obj);
      let total = fixed ? 0 : 1;
      for (let i = 0; i < n; i++) total += entry.size(items[i] || empty);
      return total;
    },

    write(view, offset, obj) {
      const items = obj[name] || [];
      const n = length(obj);
      let at = offset;
      if (!fixed) {
        view.setUint8(at, n);
        at += 1;
      }
      const slots = fixed ? capacity : n;
      for (let i = 0; i < slots; i++) {
        at = entry.write(view, at, i < n && items[i] ? items[i] : empty);
      }
      return at;
    },

    read(view, offset, out) {
      let at = offset;
      let n = capacity;
      if (!fixed) {
        if (at + 1 > view.byteLength) return -1;
        n = view.getUint8(at);
        if (n > capacity) return -1;
        at += 1;
        if (count) out[count] = n;
      }
      const items = [];
      for (let i = 0; i < n; i++) {
        const item = {};
        at = entry.read(view, at, item);
        if (at < 0) return -1;
        items.push(item);
      }
      out[name] = items;
      return at;
    },
  };
}

/**
 * A layout no other field describes. `read` must return -1 when the buffer
 * ends before the field does.
 * @param {Field} field
 * @returns {Field}
 */
export function custom({ size, write, read, spec = { kind: "custom" } }) {
  return { spec, size, write, read };
}
