/**
 * The Construct, as a spec drives it: what a page knows of the room it stands
 * in (read off its own socket), where a tile is drawn on its canvas, and the
 * way in through the End of Time's gate.
 */
import { readFileSync } from "node:fs";
import path from "node:path";
import { expect, Page } from "@playwright/test";
import { TestUser } from "./chatUsers";
import { enterAs, Look } from "./characters";
import { Walker } from "../director/space";

// The tile in front of the End of Time's gate, which stands at (56,10).
export const BEFORE_GATE = { x: 56, y: 11 };

export type Item = {
  id: string;
  kind: string;
  x: number;
  y: number;
  dir: string;
  state?: Record<string, unknown>;
};

/**
 * What a page knows about the Construct it stands in, read off its own socket:
 * the room in the join reply, then every layout broadcast after it.
 */
export class RoomWatch {
  items: Item[] = [];
  revision = 0;
  labels: { text: string; x: number; y: number }[] = [];
  floor: string[] = [];

  static follow(page: Page): RoomWatch {
    const watch = new RoomWatch();
    page.on("websocket", (ws) => {
      if (!ws.url().includes("/socket/")) return;
      ws.on("framereceived", (frame) => watch.read(String(frame.payload)));
    });
    return watch;
  }

  private read(raw: string) {
    let msg: unknown[];
    try {
      msg = JSON.parse(raw);
    } catch {
      return;
    }
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const [, , topic, event, payload] = msg as [
      unknown,
      unknown,
      string,
      string,
      any,
    ];
    if (typeof topic !== "string" || !topic.startsWith("space:construct:"))
      return;
    if (event === "phx_reply" && payload?.response?.map?.id === "construct") {
      this.items = payload.response.map.items ?? [];
      this.revision = payload.response.map.revision ?? 0;
      this.labels = payload.response.map.labels ?? [];
      this.floor = payload.response.map.layers?.floor ?? [];
    } else if (
      event === "construct_layout" &&
      payload.revision > this.revision
    ) {
      this.items = payload.items;
      this.revision = payload.revision;
      this.labels = payload.labels ?? [];
      if (payload.floor) this.floor = payload.floor;
    }
  }
}

// The Construct's geometry, read from the same file the server loads, so a
// tile can be turned into the point of the canvas it is drawn at.
const CONSTRUCT = JSON.parse(
  readFileSync(
    path.resolve(
      __dirname,
      "../../apps/retro_hex_chat/priv/maps/construct.json",
    ),
    "utf8",
  ),
) as {
  width: number;
  height: number;
  iso: { tile_w: number; tile_h: number; z_step: number; headroom: number };
};

/**
 * Where a tile's diamond centre is on screen, the way the engine draws it:
 * the isometric projection at scale 1, and a camera centred on the viewer's
 * own tile, clamped to the world.
 */
export async function tilePoint(
  page: Page,
  self: { x: number; y: number },
  tile: { x: number; y: number },
): Promise<{ x: number; y: number }> {
  const canvas = page.locator('[data-testid="channel-space-shell"] > canvas');
  const box = await canvas.evaluate((el: HTMLCanvasElement) => {
    const r = el.getBoundingClientRect();
    return {
      left: r.left,
      top: r.top,
      cssW: r.width,
      cssH: r.height,
      w: el.width,
      h: el.height,
    };
  });
  const { width, height, iso } = CONSTRUCT;
  const hw = iso.tile_w / 2;
  const hh = iso.tile_h / 2;
  const originX = height * hw + hw;
  const originY = hh + iso.headroom * iso.z_step;
  const worldW = (width + height) * hw + 2 * hw;
  const worldH = (width + height) * hh + originY + iso.headroom * iso.z_step;
  const foot = (t: { x: number; y: number }) => ({
    x: (t.x - t.y) * hw + originX,
    y: (t.x + t.y) * hh + originY,
  });
  const clamp = (v: number, max: number) =>
    max <= 0 ? 0 : Math.min(Math.max(v, 0), max);
  const me = foot(self);
  const camX = clamp(me.x - box.w / 2, worldW - box.w);
  const camY = clamp(me.y - box.h / 2, worldH - box.h);
  const at = foot(tile);
  return {
    x: box.left + ((at.x - camX) * box.cssW) / box.w,
    y: box.top + ((at.y - camY) * box.cssH) / box.h,
  };
}

/** Makes `avatar` in the door's creator, walks in, and waits for the map. */
export async function walkIn(space: Page, avatar: Look | string) {
  await enterAs(space, avatar);
  await mapDrawn(space);
}

export async function mapDrawn(space: Page) {
  await expect(space.getByTestId("channel-space-shell")).toBeVisible({
    timeout: 15_000,
  });
  await expect(space.getByTestId("space-loading")).toBeHidden({
    timeout: 20_000,
  });
}

/** From the End of Time's island, through the gate, into the Construct. */
export async function enterConstruct(walker: Walker) {
  const space = walker.page;
  await walker.goTo(BEFORE_GATE);
  await space.keyboard.press("e");
  await expect(space.getByTestId("space-modal-yes")).toBeVisible();
  await space.getByTestId("space-modal-yes").click();
  await expect(space).toHaveURL(/\?avatar=/, { timeout: 15_000 });
  await mapDrawn(space);
  await expect(space.getByTestId("construct-palette")).toBeVisible();
}

/** Into a channel's Space and straight through its gate. */
export async function openConstruct(user: TestUser, avatar: Look | string) {
  const space = await user.chat.openSpace();
  const walker = Walker.follow(space);
  const room = RoomWatch.follow(space);
  await walkIn(space, avatar);
  await enterConstruct(walker);
  return { space, walker, room };
}

/** Open the Build menu, if it is shut. */
export async function openBuildMenu(space: Page) {
  const palette = space.getByTestId("construct-palette");
  if ((await palette.getAttribute("data-open")) !== "true") {
    await space.getByTestId("construct-toggle").click();
  }
  await drawerSettled(space);
}

/** The drawer has slid all the way in: its whole box is on the screen. */
export async function drawerSettled(space: Page) {
  const drawer = space.getByTestId("construct-drawer");
  await expect(drawer).toBeVisible();
  await expect
    .poll(async () => {
      const box = await drawer.boundingBox();
      const size = space.viewportSize();
      if (!box || !size) return false;
      return box.x >= 0 && box.y >= 0 && box.y + box.height <= size.height + 1;
    })
    .toBe(true);
}

/** Shut the Build menu, if it is open (a phone shuts it on a choice). */
export async function closeBuildMenu(space: Page) {
  const palette = space.getByTestId("construct-palette");
  if ((await palette.getAttribute("data-open")) === "true") {
    await space.getByTestId("construct-close").click();
  }
  await expect(palette).toHaveAttribute("data-open", "false");
}

/**
 * Take a kind (or a floor, with `material`) in hand from the Build menu's tab,
 * and shut the menu so the floor is clear to click.
 */
export async function chooseInMenu(
  space: Page,
  tab: string,
  { kind, material }: { kind?: string; material?: string },
) {
  await openBuildMenu(space);
  await space.getByTestId(`construct-tab-${tab}`).click();
  await space
    .getByTestId(
      kind ? `construct-kind-${kind}` : `construct-material-${material}`,
    )
    .click();
  await closeBuildMenu(space);
  await expect(space.getByTestId("construct-holding")).toBeVisible();
}
