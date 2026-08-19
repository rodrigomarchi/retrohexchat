import { createTabCycle } from "../../../js/lib/chat/tab_cycle.js";

describe("createTabCycle", () => {
  let el;
  let inputEvents;

  beforeEach(() => {
    vi.useFakeTimers();
    el = document.createElement("textarea");
    document.body.appendChild(el);
    inputEvents = 0;
    el.addEventListener("input", () => {
      inputEvents += 1;
    });
  });

  afterEach(() => {
    vi.useRealTimers();
    el.remove();
  });

  it("starts inactive", () => {
    const cycle = createTabCycle(el);
    expect(cycle.active).toBe(false);
  });

  it("does nothing when the match list is empty", () => {
    const cycle = createTabCycle(el);
    el.value = "typed";
    cycle.start([], true);
    expect(cycle.active).toBe(false);
    expect(el.value).toBe("typed");
  });

  it("writes the first match with a ': ' suffix at line start", () => {
    const cycle = createTabCycle(el);
    cycle.start(["alice", "robot"], true);
    expect(el.value).toBe("alice: ");
    expect(cycle.active).toBe(true);
  });

  it("writes the first match with a ' ' suffix mid-line", () => {
    const cycle = createTabCycle(el);
    cycle.start(["alice", "robot"], false);
    expect(el.value).toBe("alice ");
  });

  it("advances through the matches and wraps around", () => {
    const cycle = createTabCycle(el);
    cycle.start(["alice", "robot", "carol"], true);
    cycle.advance();
    expect(el.value).toBe("robot: ");
    cycle.advance();
    expect(el.value).toBe("carol: ");
    cycle.advance();
    expect(el.value).toBe("alice: ");
  });

  it("ignores advance before a start", () => {
    const cycle = createTabCycle(el);
    cycle.advance();
    expect(cycle.active).toBe(false);
    expect(el.value).toBe("");
  });

  it("reset clears the cycle", () => {
    const cycle = createTabCycle(el);
    cycle.start(["alice", "robot"], true);
    cycle.reset();
    expect(cycle.active).toBe(false);
  });

  it("dispatches an input event on every write so the host re-sizes", () => {
    const cycle = createTabCycle(el);
    cycle.start(["alice", "robot"], true);
    expect(inputEvents).toBe(1);
    cycle.advance();
    expect(inputEvents).toBe(2);
  });

  it("does NOT survive a host that resets on the write's own echo (see ledger finding)", () => {
    // When the host wires its input listener to reset() — as the autocomplete
    // hook does — the write's synthetic input echo clears the cycle *before*
    // `preserved` is captured, so the setTimeout(0) restore rewrites null and
    // the cycle stays dead. This pins the byte-for-byte behavior of the code
    // this replaced; the latent bug is tracked in the refactor ledger, not
    // fixed here (a fix would change observable behavior).
    const cycle = createTabCycle(el, { setTimeoutFn: setTimeout });
    el.addEventListener("input", () => cycle.reset());
    cycle.start(["alice", "robot"], true);
    expect(cycle.active).toBe(false);
    vi.runAllTimers();
    expect(cycle.active).toBe(false);
  });
});
