import fc from "fast-check";

const RANGES = {
  u8: [0, 0xff],
  i8: [-0x80, 0x7f],
  u16: [0, 0xffff],
  i16: [-0x8000, 0x7fff],
  u32: [0, 0xffffffff],
  i32: [-0x80000000, 0x7fffffff],
};

/**
 * A fast-check arbitrary of objects a message schema can carry, generated
 * from the schema's own field list. It reaches past what a game would send —
 * fractions where a field rounds, values beyond a clamp — because a
 * differential test is about two encoders agreeing on every input.
 *
 * @param {{ fields: Array<{ spec: object }> }} schema
 * @param {Record<string, fc.Arbitrary<unknown>>} [overrides] - by field name
 */
export function arbitraryFor(schema, overrides = {}) {
  return record(
    schema.fields.map((field) => field.spec),
    overrides,
  );
}

function record(specs, overrides) {
  const shape = {};
  for (const spec of specs) {
    if (spec.kind === "flags") {
      for (const name of spec.names) shape[name] = overrides[name] ?? fc.boolean();
    } else if (spec.kind === "custom") {
      throw new Error("custom fields need an override in arbitraryFor");
    } else {
      shape[spec.name] = overrides[spec.name] ?? value(spec, overrides);
      if (spec.kind === "list" && spec.count && !(spec.count in shape)) {
        shape[spec.count] = overrides[spec.count] ?? fc.integer({ min: 0, max: spec.capacity + 2 });
      }
    }
  }
  return fc.record(shape);
}

function value(spec, overrides) {
  switch (spec.kind) {
    case "bool":
      return fc.boolean();
    case "bitmap":
      return fc.array(fc.boolean(), { minLength: spec.count, maxLength: spec.count });
    case "struct":
      return record(spec.fields, overrides);
    case "list":
      return fc.array(record(spec.fields, overrides), { maxLength: spec.capacity + 2 });
    case "f32":
      return fc.float({ noNaN: true, noDefaultInfinity: true, min: -1e6, max: 1e6 });
    default:
      return number(spec);
  }
}

function number({ kind, scale, round, clamp }) {
  const [min, max] = RANGES[kind];
  if (scale !== null) return fc.integer({ min, max }).map((raw) => raw / scale);
  if (clamp) return fc.integer({ min: clamp[0] - 5, max: clamp[1] + 5 });
  if (round) return fc.integer({ min: min * 4, max: max * 4 }).map((n) => n / 4);
  return fc.integer({ min, max });
}
