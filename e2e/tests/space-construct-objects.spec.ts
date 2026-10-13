/**
 * @section SP - Virtual Spaces
 * @flow SP21 [done] E switches a Construct lamp off and on and opens a door to walk through, and a second person inside sees both
 * @flow SP22 [done] E on a die rolls it: the face shows over the die and the roll is said in the channel's chat
 * @flow SP23 [done] Two teleporters placed in a Construct pair up, and E on one sends you to the other
 * @flow SP24 [done] Whoever put up a sign writes on it from its panel and the line floats over it; somebody else only reads it
 * @flow SP25 [done] A board shows the channel's topic, a screen the last picture posted, an arcade cabinet its games
 * @flow SP26 [done] Dragging across the floor from the Floor tab paints it, for everyone inside, and it is still painted the next time the room opens
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect, Page } from "@playwright/test";
import {
  newSignedInUser,
  closeUsers,
  uniqueChannel,
  TestUser,
} from "../helpers/chatUsers";
import { shot } from "../helpers/screenshots";
import {
  mapDrawn,
  openConstruct,
  RoomWatch,
  tilePoint,
  chooseInMenu,
} from "../helpers/construct";
import { Walker } from "../director/space";

type Spot = { x: number; y: number };

/** Place one piece from its tab, with the viewer standing at `self`. */
async function place(
  space: Page,
  walker: Walker,
  tab: "furniture" | "structure" | "fun",
  kind: string,
  tile: Spot,
) {
  const self = await walker.here();
  await chooseInMenu(space, tab, { kind });
  const at = await tilePoint(space, self, tile);
  await space.mouse.click(at.x, at.y);
  await space.keyboard.press("Escape");
  // Edits are paced per person; the next one waits its turn.
  await space.waitForTimeout(200);
}

function at(room: RoomWatch, tile: Spot) {
  return room.items.find((i) => i.x === tile.x && i.y === tile.y);
}

/** Stand next to a piece, on its left, and press E on it. */
async function use(space: Page, walker: Walker, tile: Spot) {
  await walker.goTo({ x: tile.x - 1, y: tile.y });
  await space.keyboard.press("e");
}

async function inChannel(users: TestUser[], prefix: string) {
  const channel = uniqueChannel(prefix);
  for (const user of users) await user.chat.sendMessage(`/join ${channel}`);
  return channel;
}

test.describe("The Construct's pieces", () => {
  test("a lamp switches and a door opens, for everyone inside (SP21)", async ({
    browser,
  }) => {
    const host = await newSignedInUser(browser, "ol");
    const guest = await newSignedInUser(browser, "om");
    try {
      await inChannel([host, guest], "ol");
      const a = await openConstruct(host, "ranger");
      const b = await openConstruct(guest, "monk");
      const self = await a.walker.here();

      const lamp = { x: self.x + 3, y: self.y + 4 };
      const door = { x: self.x + 3, y: self.y + 7 };
      await place(a.space, a.walker, "furniture", "lamp", lamp);
      await place(a.space, a.walker, "structure", "door", door);
      await expect.poll(() => b.room.items.length).toBe(2);

      await use(a.space, a.walker, lamp);
      await expect.poll(() => at(b.room, lamp)?.state?.on).toBe(false);
      await shot(b.space, "construct-lamp-off");
      await a.space.waitForTimeout(200);
      await a.space.keyboard.press("e");
      await expect.poll(() => at(b.room, lamp)?.state?.on).toBe(true);

      // A closed door is in the way; open, it is walked through.
      await use(a.space, a.walker, door);
      await expect.poll(() => at(b.room, door)?.state?.open).toBe(true);
      await shot(a.space, "construct-door-open");
      await a.walker.goTo({ x: door.x + 1, y: door.y });
      expect(await a.walker.here()).toMatchObject({ x: door.x + 1, y: door.y });
    } finally {
      await closeUsers([host, guest]);
    }
  });

  test("a die rolled is said in the chat (SP22)", async ({ browser }) => {
    const host = await newSignedInUser(browser, "od");
    try {
      await inChannel([host], "od");
      const { space, walker, room } = await openConstruct(host, "rogue");
      const self = await walker.here();
      const die = { x: self.x + 3, y: self.y + 3 };
      await place(space, walker, "fun", "die", die);
      await expect.poll(() => room.items.length).toBe(1);

      await use(space, walker, die);
      await expect.poll(() => at(room, die)?.state?.face).toBeGreaterThan(0);
      const face = at(room, die)!.state!.face;
      await expect
        .poll(() => room.labels.map((l) => l.text))
        .toContain(`${face}`);
      await shot(space, "construct-die-rolled");

      await expect(
        host.page
          .getByText(new RegExp(`threw the dice and got ${face}`))
          .first(),
      ).toBeVisible({ timeout: 10_000 });
    } finally {
      await closeUsers([host]);
    }
  });

  test("teleporters pair up and send you across the room (SP23)", async ({
    browser,
  }) => {
    const host = await newSignedInUser(browser, "ot");
    try {
      await inChannel([host], "ot");
      const { space, walker, room } = await openConstruct(host, "scout");
      const self = await walker.here();
      const near = { x: self.x + 3, y: self.y + 3 };
      const far = { x: self.x + 12, y: self.y + 9 };
      await place(space, walker, "fun", "teleporter", near);
      await place(space, walker, "fun", "teleporter", far);
      await expect
        .poll(() => room.items.filter((i) => i.state?.link).length)
        .toBe(2);

      await use(space, walker, near);
      await expect
        .poll(async () => {
          const here = await walker.here();
          return `${here.x},${here.y}`;
        })
        .toBe(`${far.x},${far.y}`);
      await shot(space, "construct-teleported");
    } finally {
      await closeUsers([host]);
    }
  });

  test("a sign is written by whoever put it up, and read by everyone (SP24)", async ({
    browser,
  }) => {
    const host = await newSignedInUser(browser, "os");
    const guest = await newSignedInUser(browser, "or");
    try {
      await inChannel([host, guest], "os");
      const a = await openConstruct(host, "bard");
      const self = await a.walker.here();
      const sign = { x: self.x + 3, y: self.y + 3 };
      await place(a.space, a.walker, "fun", "sign", sign);

      await use(a.space, a.walker, sign);
      const panel = a.space.getByTestId("space-panel");
      await expect(panel).toBeVisible();
      await shot(a.space, "construct-sign-panel");
      await a.space.getByTestId("space-panel-input").fill("Welcome in!");
      await a.space.keyboard.press("Enter");
      await expect(panel).toBeHidden();
      // Enter saved the sign and went no further: the say bar is not focused.
      await expect(a.space.getByTestId("space-say-input")).not.toBeFocused();
      await expect
        .poll(() => a.room.labels.map((l) => l.text))
        .toContain("Welcome in!");
      await shot(a.space, "construct-sign-written");

      // The guest is no operator and did not put the sign up: they read it.
      const b = await openConstruct(guest, "sailor");
      await use(b.space, b.walker, sign);
      const theirs = b.space.getByTestId("space-panel");
      await expect(theirs).toContainText("Welcome in!");
      await expect(b.space.getByTestId("space-panel-input")).toBeHidden();
      await b.space.getByTestId("space-panel-close").click();
      await expect(theirs).toBeHidden();
    } finally {
      await closeUsers([host, guest]);
    }
  });

  test("a board, a screen and an arcade cabinet open what the channel has (SP25)", async ({
    browser,
  }) => {
    const host = await newSignedInUser(browser, "ob");
    try {
      await inChannel([host], "ob");
      await host.chat.sendMessage("/topic Movie night at nine");
      await postPicture(host);

      const { space, walker, room } = await openConstruct(host, "mage");
      const self = await walker.here();
      const board = { x: self.x + 3, y: self.y + 3 };
      const screen = { x: self.x + 3, y: self.y + 6 };
      const arcade = { x: self.x + 3, y: self.y + 9 };
      await place(space, walker, "fun", "board", board);
      await place(space, walker, "fun", "screen", screen);
      await place(space, walker, "fun", "arcade", arcade);
      await expect.poll(() => room.items.length).toBe(3);

      const panel = space.getByTestId("space-panel");
      await use(space, walker, board);
      await expect(panel).toContainText("Movie night at nine");
      await shot(space, "construct-board");
      await space.keyboard.press("Escape");

      await use(space, walker, screen);
      const image = space.getByTestId("space-panel-image");
      await expect(image).toBeVisible();
      await expect
        .poll(() => image.evaluate((img: HTMLImageElement) => img.naturalWidth))
        .toBeGreaterThan(0);
      await shot(space, "construct-screen");
      await space.keyboard.press("Escape");

      await use(space, walker, arcade);
      const doom = space.getByTestId("space-panel-game-doom_shareware");
      await expect(doom).toHaveAttribute("href", "/play/arcade/doom_shareware");
      await expect(doom).toHaveAttribute("target", "_blank");
      await shot(space, "construct-arcade");
    } finally {
      await closeUsers([host]);
    }
  });

  test("painting the floor is shared and lasts (SP26)", async ({ browser }) => {
    const host = await newSignedInUser(browser, "of");
    const guest = await newSignedInUser(browser, "og");
    try {
      await inChannel([host, guest], "of");
      const a = await openConstruct(host, "wanderer");
      const b = await openConstruct(guest, "ranger");
      const self = await a.walker.here();

      await chooseInMenu(a.space, "floor", { material: "wood" });
      const from = { x: self.x + 2, y: self.y + 2 };
      const to = { x: self.x + 6, y: self.y + 5 };
      const start = await tilePoint(a.space, self, from);
      const end = await tilePoint(a.space, self, to);
      await a.space.mouse.move(start.x, start.y);
      await a.space.mouse.down();
      await a.space.mouse.move(end.x, end.y, { steps: 8 });
      await shot(a.space, "construct-floor-stroke");
      await a.space.mouse.up();

      const painted = (room: RoomWatch, t: Spot) => room.floor[t.y]?.[t.x];
      for (const room of [a.room, b.room]) {
        await expect.poll(() => painted(room, to)).toBe("1");
        expect(painted(room, from)).toBe("1");
        expect(painted(room, { x: to.x + 1, y: to.y })).toBe("w");
      }
      await shot(b.space, "construct-floor-painted");

      await b.space.close();
      await a.space.reload();
      await mapDrawn(a.space);
      await expect
        .poll(() => painted(a.room, { x: from.x + 1, y: from.y + 1 }))
        .toBe("1");
    } finally {
      await closeUsers([host, guest]);
    }
  });
});

// A small picture posted in the conversation, the way the composer posts one.
async function postPicture(user: TestUser) {
  const page = user.page;
  const input = page.locator(
    '#composer-region input[type="file"][name="attachments"]',
  );
  await expect(input).toHaveCount(1);
  const pending = page.getByTestId("chat-attachment-pending");
  await expect(async () => {
    await input.setInputFiles([]);
    await input.setInputFiles({
      name: `screen-${Date.now()}.bmp`,
      mimeType: "image/bmp",
      buffer: bitmap(64, 36),
    });
    await expect(pending).toContainText("100%", { timeout: 3_000 });
  }).toPass({ timeout: 15_000 });
  await user.chat.chatInput.fill("for the screen");
  await user.chat.chatSendButton.click();
  await expect(
    page.getByTestId("message-attachment-image-preview").last(),
  ).toBeVisible({
    timeout: 15_000,
  });
}

function bitmap(width: number, height: number): Buffer {
  const rowSize = Math.ceil((width * 3) / 4) * 4;
  const buffer = Buffer.alloc(54 + rowSize * height);
  buffer.write("BM", 0, "ascii");
  buffer.writeUInt32LE(buffer.length, 2);
  buffer.writeUInt32LE(54, 10);
  buffer.writeUInt32LE(40, 14);
  buffer.writeInt32LE(width, 18);
  buffer.writeInt32LE(height, 22);
  buffer.writeUInt16LE(1, 26);
  buffer.writeUInt16LE(24, 28);
  buffer.writeUInt32LE(rowSize * height, 34);
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      const o = 54 + y * rowSize + x * 3;
      buffer[o] = 200;
      buffer[o + 1] = (x * 4) % 256;
      buffer[o + 2] = (y * 7) % 256;
    }
  }
  return buffer;
}
