import { Browser, BrowserContext, Locator, Page, test } from "@playwright/test";
import { readFileSync } from "node:fs";
import path from "node:path";
import { CAMERA } from "./camera";
import { drawCursor } from "./cursor";
import { installTestCard } from "./media";
import { Recorder, Take } from "./recorder";

/**
 * The shot list: which scenes to film and how long each one lasts.
 *
 * It comes from the video project (`retro_hex_chat_videos`), which renders the
 * narration first and measures it, so a scene on screen lasts exactly as long
 * as the voice over it:
 *
 *   DIRECTOR_SHOTS=/abs/shots.json   { "episode": "01-overview",
 *                                      "shots": [{ "number": 1, "title": "...", "seconds": 24.6,
 *                                                  "cues": [{ "at": 0, "text": "..." }] }] }
 *   DIRECTOR_OUT=/abs/out/dir        each take lands in <out>/<NN>/
 */

/** A sentence of the narration and the second it starts at. */
export type Cue = { at: number; text: string };

export type Shot = {
  number: number;
  title: string;
  seconds: number;
  cues: Cue[];
};

type ShotList = { episode: string; shots: Shot[] };

/** Seconds a take may run past its narration before it fails. */
const OVERRUN_TOLERANCE = 0.25;

/** Seconds an action may reach its sentence late before the take fails. */
const LATE_CUE_TOLERANCE = 1.0;

function shotList(): ShotList {
  const file = process.env.DIRECTOR_SHOTS;
  if (!file)
    throw new Error("DIRECTOR_SHOTS is not set — run `make e2e.director`");
  return JSON.parse(readFileSync(file, "utf8")) as ShotList;
}

function outDir(): string {
  const dir = process.env.DIRECTOR_OUT;
  if (!dir)
    throw new Error("DIRECTOR_OUT is not set — run `make e2e.director`");
  return dir;
}

/** The shot for a scene, or a skip when this run's shot list does not ask for it. */
export function shotFor(number: number): Shot {
  const shot = shotList().shots.find((s) => s.number === number);
  test.skip(!shot, `scene ${number} is not in this shot list`);
  return shot!;
}

/**
 * A browser context that looks like a person's: camera size, a drawn pointer
 * (headless has none to film), no tips toast, and
 * a locale and time zone of its own rather than the filming machine's — the
 * viewer's clock and profile are on screen.
 */
export async function cameraContext(
  browser: Browser,
  nick: string,
): Promise<BrowserContext> {
  // viewport: null — the page takes the window, so the launch flags' scale holds.
  const ctx = await browser.newContext({
    viewport: null,
    locale: "en-US",
    timezoneId: "Europe/London",
  });
  await ctx.addInitScript(() => {
    window.localStorage.setItem("retro_hex_chat_tips_suppressed", "true");
  });
  await ctx.addInitScript(drawCursor);
  await installTestCard(ctx, nick);
  return ctx;
}

/** Waits on camera: the pause a person takes between two actions. */
export type Pace = (ms: number) => Promise<void>;

/**
 * Waits until the narration reaches the sentence containing `words`, so what
 * happens on screen lands with what is said about it. Arriving there more than
 * LATE_CUE_TOLERANCE after the sentence began fails the take: the action before
 * it is too slow for the words.
 */
export type CueWait = (words: string) => Promise<void>;

/** Moves the camera to another page — a tab the scene just opened. */
export type Follow = (page: Page) => Promise<void>;

/**
 * Tells the edit what the scene is about from now on: an element on the page
 * the camera is filming, or `null` for the whole frame. The edit zooms
 * towards it; nothing changes on screen while filming.
 */
export type Focus = (target: Locator | null) => Promise<void>;

export type Direction = {
  pace: Pace;
  cue: CueWait;
  follow: Follow;
  focus: Focus;
};

/**
 * Films one scene. `action` plays it; the camera then holds the last frame
 * until the narration ends. A scene whose action outlasts its narration fails:
 * the voice would end mid-gesture, so the action or the script has to change.
 */
export async function film(
  page: Page,
  shot: Shot,
  action: (direction: Direction) => Promise<void>,
): Promise<Take> {
  const dir = path.join(outDir(), String(shot.number).padStart(2, "0"));
  const startedAt = Date.now();
  const recorder = await Recorder.start(page, dir, CAMERA.frame);
  const pace: Pace = (ms) => page.waitForTimeout(ms);
  const cue: CueWait = async (words) => {
    const sentence = shot.cues.find((c) => c.text.includes(words));
    if (!sentence) {
      throw new Error(
        `scene ${shot.number} has no sentence containing "${words}"`,
      );
    }
    const late = (Date.now() - startedAt) / 1000 - sentence.at;
    if (late > LATE_CUE_TOLERANCE) {
      throw new Error(
        `scene ${shot.number} reached "${words}" ${late.toFixed(1)}s after it was said`,
      );
    }
    await pace(Math.max(0, -late * 1000));
  };

  const follow: Follow = async (next) => {
    // A region marked on one page means nothing on the next.
    recorder.mark(null);
    await recorder.follow(next);
  };
  const focus: Focus = async (target) => {
    if (!target) return recorder.mark(null);
    const box = await target.boundingBox();
    if (!box) throw new Error(`cannot focus on ${target}: it is not on screen`);
    // Boxes are CSS pixels; frames are CAMERA.scale times larger.
    const k = CAMERA.scale;
    recorder.mark({
      x: box.x * k,
      y: box.y * k,
      width: box.width * k,
      height: box.height * k,
    });
  };

  await action({ pace, cue, follow, focus });

  const acted = (Date.now() - startedAt) / 1000;
  if (acted > shot.seconds + OVERRUN_TOLERANCE) {
    await recorder.stop();
    throw new Error(
      `scene ${shot.number} acted for ${acted.toFixed(1)}s, narration is ${shot.seconds.toFixed(1)}s`,
    );
  }
  await pace(Math.max(0, shot.seconds * 1000 - (Date.now() - startedAt)));
  return recorder.stop();
}

/** Types like a person, one key at a time. */
export async function typeOnCamera(field: Locator, text: string) {
  await field.pressSequentially(text, { delay: 85 });
}

/**
 * Glides the pointer onto an element's header strip, the way a presenter
 * points at a panel. It aims at the top edge on purpose: resting over a row
 * inside — a user in the list — opens that row's hover card.
 */
export async function pointAt(page: Page, target: Locator) {
  const box = await target.boundingBox();
  if (!box) throw new Error(`cannot point at ${target}: it is not on screen`);
  await page.mouse.move(
    box.x + box.width / 2,
    box.y + Math.min(12, box.height / 2),
    {
      steps: 25,
    },
  );
}

/**
 * Parks the pointer where it hovers nothing. A pointer left where the last
 * click landed keeps that spot's hover state on screen — a message's reaction
 * bar, a button's highlight.
 */
export async function restCursor(page: Page) {
  await page.mouse.move(CAMERA.css.width - 4, CAMERA.css.height / 2, {
    steps: 12,
  });
}
