import { beforeEach, describe, expect, it, vi } from "vitest";

/**
 * A 2D context whose drawing calls are spies: every call the games'
 * renderers make, with the properties they set left at their defaults —
 * or at `props`.
 * @param {object} [props]
 * @returns {object}
 */
export function createMockCtx(props = {}) {
  return {
    fillStyle: "",
    strokeStyle: "",
    lineWidth: 0,
    globalAlpha: 1.0,
    globalCompositeOperation: "source-over",
    font: "",
    textAlign: "",
    textBaseline: "",
    shadowColor: "transparent",
    shadowBlur: 0,
    fillRect: vi.fn(),
    strokeRect: vi.fn(),
    fillText: vi.fn(),
    beginPath: vi.fn(),
    moveTo: vi.fn(),
    lineTo: vi.fn(),
    stroke: vi.fn(),
    fill: vi.fn(),
    arc: vi.fn(),
    arcTo: vi.fn(),
    ellipse: vi.fn(),
    setLineDash: vi.fn(),
    createRadialGradient: vi.fn(() => ({ addColorStop: vi.fn() })),
    createLinearGradient: vi.fn(() => ({ addColorStop: vi.fn() })),
    clearRect: vi.fn(),
    closePath: vi.fn(),
    translate: vi.fn(),
    rotate: vi.fn(),
    scale: vi.fn(),
    measureText: vi.fn(() => ({ width: 50 })),
    save: vi.fn(),
    restore: vi.fn(),
    ...props,
  };
}

/**
 * The neon palette Hex Pong and Block Breakers fall back to.
 * @returns {object}
 */
export function neonColors() {
  return {
    bg: "#0a0a1a",
    fg: "#00ffcc",
    accent: "#ff0066",
    muted: "#1a3a4a",
    glow: "rgba(0,255,204,0.2)",
    warning: "#ffaa00",
  };
}

/**
 * The text a context was asked to draw, in order.
 * @param {object} ctx - a context from createMockCtx
 * @returns {string[]}
 */
export function drawnTexts(ctx) {
  return ctx.fillText.mock.calls.map((call) => call[0]);
}

/**
 * The getColors tests every canvas game shares: a CSS custom property on the
 * canvas is read, and with none set each colour in `fallback` comes back.
 * @param {(canvas: HTMLCanvasElement) => object} getColors
 * @param {Record<string, string>} fallback - colours the game falls back to
 */
export function itReadsColors(getColors, fallback) {
  const onCanvas = (style, check) => {
    const canvas = document.createElement("canvas");
    style(canvas.style);
    document.body.appendChild(canvas);
    check(getColors(canvas));
    document.body.removeChild(canvas);
  };

  it("reads CSS custom properties from canvas", () => {
    onCanvas(
      (style) => style.setProperty("--game-bg-color", "#111111"),
      (colors) => expect(colors.bg).toBeDefined(),
    );
  });

  it("returns fallback colors when properties not set", () => {
    onCanvas(
      () => {},
      (colors) => {
        for (const [name, value] of Object.entries(fallback)) expect(colors[name]).toBe(value);
      },
    );
  });
}

/**
 * Draws each state on a fresh context, expecting none of them to throw.
 * @param {(ctx: object, state: object, colors: object, time: number) => void} render
 * @param {object[]} states
 * @param {object} colors
 */
export function expectRendersWithoutThrowing(render, states, colors) {
  for (const state of states) {
    expect(() => render(createMockCtx(), state, colors, 0)).not.toThrow();
  }
}

/**
 * The frame tests the bat-and-ball games share: GET READY at the centre
 * while a serve waits, and a radial vignette over the whole canvas last.
 * @param {object} game
 * @param {Function} game.render
 * @param {() => object} game.createInitialState
 * @param {{ SERVING: number, PLAYING: number }} game.PHASE
 * @param {number} game.width - the canvas width
 * @param {number} game.height - the canvas height
 * @param {() => { ctx: object, colors: object }} frame - this test's context and colours
 */
function itDrawsServeAndVignette(game, frame) {
  const { render, createInitialState, PHASE, width, height } = game;

  it("draws GET READY at the centre while a serve waits", () => {
    const { ctx, colors } = frame();
    render(ctx, { ...createInitialState(), phase: PHASE.SERVING }, colors, 0);
    expect(ctx.fillText).toHaveBeenCalledWith("GET READY", width / 2, height / 2);
  });

  itDrawsVignette(
    frame,
    (ctx, colors) => render(ctx, { ...createInitialState(), phase: PHASE.PLAYING }, colors, 0),
    width,
    height,
  );
}

/**
 * Declares that a frame drawn by `draw(ctx, colors)` ends with a radial
 * vignette over the whole canvas.
 * @param {() => { ctx: object, colors: object }} frame - this test's context and colours
 * @param {(ctx: object, colors: object) => void} draw
 * @param {number} width
 * @param {number} height
 */
export function itDrawsVignette(frame, draw, width, height) {
  it("frames every rendered frame with a radial gradient across the canvas", () => {
    const { ctx, colors } = frame();
    draw(ctx, colors);
    expect(ctx.createRadialGradient).toHaveBeenCalled();
    expect(ctx.fillRect).toHaveBeenLastCalledWith(0, 0, width, height);
  });
}

/**
 * The full-frame tests the bat-and-ball games share: every phase draws, and
 * so does a frame with a particle in flight.
 * @param {object} game
 * @param {Function} game.render
 * @param {() => object} game.createInitialState
 * @param {number[]} game.phases - every phase the game draws
 * @param {object} game.ended - what a finished state carries (who won)
 * @param {object} game.particle - one particle as the game keeps them
 * @param {number} game.playing - the game's PLAYING phase
 * @param {() => object} colors - this test's colours
 */
function itRendersEveryFrame(game, colors) {
  const { render, createInitialState, phases, ended, particle, playing } = game;
  const moving = { ballVX: 3, ballVY: 2 };

  it("renders all phases without throwing", () => {
    const states = phases.map((phase) => ({ ...createInitialState(), phase, ...ended, ...moving }));
    expectRendersWithoutThrowing(render, states, colors());
  });

  it("renders particles when present", () => {
    const state = { ...createInitialState(), phase: playing, ...moving, particles: [particle] };
    expectRendersWithoutThrowing(render, [state], colors());
  });
}

/**
 * The renderer tests Hex Pong and Block Breakers share, on a fresh context
 * and the neon palette for each: getColors, the serve and the vignette, and
 * every phase drawn.
 * @param {object} modules - the game's own
 * @param {{ CANVAS_W: number, CANVAS_H: number, createInitialState: () => object }} modules.physics
 * @param {{ getColors: Function, render: Function }} modules.renderer
 * @param {{ SERVING: number, PLAYING: number }} modules.PHASE
 * @param {object} frames
 * @param {number[]} [frames.morePhases] - phases the game draws beyond
 *   WAITING, COUNTDOWN, SERVING, PLAYING and FINISHED
 * @param {object} frames.ended - what a finished state carries (who won)
 * @param {object} frames.particle - one particle as the game keeps them
 */
export function describeBatAndBallBasics({ physics, renderer, PHASE }, frames) {
  const { WAITING, COUNTDOWN, SERVING, PLAYING, FINISHED } = PHASE;
  const game = {
    ...frames,
    phases: [WAITING, COUNTDOWN, SERVING, PLAYING, ...(frames.morePhases ?? []), FINISHED],
    render: renderer.render,
    createInitialState: physics.createInitialState,
    PHASE,
    playing: PHASE.PLAYING,
    width: physics.CANVAS_W,
    height: physics.CANVAS_H,
  };
  let ctx;
  let colors;

  beforeEach(() => {
    ctx = createMockCtx();
    colors = neonColors();
  });

  describe("getColors", () => {
    const { bg, fg, accent } = neonColors();
    itReadsColors(renderer.getColors, { bg, fg, accent });
  });

  describe("the serve and the vignette", () => {
    itDrawsServeAndVignette(game, () => ({ ctx, colors }));
  });

  describe("render (full frame)", () => {
    itRendersEveryFrame(game, () => colors);
  });
}

/**
 * Declares a test per scene that `render(ctx, state, colors, frame,
 * particles)` draws it without throwing. A scene is `{ name, state }`, with
 * a `frame` and `particles` where it needs them.
 * @param {Function} render
 * @param {object} colors
 * @param {{ name: string, state: object, frame?: number, particles?: object[] }[]} scenes
 */
export function itRendersEach(render, colors, scenes) {
  it.each(scenes)("renders $name without throwing", ({ state, frame = 0, particles = [] }) => {
    expect(() => render(createMockCtx(), state, colors, frame, particles)).not.toThrow();
  });
}

/**
 * The full-frame tests of a game's `render(ctx, state, colors, time)`: a
 * frame in play ends with the vignette over the whole canvas, and every
 * phase draws without throwing.
 * @param {object} game
 * @param {Function} game.render
 * @param {() => object} game.start - a fresh state of the game
 * @param {number} game.playing - its phase of play
 * @param {number[]} game.phases - every phase it draws
 * @param {object} [game.ended] - what the phases' states carry besides
 * @param {number} game.width
 * @param {number} game.height
 * @param {() => { ctx: object, colors: object }} frame - this test's context and colours
 */
export function describeFullFrames(
  { render, start, playing, phases, ended = {}, width, height },
  frame,
) {
  describe("the vignette", () => {
    itDrawsVignette(
      frame,
      (ctx, colors) => render(ctx, { ...start(), phase: playing }, colors, 0),
      width,
      height,
    );
  });

  describe("render (full frame)", () => {
    it("renders all phases without throwing", () => {
      const states = phases.map((phase) => ({ ...start(), phase, ...ended }));
      expectRendersWithoutThrowing(render, states, frame().colors);
    });
  });
}
