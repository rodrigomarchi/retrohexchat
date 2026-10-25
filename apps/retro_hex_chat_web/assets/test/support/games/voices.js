/**
 * What a sound log plays, rather than the calls that built it: one voice per
 * source (an oscillator or a buffer of noise), with its wave, its parameter
 * curves, the nodes it passes through to the speakers, and when it starts and
 * stops. Two logs that build the same voices sound the same — setting
 * `frequency.value` and `setValueAtTime(f, now)` give one voice, and so do a
 * chained `connect` and two separate ones, or a note scheduled 40 ms ahead and
 * one started by a 40 ms timer.
 *
 * Reads the time of each entry from `entry.t`, which `recordingAudio` stamps.
 *
 * @param {Array<Array<unknown> & { t: number }>} log
 * @returns {Array<object>}
 */
export function voices(log) {
  const nodes = new Map();
  const buffers = new Map();
  const round = (x) => (typeof x === "number" ? Math.round(x * 1e6) / 1e6 : x);

  log.forEach((entry, index) => {
    const [subject, op, ...args] = entry;
    const t = round(entry.t ?? 0);
    if (subject === "context") return;
    if (op === "createBuffer") {
      buffers.set(subject, { seconds: round(args[1] / args[2]) });
      return;
    }
    if (typeof op === "string" && op.startsWith("create")) {
      nodes.set(subject, {
        kind: op.slice("create".length),
        index,
        fields: {},
        params: {},
        to: [],
        start: null,
        stop: null,
      });
      return;
    }

    const dot = String(subject).indexOf(".");
    if (dot !== -1) {
      const node = nodes.get(subject.slice(0, dot));
      const name = subject.slice(dot + 1);
      const curve = (node.params[name] ??= []);
      if (op === "value") curve.push(["set", round(args[0]), t]);
      else if (op === "setValueAtTime") curve.push(["set", ...args.map(round)]);
      else if (op === "linearRampToValueAtTime") curve.push(["linear", ...args.map(round)]);
      else if (op === "exponentialRampToValueAtTime") curve.push(["exp", ...args.map(round)]);
      else if (op === "setTargetAtTime") curve.push(["target", ...args.map(round)]);
      else curve.push([op, ...args.map(round)]);
      return;
    }

    const node = nodes.get(subject);
    if (!node) return;
    if (op === "connect") node.to.push(args[0]);
    else if (op === "start") node.start = round(args[0] ?? t);
    else if (op === "stop") node.stop = round(args[0] ?? t);
    else if (op === "disconnect") node.disconnected = t;
    else if (op === "buffer") node.fields.seconds = buffers.get(args[0])?.seconds ?? null;
    else node.fields[op] = args[0];
  });

  const describe = (node) => {
    const params = Object.fromEntries(
      Object.entries(node.params).filter(([, curve]) => curve.length > 0),
    );
    return { kind: node.kind, ...node.fields, ...(Object.keys(params).length ? { params } : {}) };
  };

  const sources = [...nodes.values()].filter(
    (node) => node.kind === "Oscillator" || node.kind === "BufferSource",
  );
  return sources
    .map((source) => {
      const path = [];
      const seen = new Set();
      let next = source.to[0];
      while (next && next !== "destination" && !seen.has(next) && nodes.has(next)) {
        seen.add(next);
        const node = nodes.get(next);
        path.push(describe(node));
        next = node.to[0];
      }
      return {
        source: describe(source),
        path,
        out: next === "destination" ? "speakers" : "nowhere",
        start: source.start,
        stop: source.stop,
        order: source.index,
      };
    })
    .sort((a, b) => (a.start ?? 0) - (b.start ?? 0) || a.order - b.order)
    .map(({ order: _order, ...voice }) => voice);
}
