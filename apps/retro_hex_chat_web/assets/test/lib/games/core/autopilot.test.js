import { afterEach, describe, expect, it, vi } from "vitest";
import {
  AUTOPILOT_GLOBAL,
  AUTOPILOT_META,
  autopilotRequest,
  createAutopilot,
} from "../../../../js/lib/games/core/autopilot.js";
import { matchPerTest } from "../../../support/games/harness.js";

/** A keyboard that writes down every key event it is sent. */
function listeningKeyboard() {
  const target = new EventTarget();
  const heard = [];
  for (const type of ["keydown", "keyup"]) {
    target.addEventListener(type, (event) => heard.push(`${type} ${event.key}`));
  }
  return { target, heard };
}

/** A controller that answers each step with the next of `answers`. */
function scripted(answers) {
  let turn = 0;
  return { nextInputs: () => answers[Math.min(turn++, answers.length - 1)] };
}

/** A page as the e2e server builds it (with the meta), or as any other build does. */
const page = (e2e, request) => ({
  document: { querySelector: (selector) => (e2e && selector === AUTOPILOT_META ? {} : null) },
  ...(request === undefined ? {} : { [AUTOPILOT_GLOBAL]: request }),
});

/** The meta the e2e server prints, on the page the tests run in. */
function builtByTheE2EServer() {
  const meta = document.createElement("meta");
  meta.name = "rhc-autopilot";
  meta.content = "allowed";
  document.head.appendChild(meta);
}

afterEach(() => {
  document.head.querySelector(AUTOPILOT_META)?.remove();
});

describe("autopilotRequest", () => {
  it("is null until the page asks", () => {
    expect(autopilotRequest(page(true))).toBeNull();
    expect(autopilotRequest(page(true, true))).toBeNull();
  });

  it("carries the difficulty the page asked for", () => {
    expect(autopilotRequest(page(true, { difficulty: "hard" }))).toEqual({ difficulty: "hard" });
    expect(autopilotRequest(page(true, { difficulty: 3 }))).toEqual({ difficulty: undefined });
  });

  it("is null on a page the e2e server did not build, whatever the page asks", () => {
    expect(autopilotRequest(page(false, { difficulty: "hard" }))).toBeNull();
    expect(autopilotRequest({ [AUTOPILOT_GLOBAL]: { difficulty: "hard" } })).toBeNull();
  });
});

describe("createAutopilot", () => {
  const inputs = { left: ["ArrowLeft", "a"], fire: [" "] };

  it("presses a key once while the AI holds it and lets go when it stops", () => {
    const { target, heard } = listeningKeyboard();
    const pilot = createAutopilot({
      controller: scripted([{ left: true }, { left: true, fire: true }, { fire: true }, {}]),
      inputs,
      observe: () => ({}),
      target,
    });

    for (let i = 0; i < 4; i++) pilot.step();

    expect(heard).toEqual(["keydown ArrowLeft", "keydown  ", "keyup ArrowLeft", "keyup  "]);
    expect(pilot.held()).toEqual([]);
  });

  it("lets go of every held key on release", () => {
    const { target, heard } = listeningKeyboard();
    const pilot = createAutopilot({
      controller: scripted([{ left: true, fire: true }]),
      inputs,
      observe: () => ({}),
      target,
    });

    pilot.step();
    pilot.release();

    expect(heard.filter((line) => line.startsWith("keyup"))).toHaveLength(2);
    expect(pilot.held()).toEqual([]);
  });

  it("keeps what is held when the AI has no answer this step", () => {
    const { target, heard } = listeningKeyboard();
    const pilot = createAutopilot({
      controller: scripted([{ left: true }, null]),
      inputs,
      observe: () => ({}),
      target,
    });

    pilot.step();
    pilot.step();

    expect(heard).toEqual(["keydown ArrowLeft"]);
    expect(pilot.held()).toEqual(["left"]);
  });
});

describe("a seat on autopilot", () => {
  const play = matchPerTest({ gameId: "hex_invaders" });

  it("plays a solo match by itself, through the seat's keys", async () => {
    builtByTheE2EServer();
    vi.stubGlobal(AUTOPILOT_GLOBAL, { difficulty: "hard" });
    const match = await play({ mode: "solo" });

    match.advance(20_000);

    expect(match.engines.host.gameState.score1).toBeGreaterThan(0);
  });

  it("leaves the seat to the person when nothing asks for it", async () => {
    builtByTheE2EServer();
    const match = await play({ mode: "solo" });

    match.advance(20_000);

    expect(match.engines.host.gameState.score1).toBe(0);
  });

  it("leaves the seat to the person on a page any other build made", async () => {
    vi.stubGlobal(AUTOPILOT_GLOBAL, { difficulty: "hard" });
    const match = await play({ mode: "solo" });

    match.advance(20_000);

    expect(match.engines.host.gameState.score1).toBe(0);
  });

  it("plays the guest's seat over the wire", async () => {
    builtByTheE2EServer();
    vi.stubGlobal(AUTOPILOT_GLOBAL, { difficulty: "hard" });
    const match = await play({ mode: "p2p" });

    match.advance(20_000);

    expect(match.engines.host.gameState.score1).toBeGreaterThan(0);
    expect(match.engines.host.gameState.score2).toBeGreaterThan(0);
  });
});
