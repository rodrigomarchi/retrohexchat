import { Browser, BrowserContext, Locator, Page, test } from "@playwright/test";
import { mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import path from "node:path";
import { CAMERA } from "./camera";
import { drawCursor } from "./cursor";
import { installCharacterCamera, installTestCard } from "./media";
import { Box, Frame, Mark, Recorder, Take } from "./recorder";

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

/**
 * A sentence of the narration and the second it starts at — or, with `who`,
 * a line one of the people on film says: never narrated, the narration pauses
 * for `seconds` while it is on screen.
 */
export type Cue = { at: number; text: string; who?: string; seconds?: number };

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
 * (headless has none to film), and
 * a locale and time zone of its own rather than the filming machine's — the
 * viewer's clock and profile are on screen.
 */
export async function cameraContext(
  browser: Browser,
  nick: string,
  options: {
    /** What their camera shows: a test card, or an animated character. */
    face?: "test-card" | "character";
    timezoneId?: string;
  } = {},
): Promise<BrowserContext> {
  // viewport: null — the page takes the window, so the launch flags' scale holds.
  const ctx = await browser.newContext({
    viewport: null,
    locale: "en-US",
    timezoneId: options.timezoneId ?? "Europe/London",
  });
  await ctx.addInitScript(drawCursor);
  if (options.face === "character") await installCharacterCamera(ctx, nick);
  else await installTestCard(ctx, nick);
  return ctx;
}

/**
 * Off camera, after signing in: this person has already said "Don't show tips
 * again". Tips are their own setting, kept on the server and read when the chat
 * opens — so it is saved, then the page reloads to read it, and no tip opens
 * over a scene.
 */
export async function turnTipsOff(page: Page, nick: string): Promise<void> {
  const saved = await page.request.post("/api/e2e/contextual-tips/suppress", {
    data: { nickname: nick },
  });
  if (!saved.ok()) {
    throw new Error(`could not turn tips off for ${nick}: ${saved.status()}`);
  }
  await page.reload();
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
    await waitForCue(page, shot, startedAt, words);
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
  if (REHEARSAL) {
    console.log(
      `[rehearsal] scene ${shot.number} acted ${acted.toFixed(1)}s of ${shot.seconds.toFixed(1)}s`,
    );
  }
  if (acted > shot.seconds + OVERRUN_TOLERANCE) {
    const message = `scene ${shot.number} acted for ${acted.toFixed(1)}s, narration is ${shot.seconds.toFixed(1)}s`;
    if (!REHEARSAL) await recorder.stop();
    rehearse(message);
  }
  await pace(Math.max(0, shot.seconds * 1000 - (Date.now() - startedAt)));
  return recorder.stop();
}

/**
 * Rehearsal (`DIRECTOR_REHEARSAL=1`): a late cue or an overrun is reported
 * instead of failing the take, so one run measures how much narration every
 * beat of a scene really needs.
 */
const REHEARSAL = !!process.env.DIRECTOR_REHEARSAL;

function rehearse(message: string): void {
  if (!REHEARSAL) throw new Error(message);
  console.log(`[rehearsal] ${message}`);
}

/** The cue that is `words`, else the first that contains them, or a failed take. */
function findCue(shot: Shot, words: string): Cue {
  const sentence =
    shot.cues.find((c) => c.text === words) ??
    shot.cues.find((c) => c.text.includes(words));
  if (!sentence) {
    throw new Error(
      `scene ${shot.number} has no sentence containing "${words}"`,
    );
  }
  return sentence;
}

async function waitForCue(
  page: Page,
  shot: Shot,
  startedAt: number,
  words: string,
): Promise<Cue> {
  const sentence = findCue(shot, words);
  const late = (Date.now() - startedAt) / 1000 - sentence.at;
  if (late > LATE_CUE_TOLERANCE) {
    rehearse(
      `scene ${shot.number} reached "${words}" ${late.toFixed(1)}s after it was said`,
    );
  }
  await page.waitForTimeout(Math.max(0, -late * 1000));
  return sentence;
}

/**
 * How the edit shows a crew: one person's screen (`full`), two side by side
 * (`split`, left then right), or one with the other in a corner (`pip`, main
 * then corner).
 */
export type LayoutKind = "full" | "split" | "pip";
export type Layout = { at: number; kind: LayoutKind; cameras: string[] };

export type CrewDirection = Direction & {
  /** From now on, the edit shows these cameras this way. */
  layout: (kind: LayoutKind, ...cameras: string[]) => void;
  /**
   * Waits for a line one of the people says (a cue with `who`), then makes
   * their character talk for as long as it is on screen.
   */
  talk: (words: string) => Promise<void>;
  /** Makes a person's character wave. */
  wave: (who: string, seconds?: number) => Promise<void>;
};

type CrewTake = {
  seconds: number;
  width: number;
  height: number;
  cameras: { name: string; frames: Frame[]; marks: Mark[] }[];
  layouts: Layout[];
};

/**
 * Films one scene with a camera on each of several people at once — each
 * person's own browser, named by their nick. Every camera records the whole
 * take on one clock; `layout` tells the edit which of them to show, and how.
 * `follow` and `focus` act on the camera whose browser the page or element
 * belongs to.
 */
export async function filmCrew(
  cameras: Record<string, Page>,
  shot: Shot,
  action: (direction: CrewDirection) => Promise<void>,
  initial: { kind: LayoutKind; cameras: string[] },
  /**
   * People on the call who are not filmed but are seen on someone's screen:
   * their page, so their lines make their own portrait talk.
   */
  voices: Record<string, Page> = {},
): Promise<CrewTake> {
  const dir = path.join(outDir(), String(shot.number).padStart(2, "0"));
  rmSync(dir, { recursive: true, force: true });
  mkdirSync(dir, { recursive: true });
  const names = Object.keys(cameras);
  const contexts = new Map(names.map((n) => [cameras[n].context(), n]));
  const current = new Map(names.map((n) => [n, cameras[n]]));
  const startedAt = Date.now();
  const recorders = new Map<string, Recorder>();
  for (const name of names) {
    recorders.set(
      name,
      await Recorder.start(cameras[name], dir, CAMERA.frame, {
        prefix: `cams/${name}/`,
        startedAt,
      }),
    );
  }
  const elapsed = () => (Date.now() - startedAt) / 1000;
  const layouts: Layout[] = [];
  const known = (camera: string) => {
    if (!recorders.has(camera)) {
      throw new Error(`no camera named ${camera} (${names.join(", ")})`);
    }
  };
  const layout = (kind: LayoutKind, ...shown: string[]) => {
    shown.forEach(known);
    const wanted = kind === "full" ? 1 : 2;
    if (shown.length !== wanted) {
      throw new Error(
        `a ${kind} layout shows ${wanted} camera(s), not ${shown}`,
      );
    }
    layouts.push({ at: elapsed(), kind, cameras: shown });
  };
  layout(initial.kind, ...initial.cameras);
  // The opening layout holds from the first frame.
  layouts[0].at = 0;

  const cameraOf = (page: Page): string => {
    const name = contexts.get(page.context());
    if (!name) throw new Error(`no camera films ${page.url()}`);
    return name;
  };
  const anyPage = () => cameras[names[0]];
  const pace: Pace = (ms) => anyPage().waitForTimeout(ms);
  const cue: CueWait = async (words) => {
    await waitForCue(anyPage(), shot, startedAt, words);
  };
  const follow: Follow = async (next) => {
    const name = cameraOf(next);
    const recorder = recorders.get(name)!;
    recorder.mark(null);
    await recorder.follow(next);
    current.set(name, next);
  };
  const focus: Focus = async (target) => {
    if (!target) {
      for (const recorder of recorders.values()) recorder.mark(null);
      return;
    }
    const recorder = recorders.get(cameraOf(target.page()))!;
    const box = await target.boundingBox();
    if (!box) throw new Error(`cannot focus on ${target}: it is not on screen`);
    const k = CAMERA.scale;
    recorder.mark({
      x: box.x * k,
      y: box.y * k,
      width: box.width * k,
      height: box.height * k,
    } satisfies Box);
  };
  const character = async (
    who: string,
    kind: "talk" | "wave",
    seconds: number,
  ) => {
    const page = current.get(who) ?? voices[who];
    if (!page) {
      throw new Error(
        `${who} is neither filmed nor a voice (${[...names, ...Object.keys(voices)].join(", ")})`,
      );
    }
    await page.evaluate(
      ([k, s]) =>
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        (window as any).__directorCamera[k as string](s as number),
      [kind, seconds] as const,
    );
  };
  const talk = async (words: string) => {
    const line = await waitForCue(anyPage(), shot, startedAt, words);
    if (!line.who) {
      throw new Error(`"${words}" is narration, not a line someone says`);
    }
    await character(line.who, "talk", line.seconds ?? 2);
  };
  const wave = (who: string, seconds = 2) => character(who, "wave", seconds);

  const stopAll = async () => {
    const takes = new Map<string, Take>();
    for (const [name, recorder] of recorders)
      takes.set(name, await recorder.end());
    return takes;
  };

  await action({ pace, cue, follow, focus, layout, talk, wave });

  const acted = elapsed();
  if (REHEARSAL) {
    console.log(
      `[rehearsal] scene ${shot.number} acted ${acted.toFixed(1)}s of ${shot.seconds.toFixed(1)}s`,
    );
  }
  if (acted > shot.seconds + OVERRUN_TOLERANCE) {
    const message = `scene ${shot.number} acted for ${acted.toFixed(1)}s, narration is ${shot.seconds.toFixed(1)}s`;
    if (!REHEARSAL) await stopAll();
    rehearse(message);
  }
  await pace(Math.max(0, shot.seconds * 1000 - (Date.now() - startedAt)));
  const takes = await stopAll();
  const first = takes.get(names[0])!;
  const take: CrewTake = {
    seconds: Math.max(...[...takes.values()].map((t) => t.seconds)),
    width: first.width,
    height: first.height,
    cameras: names.map((name) => ({
      name,
      frames: takes.get(name)!.frames,
      marks: takes.get(name)!.marks,
    })),
    layouts,
  };
  writeFileSync(path.join(dir, "take.json"), JSON.stringify(take, null, 2));
  return take;
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
