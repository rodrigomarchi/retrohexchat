import { BrowserContext, expect, Page } from "@playwright/test";
import { readFileSync } from "node:fs";
import path from "node:path";
import { enterThroughNewCard } from "../helpers/surfaceEntry";
import { enterAs, Look } from "../helpers/characters";

/**
 * Spaces on film: entering one, and keeping its avatars alive.
 *
 * The map is a canvas — there is no DOM for positions — so these wait on the
 * creator and the loading veil, and move people with the keys a player holds.
 */

/** Opens the channel's Space from the chat (card → new tab) and returns the tab. */
export async function openSpace(
  page: Page,
  ctx: BrowserContext,
): Promise<Page> {
  const space = await enterThroughNewCard(page, ctx, "space-open");
  await expect(space.getByTestId("space-character-creator")).toBeVisible({
    timeout: 15_000,
  });
  return space;
}

/** Makes a character in the door's creator, enters, and waits until the map has drawn. */
export async function pickAvatar(space: Page, avatar: Look | string) {
  await enterAs(space, avatar);
  await expect(space.getByTestId("space-loading")).toBeHidden({
    timeout: 20_000,
  });
}

/** Holds a direction key long enough to walk `steps` tiles (one per 150 ms). */
export async function walk(space: Page, key: string, steps: number) {
  await space.keyboard.down(key);
  await space.waitForTimeout(steps * 150 + 60);
  await space.keyboard.up(key);
}

const PACES: [string, string][] = [
  ["ArrowLeft", "ArrowRight"],
  ["ArrowUp", "ArrowDown"],
  ["ArrowRight", "ArrowLeft"],
  ["ArrowDown", "ArrowUp"],
];

/**
 * Keeps an avatar pacing near where it stands — out and back — until `stop`
 * resolves, so a crowd looks alive without drifting apart. `offset` staggers
 * people so they do not move in step.
 */
export async function wander(
  space: Page,
  offset: number,
  stopped: () => boolean,
) {
  await space.waitForTimeout(offset);
  for (let i = offset; !stopped(); i++) {
    const [out, back] = PACES[i % PACES.length];
    const steps = 1 + (i % 2);
    await walk(space, out, steps);
    await space.waitForTimeout(700 + (i % 3) * 400);
    if (stopped()) break;
    await walk(space, back, steps);
    await space.waitForTimeout(900 + (i % 2) * 500);
  }
}

type Spot = {
  x: number;
  y: number;
  nickname: string;
  pose?: string;
  hp?: number;
};

/** Where the islands are: every tile a character may stand on. */
type Ground = { width: number; height: number; blocked: Set<string> };

const tileKey = (x: number, y: number) => `${x},${y}`;

const groundCache = new Map<string, Ground>();

/**
 * The map's walkable tiles, read from the same file the server loads: void
 * between the islands and the props standing on them block a step. A
 * Construct's base room is read the same way; what was built in it is not in
 * the file, so a route there goes around nothing but the gate.
 */
function ground(mapId = "end_of_time"): Ground {
  const cached = groundCache.get(mapId);
  if (cached) return cached;
  const file = path.resolve(
    __dirname,
    `../../apps/retro_hex_chat/priv/maps/${mapId}.json`,
  );
  const map = JSON.parse(readFileSync(file, "utf8")) as {
    width: number;
    height: number;
    collision: { x: number; y: number; w: number; h: number }[];
  };
  const blocked = new Set<string>();
  for (const r of map.collision) {
    for (let y = r.y; y < r.y + r.h; y++)
      for (let x = r.x; x < r.x + r.w; x++) blocked.add(tileKey(x, y));
  }
  const built = { width: map.width, height: map.height, blocked };
  groundCache.set(mapId, built);
  return built;
}

const STEPS: [string, number, number][] = [
  ["ArrowUp", 0, -1],
  ["ArrowDown", 0, 1],
  ["ArrowLeft", -1, 0],
  ["ArrowRight", 1, 0],
];

/** The server's step cadence: a held key walks one tile this often. */
const STEP_MS = 150;

/** A route as runs of the same key: ["Up","Up","Left"] → [["Up",2],["Left",1]]. */
function stretches(keys: string[]): [string, number][] {
  const out: [string, number][] = [];
  for (const key of keys) {
    const last = out.at(-1);
    if (last && last[0] === key) last[1] += 1;
    else out.push([key, 1]);
  }
  return out;
}

/** A binary min-heap: the route search's open list. */
class Heap<T> {
  private items: T[] = [];
  constructor(private readonly less: (a: T, b: T) => number) {}
  get size() {
    return this.items.length;
  }
  push(item: T) {
    const a = this.items;
    a.push(item);
    for (let i = a.length - 1; i > 0; ) {
      const p = (i - 1) >> 1;
      if (this.less(a[i], a[p]) >= 0) break;
      [a[i], a[p]] = [a[p], a[i]];
      i = p;
    }
  }
  pop(): T | undefined {
    const a = this.items;
    const top = a[0];
    const last = a.pop();
    if (a.length && last !== undefined) {
      a[0] = last;
      for (let i = 0; ; ) {
        const l = 2 * i + 1;
        const r = l + 1;
        let m = i;
        if (l < a.length && this.less(a[l], a[m]) < 0) m = l;
        if (r < a.length && this.less(a[r], a[m]) < 0) m = r;
        if (m === i) break;
        [a[i], a[m]] = [a[m], a[i]];
        i = m;
      }
    }
    return top;
  }
}

/**
 * The keys that walk from one tile to another: fewest steps, and of those the
 * fewest turns, so a walk reads as a person heading somewhere rather than a
 * staircase — and each straight stretch can be one held key.
 */
function route(
  from: Spot,
  to: { x: number; y: number },
  mapId?: string,
): string[] {
  const { width, height, blocked } = ground(mapId);
  const TURN = 1;
  const STEP = 100;
  type State = { x: number; y: number; d: number; cost: number };
  const best = new Map<string, number>();
  const came = new Map<string, string | null>();
  const id = (x: number, y: number, d: number) => `${x},${y},${d}`;
  const open = new Heap<State>((a, b) => a.cost - b.cost);
  open.push({ x: from.x, y: from.y, d: -1, cost: 0 });
  best.set(id(from.x, from.y, -1), 0);
  came.set(id(from.x, from.y, -1), null);
  let goal: string | null = null;
  while (open.size) {
    const cur = open.pop()!;
    const curId = id(cur.x, cur.y, cur.d);
    if (cur.cost > (best.get(curId) ?? Infinity)) continue;
    if (cur.x === to.x && cur.y === to.y) {
      goal = curId;
      break;
    }
    STEPS.forEach(([, dx, dy], d) => {
      const nx = cur.x + dx;
      const ny = cur.y + dy;
      if (nx < 0 || ny < 0 || nx >= width || ny >= height) return;
      if (blocked.has(tileKey(nx, ny))) return;
      const cost = cur.cost + STEP + (cur.d >= 0 && cur.d !== d ? TURN : 0);
      const nid = id(nx, ny, d);
      if (cost < (best.get(nid) ?? Infinity)) {
        best.set(nid, cost);
        came.set(nid, curId);
        open.push({ x: nx, y: ny, d, cost });
      }
    });
  }
  if (!goal)
    throw new Error(`no way from ${from.x},${from.y} to ${to.x},${to.y}`);
  const keys: string[] = [];
  for (
    let at: string | null = goal;
    came.get(at!) !== null;
    at = came.get(at!)!
  ) {
    keys.unshift(STEPS[Number(at!.split(",")[2])][0]);
  }
  return keys;
}

/**
 * Someone standing in a Space, followed through their own socket.
 *
 * The map is a canvas, so where anybody stands is read from the frames the
 * server sends that page — the join reply's snapshot and every delta after it
 * — and walking is the arrow keys, one tile per press, along a route worked
 * out on the map file. Nothing here moves anyone the server would not.
 */
export class Walker {
  private spots = new Map<string, Spot>();
  private selfKey: string | null = null;
  // The map the last join landed on: a gate can take this page to another.
  private mapId = "end_of_time";

  /**
   * `onCamera`: this page is the one being filmed, in front. A tab behind it
   * gets no animation frames, so every action that waits for one takes a
   * second, and a held key never walks past its first step (the engine paces
   * a held key on its frames). Off camera, a line is submitted straight to
   * the form and a walk is one press per tile — the first keydown is a step
   * of its own, frames or not.
   */
  private constructor(
    readonly page: Page,
    private readonly onCamera: boolean,
  ) {}

  /** Attach before the page opens its socket: the join reply is the first word. */
  static follow(page: Page, { onCamera = false } = {}): Walker {
    const walker = new Walker(page, onCamera);
    page.on("websocket", (ws) => {
      if (!ws.url().includes("/socket/")) return;
      ws.on("framereceived", (frame) => walker.read(String(frame.payload)));
    });
    return walker;
  }

  private read(raw: string) {
    let msg: unknown[];
    try {
      msg = JSON.parse(raw);
    } catch {
      return;
    }
    const [, , topic, event, payload] = msg as [
      unknown,
      unknown,
      string,
      string,
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      any,
    ];
    if (typeof topic !== "string" || !topic.startsWith("space:")) return;
    if (event === "phx_reply" && payload?.response?.snapshot) {
      this.selfKey = payload.response.self_key;
      this.mapId = payload.response.map?.id ?? this.mapId;
      this.spots.clear();
      this.take(payload.response.snapshot.participants);
    } else if (event === "space_snapshot") {
      this.spots.clear();
      this.take(payload.participants);
    } else if (event === "space_delta") {
      this.take(payload.joined);
      this.take(payload.updates);
      for (const key of payload.left ?? []) this.spots.delete(key);
    }
  }

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  private take(participants: Record<string, any> | undefined) {
    for (const [key, p] of Object.entries(participants ?? {})) {
      const known = this.spots.get(key);
      this.spots.set(key, {
        x: p.x ?? known?.x,
        y: p.y ?? known?.y,
        nickname: p.nickname ?? known?.nickname,
        pose: p.pose ?? known?.pose,
        hp: p.hp ?? known?.hp,
      });
    }
  }

  /** Where this person stands, as the server last said. */
  async here(): Promise<Spot> {
    await expect
      .poll(() => (this.selfKey ? this.spots.has(this.selfKey) : false), {
        timeout: 20_000,
      })
      .toBe(true);
    return this.spots.get(this.selfKey!)!;
  }

  /** Where someone else stands, by nickname. */
  where(nickname: string): Spot | undefined {
    return [...this.spots.values()].find(
      (s) => s.nickname?.toLowerCase() === nickname.toLowerCase(),
    );
  }

  /**
   * Walks to a tile. Each straight stretch of the route is one held key —
   * the engine paces a held key to the server's own step cadence — and
   * whatever the server corrected on the way is walked again from where it
   * says this person stands. `pace` only slows the corrections.
   */
  async goTo(target: { x: number; y: number }, pace = 165) {
    for (let attempt = 0; attempt < 4; attempt++) {
      const from = await this.here();
      if (from.x === target.x && from.y === target.y) return;
      const keys = route(from, target, this.mapId);
      if (attempt === 0 && this.onCamera) {
        for (const [key, steps] of stretches(keys)) {
          await this.page.keyboard.down(key);
          await this.page.waitForTimeout(steps * STEP_MS - STEP_MS / 2);
          await this.page.keyboard.up(key);
          await this.page.waitForTimeout(40);
        }
      } else {
        for (const key of keys) {
          await this.page.keyboard.press(key);
          await this.page.waitForTimeout(pace);
        }
      }
      try {
        await expect
          .poll(
            async () => {
              const at = await this.here();
              return at.x === target.x && at.y === target.y;
            },
            { timeout: 600 },
          )
          .toBe(true);
        return;
      } catch {
        // Short or long by a step or two: walk on from where the server says.
      }
    }
    const at = await this.here();
    throw new Error(`walked to ${at.x},${at.y}, not ${target.x},${target.y}`);
  }

  /** Walks to the tile beside someone, the side nearest to here. */
  async nextTo(nickname: string, pace = 180) {
    const other = this.where(nickname);
    if (!other) throw new Error(`${nickname} is not in this space`);
    const { blocked } = ground(this.mapId);
    const me = await this.here();
    const sides = STEPS.map(([, dx, dy]) => ({
      x: other.x + dx,
      y: other.y + dy,
    }))
      .filter((s) => !blocked.has(tileKey(s.x, s.y)))
      .sort(
        (a, b) =>
          Math.abs(a.x - me.x) +
          Math.abs(a.y - me.y) -
          (Math.abs(b.x - me.x) + Math.abs(b.y - me.y)),
      );
    await this.goTo(sides[0], pace);
  }

  /** Says a line in the Space's say line: it becomes their bubble. */
  async say(text: string, typing = 0) {
    const line = this.page.getByTestId("space-say-input");
    if (!this.onCamera) {
      await line.evaluate((el, value) => {
        const input = el as HTMLInputElement;
        input.value = value;
        input.dispatchEvent(new Event("input", { bubbles: true }));
        input.form!.requestSubmit();
      }, text);
      return;
    }
    if (typing > 0) {
      // A word at a time: per-key typing on a page drawing a map at 1080p is
      // slower than the line it belongs to.
      await line.click();
      for (const [i, word] of text.split(" ").entries()) {
        await this.page.keyboard.insertText(i === 0 ? word : ` ${word}`);
        await this.page.waitForTimeout(typing);
      }
    } else {
      await line.fill(text);
    }
    await line.press("Enter");
    await expect(line).toHaveValue("", { timeout: 5_000 });
    // The keyboard goes back to the map, so the next walk is a walk. Not
    // Escape: in fullscreen it is also the browser's way out.
    await line.evaluate((el) => (el as HTMLElement).blur());
  }
}
