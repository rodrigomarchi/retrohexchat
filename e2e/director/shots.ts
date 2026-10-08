import { Browser, BrowserContext, Page, test } from "@playwright/test";
import { readFileSync } from "node:fs";
import path from "node:path";
import { CAMERA } from "./camera";
import { Recorder, Take } from "./recorder";

/**
 * The shot list: which scenes to film and how long each one lasts.
 *
 * It comes from the video project (`retro_hex_chat_videos`), which renders the
 * narration first and measures it, so a scene on screen lasts exactly as long
 * as the voice over it:
 *
 *   DIRECTOR_SHOTS=/abs/shots.json   { "episode": "01-overview",
 *                                      "shots": [{ "number": 1, "title": "...", "seconds": 24.6 }] }
 *   DIRECTOR_OUT=/abs/out/dir        each take lands in <out>/<NN>/
 */

export type Shot = { number: number; title: string; seconds: number };

type ShotList = { episode: string; shots: Shot[] };

/** Seconds a take may run past its narration before it fails. */
const OVERRUN_TOLERANCE = 0.25;

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

/** A browser context that looks like a person's: camera size, no tips toast. */
export async function cameraContext(browser: Browser): Promise<BrowserContext> {
  // viewport: null — the page takes the window, so the launch flags' scale holds.
  const ctx = await browser.newContext({ viewport: null, locale: "en-US" });
  await ctx.addInitScript(() => {
    window.localStorage.setItem("retro_hex_chat_tips_suppressed", "true");
  });
  return ctx;
}

/** Waits on camera: the pause a person takes between two actions. */
export type Pace = (ms: number) => Promise<void>;

/**
 * Films one scene. `action` plays it; the camera then holds the last frame
 * until the narration ends. A scene whose action outlasts its narration fails:
 * the voice would end mid-gesture, so the action or the script has to change.
 */
export async function film(
  page: Page,
  shot: Shot,
  action: (pace: Pace) => Promise<void>,
): Promise<Take> {
  const dir = path.join(outDir(), String(shot.number).padStart(2, "0"));
  const startedAt = Date.now();
  const recorder = await Recorder.start(page, dir, CAMERA.frame);
  const pace: Pace = (ms) => page.waitForTimeout(ms);

  await action(pace);

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
export async function typeOnCamera(page: Page, selector: string, text: string) {
  await page.locator(selector).pressSequentially(text, { delay: 85 });
}
