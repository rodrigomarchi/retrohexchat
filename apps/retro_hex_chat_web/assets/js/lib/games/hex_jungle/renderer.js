/**
 * Hex Jungle's picture. `layout` says what a screen shows, in the
 * cartridge's units; `render` paints it, scaled to the canvas: its 160 pixels
 * across, and 160 lines down — a top line for the points and the time, then
 * the jungle from the treetops to below the tunnel's floor.
 *
 * @module games/hex_jungle/renderer
 */

import { readGameColors } from "../../game_colors.js";
import { drawDigit, drawPixelSprite } from "../core/render.js";
import { floorAt, shiftingInset, treasureLies, vineX } from "./physics.js";
import {
  CROC_CYCLE,
  CROC_SHUT_TICKS,
  GROUND_Y,
  LADDER,
  OBJECT_X,
  PHASE,
  PIT,
  SCREEN_W,
  UNDER_Y,
  VINE_CENTER,
  VINE_HANG_Y,
  WALL_X,
} from "./protocol.js";
import { CROCODILE, EXPLORER, FIRE, LOG, SCORPION, SNAKE, TREASURES } from "./sprites.js";
import { decodeScene } from "./world.js";

/** The lines the picture spans: the top line, then the jungle from line -40. */
const HUD_LINES = 20;
const TOP_LINE = -40;
const LINES = 160;
const CANOPY_END = -10;
const TUNNEL_ROOF = 64;
const FLOOR_END = 92;
const CROCODILES_X = [60, 76, 92];
const PLAYER_H = 22;
const TREES = [
  [12, 44, 104, 136],
  [24, 56, 96, 128],
  [8, 40, 116, 148],
  [20, 52, 84, 140],
];

/**
 * The palette, from the canvas's CSS custom properties.
 * @param {HTMLCanvasElement} canvas
 * @returns {object}
 */
export function readColors(canvas) {
  return readGameColors(canvas, {
    bg: ["--game-bg-color", "0a1a0a"],
    fg: ["--game-fg-color", "33ff66"],
    canopy: ["--game-jungle-canopy-color", "1d5e1d"],
    leaves: ["--game-jungle-leaves-color", "2f8a2f"],
    trunk: ["--game-jungle-trunk-color", "5a3a1a"],
    ground: ["--game-jungle-ground-color", "8a6a2a"],
    earth: ["--game-jungle-earth-color", "4a3418"],
    tunnel: ["--game-jungle-tunnel-color", "120c06"],
    hole: ["--game-jungle-hole-color", "000000"],
    tar: ["--game-jungle-tar-color", "101010"],
    water: ["--game-jungle-water-color", "1f5fbf"],
    quicksand: ["--game-jungle-quicksand-color", "3f7fcf"],
    ladder: ["--game-jungle-ladder-color", "c8a040"],
    brick: ["--game-jungle-brick-color", "a83a2a"],
    mortar: ["--game-jungle-mortar-color", "6a2a1a"],
    vine: ["--game-jungle-vine-color", "3a7a2a"],
    helmet: ["--game-jungle-helmet-color", "e8dca0"],
    skin: ["--game-jungle-skin-color", "e0a070"],
    eye: ["--game-jungle-eye-color", "000000"],
    shirt: ["--game-jungle-shirt-color", "4a8a3a"],
    belt: ["--game-jungle-belt-color", "3a2a10"],
    trousers: ["--game-jungle-trousers-color", "b89850"],
    boots: ["--game-jungle-boots-color", "3a2410"],
    log: ["--game-jungle-log-color", "8a5a2a"],
    logRing: ["--game-jungle-log-ring-color", "c89a5a"],
    flame: ["--game-jungle-flame-color", "ff4a10"],
    flameCore: ["--game-jungle-flame-core-color", "ffdc30"],
    snake: ["--game-jungle-snake-color", "c8c820"],
    croc: ["--game-jungle-croc-color", "3a9a3a"],
    teeth: ["--game-jungle-teeth-color", "f0f0f0"],
    scorpion: ["--game-jungle-scorpion-color", "e8e8e8"],
    sting: ["--game-jungle-sting-color", "ff3030"],
    gold: ["--game-jungle-gold-color", "ffd030"],
    silver: ["--game-jungle-silver-color", "d0d8e0"],
    money: ["--game-jungle-money-color", "c8a060"],
    diamond: ["--game-jungle-diamond-color", "a0f0ff"],
    hud: ["--game-jungle-hud-color", "f0f0d0"],
  });
}

/**
 * The points, the time left as mm:ss and the spare lives, for the top line.
 * @param {object} state
 * @returns {{ score: string, time: string, spare: number }}
 */
export function hud(state) {
  const seconds = Math.floor(state.timerTicks / 60);
  const two = (n) => String(n).padStart(2, "0");
  return {
    score: String(state.score),
    time: `${two(Math.floor(seconds / 60))}:${two(seconds % 60)}`,
    spare: Math.max(0, state.lives - 1),
  };
}

function poseOf(state) {
  const { player } = state;
  if (player.onVine) return "hang";
  if (player.climbing) return "climb";
  if (player.kneeling) return "kneel";
  if (player.jumpTick !== null || player.y < floorAt(state, player.x)) return "jump";
  return Math.floor(player.x / 4) % 2 === 0 ? "stride" : "stand";
}

/**
 * What the screen shows now, back to front, in the cartridge's units.
 * @param {object} state
 * @param {number} [frame] - the frame being drawn, for what blinks and flickers
 * @returns {Array<{ kind: string, x: number, y: number, w?: number, h?: number }>}
 */
export function layout(state, frame = 0) {
  const scene = decodeScene(state.screen);
  const shapes = [];
  for (const [from, to] of scene.holes) {
    shapes.push({
      kind: "hole",
      x: from,
      y: GROUND_Y,
      w: to - from + 1,
      h: TUNNEL_ROOF - GROUND_Y,
    });
  }
  if (scene.ladder) {
    shapes.push({ kind: "ladder", x: LADDER.x - 4, y: GROUND_Y, w: 8, h: UNDER_Y - GROUND_Y });
  }
  if (scene.pit) {
    const inset = scene.pit.shifting ? shiftingInset(state.tick) : 0;
    if (inset !== null) {
      const x = PIT[0] + inset;
      const w = PIT[1] - inset - x + 1;
      const liquid = scene.pit.kind;
      shapes.push({ kind: "pit", x, y: GROUND_Y, w, h: 8, liquid });
    }
    if (scene.pit.crocodiles) {
      const open = state.tick % CROC_CYCLE >= CROC_SHUT_TICKS;
      for (const x of CROCODILES_X) shapes.push({ kind: "crocodile", x, y: GROUND_Y, open });
    }
  }
  const { wall, scorpion } = scene.underground;
  if (wall) {
    shapes.push({ kind: "wall", x: WALL_X[wall], y: TUNNEL_ROOF, w: 8, h: UNDER_Y - TUNNEL_ROOF });
  }
  if (scorpion) shapes.push({ kind: "scorpion", x: state.scorpionX, y: UNDER_Y - 8 });
  if (scene.vine) shapes.push({ kind: "vine", x: vineX(state.tick), y: VINE_HANG_Y - PLAYER_H });
  for (const log of state.logs) shapes.push({ kind: "log", x: log.x, y: GROUND_Y - 4 });
  if (scene.hazard?.kind === "fire" || scene.hazard?.kind === "snake") {
    shapes.push({ kind: scene.hazard.kind, x: OBJECT_X, y: GROUND_Y - 6 });
  }
  if (treasureLies(state)) {
    shapes.push({ kind: "treasure", x: OBJECT_X, y: GROUND_Y - 8, treasure: scene.treasure.kind });
  }
  const blinkedOut = state.phase === PHASE.DYING && Math.floor(frame / 6) % 2 === 1;
  if (!blinkedOut) {
    const { player } = state;
    shapes.push({
      kind: "player",
      x: player.x - 2,
      y: player.y - PLAYER_H,
      pose: poseOf(state),
      flip: player.facing < 0,
    });
  }
  return shapes;
}

/**
 * Draw the expedition as it stands.
 * @param {CanvasRenderingContext2D} ctx
 * @param {object} state
 * @param {object} colors
 * @param {number} frame
 */
export function render(ctx, state, colors, frame = 0) {
  const { width, height } = ctx.canvas;
  const view = {
    sx: width / SCREEN_W,
    sy: height / LINES,
    x: (x) => x * (width / SCREEN_W),
    y: (line) => (HUD_LINES + line - TOP_LINE) * (height / LINES),
  };
  const band = (color, from, to, x = 0, w = SCREEN_W) => {
    ctx.fillStyle = color;
    ctx.fillRect(view.x(x), view.y(from), w * view.sx, (to - from) * view.sy);
  };

  ctx.fillStyle = colors.bg;
  ctx.fillRect(0, 0, width, height);
  // The jungle stays below the top line: a player dropping back in from
  // above the trees never covers the points.
  const top = view.y(TOP_LINE);
  ctx.save();
  ctx.beginPath();
  ctx.rect(0, top, width, height - top);
  ctx.clip();
  drawJungle(band, colors, decodeScene(state.screen).trees);
  for (const shape of layout(state, frame)) paint(ctx, view, band, colors, shape, frame);
  ctx.restore();
  drawHud(ctx, view, colors, hud(state));
}

function drawJungle(band, colors, trees) {
  band(colors.canopy, TOP_LINE, CANOPY_END);
  for (let x = trees * 4; x < SCREEN_W; x += 16) {
    band(colors.leaves, CANOPY_END - 4, CANOPY_END, x, 8);
  }
  for (const x of TREES[trees]) band(colors.trunk, CANOPY_END, GROUND_Y, x, 4);
  band(colors.ground, GROUND_Y, GROUND_Y + 8);
  band(colors.earth, GROUND_Y + 8, TUNNEL_ROOF);
  band(colors.tunnel, TUNNEL_ROOF, UNDER_Y);
  band(colors.ground, UNDER_Y, FLOOR_END);
  band(colors.earth, FLOOR_END, LINES + TOP_LINE - HUD_LINES);
}

const LIQUIDS = { tar: "tar", swamp: "water", quicksand: "quicksand" };

function paint(ctx, view, band, colors, shape, frame) {
  const sprite = (rows, palette, flip = false) =>
    drawPixelSprite(ctx, rows, palette, view.x(shape.x), view.y(shape.y), view.sx, view.sy, {
      flip,
    });
  switch (shape.kind) {
    case "hole":
      band(colors.hole, shape.y, shape.y + shape.h, shape.x, shape.w);
      break;
    case "ladder":
      for (let line = shape.y; line < shape.y + shape.h; line += 5) {
        band(colors.ladder, line, line + 1, shape.x, shape.w);
      }
      band(colors.ladder, shape.y, shape.y + shape.h, shape.x, 1);
      band(colors.ladder, shape.y, shape.y + shape.h, shape.x + shape.w - 1, 1);
      break;
    case "pit":
      band(colors[LIQUIDS[shape.liquid]], shape.y, shape.y + shape.h, shape.x, shape.w);
      break;
    case "crocodile": {
      const rows = shape.open ? CROCODILE.open : CROCODILE.shut;
      drawPixelSprite(
        ctx,
        rows,
        { g: colors.croc, w: colors.teeth },
        view.x(shape.x),
        view.y(shape.y - rows.length + 2),
        view.sx,
        view.sy,
      );
      break;
    }
    case "wall":
      band(colors.brick, shape.y, shape.y + shape.h, shape.x, shape.w);
      for (let line = shape.y + 3; line < shape.y + shape.h; line += 4) {
        band(colors.mortar, line, line + 1, shape.x, shape.w);
      }
      break;
    case "scorpion":
      sprite(SCORPION, { x: colors.scorpion, e: colors.sting });
      break;
    case "vine":
      drawVine(ctx, view, colors, shape);
      break;
    case "log":
      sprite(LOG, { o: colors.log, O: colors.logRing });
      break;
    case "fire":
      sprite(FIRE[Math.floor(frame / 8) % 2], { r: colors.flame, y: colors.flameCore });
      break;
    case "snake":
      sprite(SNAKE, { n: colors.snake, e: colors.eye });
      break;
    case "treasure":
      sprite(TREASURES[shape.treasure], treasurePalette(colors, shape.treasure));
      break;
    case "player":
      sprite(
        EXPLORER[shape.pose],
        {
          h: colors.helmet,
          s: colors.skin,
          e: colors.eye,
          c: colors.shirt,
          b: colors.belt,
          p: colors.trousers,
          k: colors.boots,
        },
        shape.flip,
      );
      break;
    default:
      break;
  }
}

function treasurePalette(colors, kind) {
  const metal = {
    money: colors.money,
    silver: colors.silver,
    gold: colors.gold,
    ring: colors.gold,
  };
  return { t: metal[kind], T: colors.hud, $: colors.gold, d: colors.diamond, D: colors.hud };
}

function drawVine(ctx, view, colors, shape) {
  ctx.strokeStyle = colors.vine;
  ctx.lineWidth = view.sx;
  ctx.beginPath();
  ctx.moveTo(view.x(VINE_CENTER + 1), view.y(CANOPY_END));
  ctx.lineTo(view.x(shape.x + 1), view.y(shape.y));
  ctx.stroke();
}

function drawHud(ctx, view, colors, { score, time, spare }) {
  ctx.fillStyle = colors.hud;
  const pixel = view.sy * 1.5;
  // The digits sit in the middle of the top line, 7 pixels tall.
  const top = (view.y(TOP_LINE) - 7 * pixel) / 2;
  const digits = (text, x) => {
    let left = x;
    for (const char of text) {
      if (char === ":") {
        ctx.fillRect(left + pixel, top + 2 * pixel, pixel, pixel);
        ctx.fillRect(left + pixel, top + 4 * pixel, pixel, pixel);
        left += 3 * pixel;
      } else {
        drawDigit(ctx, Number(char), left, top, pixel);
        left += 6 * pixel;
      }
    }
  };
  digits(score, view.x(4));
  const right = ctx.canvas.width - view.x(4) - (time.length * 6 - 3) * pixel;
  digits(time, right);
  for (let i = 0; i < spare; i++) {
    ctx.fillRect(right - (i + 1) * 4 * pixel, top + pixel, 2 * pixel, 5 * pixel);
  }
}
