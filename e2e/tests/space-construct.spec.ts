/**
 * @section SP - Virtual Spaces
 * @flow SP17 [done] E at the End of Time's gate asks before going: No stays on the island, Yes opens the channel's Construct with the same character, and its white gate leads back
 * @flow SP18 [done] A piece placed from the Construct's palette is seen by everyone inside, can be dragged elsewhere and removed with a right-click, and the room is still built the next time it opens
 * @flow SP19 [done] A chair placed in the Construct can be sat in with F
 * @flow SP20 [done] On the touch pad, the hand button goes through the gate and sits down on a chair, as E and F do
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { readFileSync } from "node:fs";
import path from "node:path";
import { test, expect, Page } from "@playwright/test";
import {
  newSignedInUser,
  closeUsers,
  uniqueChannel,
  TestUser,
} from "../helpers/chatUsers";
import { shot } from "../helpers/screenshots";
import { Walker } from "../director/space";

// The tile in front of the End of Time's gate, which stands at (56,10).
const BEFORE_GATE = { x: 56, y: 11 };

type Item = { id: string; kind: string; x: number; y: number; dir: string };

/**
 * What a page knows about the Construct it stands in, read off its own socket:
 * the room in the join reply, then every layout broadcast after it.
 */
class RoomWatch {
  items: Item[] = [];
  revision = 0;

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
    } else if (
      event === "construct_layout" &&
      payload.revision > this.revision
    ) {
      this.items = payload.items;
      this.revision = payload.revision;
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
async function tilePoint(
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

async function walkIn(space: Page, avatar: string) {
  await space.getByTestId(`space-avatar-${avatar}`).click();
  await mapDrawn(space);
}

async function mapDrawn(space: Page) {
  await expect(space.getByTestId("channel-space-shell")).toBeVisible({
    timeout: 15_000,
  });
  await expect(space.getByTestId("space-loading")).toBeHidden({
    timeout: 20_000,
  });
}

/** From the End of Time's island, through the gate, into the Construct. */
async function enterConstruct(walker: Walker) {
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
async function openConstruct(user: TestUser, avatar: string) {
  const space = await user.chat.openSpace();
  const walker = Walker.follow(space);
  const room = RoomWatch.follow(space);
  await walkIn(space, avatar);
  await enterConstruct(walker);
  return { space, walker, room };
}

test.describe("The Construct", () => {
  test("the gate asks first, takes the character in, and its twin brings it back (SP17)", async ({
    browser,
  }) => {
    const host = await newSignedInUser(browser, "cg");
    try {
      const channel = uniqueChannel("cg");
      await host.chat.sendMessage(`/join ${channel}`);
      const space = await host.chat.openSpace();
      const walker = Walker.follow(space);
      await walkIn(space, "knight");

      await walker.goTo(BEFORE_GATE);
      await space.keyboard.press("e");
      const modal = space.getByTestId("space-modal");
      await expect(modal).toBeVisible();
      await expect(modal).toContainText("Construct");
      await shot(space, "construct-gate-question");

      // No: the question goes, the island stays.
      await space.getByTestId("space-modal-no").click();
      await expect(modal).toBeHidden();
      expect(space.url()).not.toContain("avatar=");

      // Yes, this time from the keyboard.
      await space.keyboard.press("e");
      await expect(modal).toBeVisible();
      await space.keyboard.press("Enter");
      await expect(space).toHaveURL(/\?avatar=knight/, { timeout: 15_000 });
      await mapDrawn(space);
      const shell = space.getByTestId("channel-space-shell");
      await expect(shell).toHaveAttribute("data-space-mode", "construct");
      await expect(shell).toHaveAttribute("data-avatar", "knight");
      await expect(space.getByTestId("construct-palette")).toBeVisible();
      await expect(space.getByTestId("space-say-input")).toHaveAttribute(
        "placeholder",
        new RegExp(channel.replace("#", "")),
      );
      await shot(space, "construct-empty");

      // The white gate, in the far corner, is one step left and one up away.
      const inside = await walker.here();
      await walker.goTo({ x: inside.x - 1, y: inside.y - 1 });
      await space.keyboard.press("e");
      await expect(modal).toContainText("End of Time");
      await space.getByTestId("space-modal-yes").click();
      await expect(space.getByTestId("construct-palette")).toBeHidden({
        timeout: 15_000,
      });
      await mapDrawn(space);
      await expect(shell).toHaveAttribute("data-space-mode", "channel");
      await expect(shell).toHaveAttribute("data-avatar", "knight");
    } finally {
      await closeUsers([host]);
    }
  });

  test("building is shared, can be undone, and lasts (SP18)", async ({
    browser,
  }) => {
    const host = await newSignedInUser(browser, "cb");
    const guest = await newSignedInUser(browser, "cv");
    try {
      const channel = uniqueChannel("cb");
      await host.chat.sendMessage(`/join ${channel}`);
      await guest.chat.sendMessage(`/join ${channel}`);

      const a = await openConstruct(host, "archer");
      const b = await openConstruct(guest, "monk");
      const self = await a.walker.here();

      // Place a tree three tiles down the room, with the ghost shown first.
      await a.space.getByTestId("construct-kind-tree").click();
      await expect(a.space.getByTestId("construct-kind-tree")).toHaveAttribute(
        "data-selected",
        "true",
      );
      const spot = { x: self.x + 3, y: self.y + 3 };
      const at = await tilePoint(a.space, self, spot);
      await a.space.mouse.move(at.x, at.y);
      await shot(a.space, "construct-ghost");
      await a.space.mouse.click(at.x, at.y);

      for (const room of [a.room, b.room]) {
        await expect
          .poll(() => room.items.map((i) => `${i.kind}@${i.x},${i.y}`))
          .toEqual([`tree@${spot.x},${spot.y}`]);
      }
      await shot(b.space, "construct-tree-seen-by-guest");

      // The same tile again is refused, and the status line says why.
      // (After the per-person pause between edits, which has a sentence of its own.)
      await a.space.waitForTimeout(300);
      await a.space.mouse.click(at.x, at.y);
      await expect(a.space.getByTestId("construct-status")).toContainText(
        "already",
      );

      // Put it down, then drag the tree two tiles across.
      await a.space.keyboard.press("Escape");
      const to = { x: spot.x + 2, y: spot.y };
      const toAt = await tilePoint(a.space, self, to);
      await a.space.mouse.move(at.x, at.y - 4);
      await a.space.mouse.down();
      await a.space.mouse.move(toAt.x, toAt.y - 4, { steps: 6 });
      await a.space.mouse.up();
      await expect
        .poll(() => b.room.items.map((i) => `${i.x},${i.y}`))
        .toEqual([`${to.x},${to.y}`]);

      // Leave and come back: the room is as it was left.
      await b.space.close();
      await a.space.reload();
      await mapDrawn(a.space);
      await expect
        .poll(() => a.room.items.map((i) => `${i.x},${i.y}`))
        .toEqual([`${to.x},${to.y}`]);
      await shot(a.space, "construct-reopened");

      // A right-click removes it.
      const back = await a.walker.here();
      const treeAt = await tilePoint(a.space, back, to);
      await a.space.mouse.click(treeAt.x, treeAt.y - 4, { button: "right" });
      await expect.poll(() => a.room.items).toEqual([]);
    } finally {
      await closeUsers([host, guest]);
    }
  });

  test("a placed chair can be sat in (SP19)", async ({ browser }) => {
    const host = await newSignedInUser(browser, "cs");
    try {
      const channel = uniqueChannel("cs");
      await host.chat.sendMessage(`/join ${channel}`);
      const { space, walker, room } = await openConstruct(host, "cleric");
      const self = await walker.here();

      const chairTile = { x: self.x + 2, y: self.y };
      await space.getByTestId("construct-kind-chair").click();
      const at = await tilePoint(space, self, chairTile);
      await space.mouse.click(at.x, at.y);
      await space.keyboard.press("Escape");
      await expect.poll(() => room.items.length).toBe(1);

      await walker.goTo({ x: self.x + 1, y: self.y });
      await space.keyboard.press("f");
      await expect.poll(async () => (await walker.here()).pose).toBe("sitting");
      await shot(space, "construct-seated");
    } finally {
      await closeUsers([host]);
    }
  });

  test("the pad's hand button goes through the gate and sits down (SP20)", async ({
    browser,
  }) => {
    const host = await newSignedInUser(browser, "cp");
    try {
      const channel = uniqueChannel("cp");
      await host.chat.sendMessage(`/join ${channel}`);
      const space = await host.chat.openSpace();
      const walker = Walker.follow(space);
      const room = RoomWatch.follow(space);
      await walkIn(space, "rogue");

      await walker.goTo(BEFORE_GATE);
      await space.getByTestId("space-pad-use").click();
      await expect(space.getByTestId("space-modal-yes")).toBeVisible();
      await shot(space, "construct-pad-use-gate");
      await space.getByTestId("space-modal-yes").click();
      await expect(space).toHaveURL(/\?avatar=rogue/, { timeout: 15_000 });
      await mapDrawn(space);

      const self = await walker.here();
      await space.getByTestId("construct-kind-chair").click();
      const at = await tilePoint(space, self, { x: self.x + 2, y: self.y });
      await space.mouse.click(at.x, at.y);
      await space.keyboard.press("Escape");
      await expect.poll(() => room.items.length).toBe(1);

      await walker.goTo({ x: self.x + 1, y: self.y });
      await space.getByTestId("space-pad-use").click();
      await expect.poll(async () => (await walker.here()).pose).toBe("sitting");
      await space.getByTestId("space-pad-use").click();
      await expect
        .poll(async () => (await walker.here()).pose)
        .toBe("standing");
    } finally {
      await closeUsers([host]);
    }
  });
});
