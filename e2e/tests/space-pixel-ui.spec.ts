/**
 * @section SP - Virtual Spaces
 * @flow SP30 [done] On a phone, the space's screens — the character creator, the build palette, the pad, a piece's panel — wear the space's pixel-art kit and fit the screen
 * @flow SP31 [done] A line said in Japanese or in Traditional Chinese is drawn over the speaker in the pixel font, that region's own glyphs fetched for it
 * @flow SP32 [done] A character who takes a hit shows the kit's HP bar under its nameplate until it is whole again
 * @flow SP33 [done] The Construct's pieces live in a Build menu; what is in hand shows on a card that turns, removes or drops it, so a touch screen can let go of a piece
 * @flow SP34 [done] An arcade cabinet shelves its games as cartridges, each with its cover, under the cabinet's own icon
 * @flow SP35 [done] The pad is held like a handheld (actions under the left thumb, the D-pad under the right) and the say bar carries the status on one line, on a desktop, a phone and a small phone in Russian
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect, Browser, Page } from "@playwright/test";
import {
  closeUsers,
  newSignedInUser,
  uniqueChannel,
  TestUser,
} from "../helpers/chatUsers";
import { shot } from "../helpers/screenshots";
import {
  BEFORE_GATE,
  RoomWatch,
  chooseInMenu,
  drawerSettled,
  mapDrawn,
  openBuildMenu,
  openConstruct,
  tilePoint,
  walkIn,
} from "../helpers/construct";
import { ChatPage } from "../pages/ChatPage";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { Walker } from "../director/space";

const PHONE = { width: 390, height: 844 };
const SMALL_PHONE = { width: 320, height: 640 };

/** A registered user whose browser has its own screen size and language. */
async function userWith(
  browser: Browser,
  prefix: string,
  { locale, viewport }: { locale?: string; viewport?: typeof PHONE } = {},
): Promise<TestUser> {
  const ctx = await browser.newContext({
    viewport,
    locale: locale?.replace("_", "-"),
    hasTouch: viewport !== undefined,
  });
  const page = await ctx.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);
  await connect.open(locale);
  await connect.enterNickname(nick);
  await connect.registerWithPassword("pass12345");
  await chat.waitUntilConnected();
  return { chat, connect, ctx, page, nick, password: "pass12345" };
}

async function inChannel(users: TestUser[], prefix: string) {
  const channel = uniqueChannel(prefix);
  for (const user of users) await user.chat.sendMessage(`/join ${channel}`);
  return channel;
}

async function say(space: Page, text: string) {
  const line = space.getByTestId("space-say-input");
  await line.fill(text);
  await line.press("Enter");
  await expect(line).toHaveValue("");
}

/**
 * The pad's halves sit in opposite bottom corners, and the say bar is one row:
 * the way back, the field, the count and the character key on one line, with
 * no second bar under it.
 */
async function handheldAndOneLine(space: Page) {
  const box = async (testid: string) =>
    (await space.getByTestId(testid).boundingBox())!;
  const stage = await box("channel-space-shell");
  const use = await box("space-pad-use");
  const up = (await space.locator('[data-space-pad-dir="up"]').boundingBox())!;
  expect(use.x + use.width).toBeLessThan(stage.x + stage.width / 2);
  expect(up.x).toBeGreaterThan(stage.x + stage.width / 2);

  const field = await box("space-say-input");
  const middle = field.y + field.height / 2;
  for (const id of [
    "space-back-to-chat",
    "space-say-send",
    "space-change-character",
    "space-status-count",
  ]) {
    const b = await box(id);
    expect(Math.abs(b.y + b.height / 2 - middle)).toBeLessThanOrEqual(4);
  }
  await expect(space.locator(".window-status-field--pixel")).toHaveCount(0);
}

/** The page is the screen: nothing scrolls it, either way. */
async function fitsTheScreen(space: Page) {
  const overflow = await space.evaluate(() => ({
    x: document.documentElement.scrollWidth - window.innerWidth,
    y: document.documentElement.scrollHeight - window.innerHeight,
    scrolled: window.scrollY,
  }));
  expect(overflow.x).toBeLessThanOrEqual(0);
  expect(overflow.y).toBeLessThanOrEqual(0);
  expect(overflow.scrolled).toBe(0);
}

test.describe("The space's pixel-art interface", () => {
  test("on a phone, every screen of the space wears the kit (SP30)", async ({
    browser,
  }) => {
    const host = await userWith(browser, "px", { viewport: PHONE });
    try {
      await inChannel([host], "px");
      const space = await host.chat.openSpace();
      const walker = Walker.follow(space);
      const room = RoomWatch.follow(space);
      await expect(space.getByTestId("space-character-creator")).toBeVisible();
      await expect(space.locator(".space-ui-panel").first()).toBeVisible();
      await fitsTheScreen(space);
      await shot(space, "phone-creator");

      await walkIn(space, "bard");
      await expect(space.getByTestId("space-virtual-pad")).toBeVisible();
      // One fullscreen glyph at a time: enter now, exit once it is full.
      const toggle = space.getByTestId("space-fullscreen-toggle");
      await expect(
        toggle.locator(".space-icon--fullscreen-enter"),
      ).toBeVisible();
      await expect(toggle.locator(".space-icon--fullscreen-exit")).toBeHidden();
      // The pad's keys are a thumb wide.
      for (const key of await space.locator(".space-pad-button").all()) {
        const box = (await key.boundingBox())!;
        expect(Math.min(box.width, box.height)).toBeGreaterThanOrEqual(44);
      }
      await handheldAndOneLine(space);
      await fitsTheScreen(space);
      await shot(space, "phone-map-pad-say");
      // Typing a line keeps the page still, and the status steps aside so
      // the line is the field's.
      await space.getByTestId("space-say-input").focus();
      await expect(space.getByTestId("space-status-count")).toBeHidden();
      const typing = (await space
        .getByTestId("space-say-input")
        .boundingBox())!;
      expect(typing.width).toBeGreaterThanOrEqual(250);
      await shot(space, "phone-say-typing");
      await fitsTheScreen(space);
      await space.getByTestId("space-say-input").press("Escape");
      await expect(space.getByTestId("space-status-count")).toBeVisible();

      // Through the gate: the question is the kit's panel too.
      await walker.goTo(BEFORE_GATE);
      await space.keyboard.press("e");
      await expect(space.getByTestId("space-modal-yes")).toBeVisible();
      await shot(space, "phone-gate-question");
      await space.getByTestId("space-modal-yes").click();
      await mapDrawn(space);
      await expect(space.getByTestId("construct-palette")).toBeVisible();
      // Shut, the menu is one key; open, it is a sheet over the floor.
      await expect(space.getByTestId("construct-drawer")).toBeHidden();
      await shot(space, "phone-construct-shut");
      await openBuildMenu(space);
      await space.getByTestId("construct-tab-fun").click();
      await fitsTheScreen(space);
      await shot(space, "phone-palette");
      // Choosing shuts the sheet; the card says what the next tap builds.
      await space.getByTestId("construct-kind-sign").click();
      await expect(space.getByTestId("construct-drawer")).toBeHidden();
      await expect(space.getByTestId("construct-holding")).toBeVisible();
      await shot(space, "phone-holding-sign");

      // A piece's panel, on the phone: put a sign up and read it.
      const self = await walker.here();
      const sign = { x: self.x + 2, y: self.y + 2 };
      const spot = await tilePoint(space, self, sign);
      await space.mouse.click(spot.x, spot.y);
      await space.keyboard.press("Escape");
      await walker.goTo({ x: sign.x - 1, y: sign.y });
      await space.keyboard.press("e");
      const panel = space.getByTestId("space-panel");
      await expect(panel).toBeVisible();
      await expect(space.getByTestId("space-panel-input")).toBeVisible();
      await fitsTheScreen(space);
      await shot(space, "phone-sign-panel");
      await space.getByTestId("space-panel-close").click();

      // A finger lets go of a piece from the card, and the next tap on the
      // floor builds nothing.
      const before = room.items.length;
      await chooseInMenu(space, "furniture", { kind: "chair" });
      await space.getByTestId("construct-drop").tap();
      await expect(space.getByTestId("construct-holding")).toBeHidden();
      const here = await walker.here();
      const floor = await tilePoint(space, here, {
        x: here.x + 1,
        y: here.y + 3,
      });
      await space.touchscreen.tap(floor.x, floor.y);
      await space.waitForTimeout(400);
      expect(room.items.length).toBe(before);

      // Dragging a finger over the map never scrolls the page.
      await space.mouse.move(floor.x, floor.y);
      await space.mouse.down();
      await space.mouse.move(floor.x, floor.y - 120, { steps: 6 });
      await space.mouse.up();
      await fitsTheScreen(space);
    } finally {
      await closeUsers([host]);
    }
  });

  for (const [locale, line, family] of [
    ["ja", "こんにちは、時の果てへようこそ", "RH Pixel JP"],
    ["zh_hant", "歡迎來到時間的盡頭", "RH Pixel TC"],
  ] as const) {
    test(`a line in ${locale} is drawn in the pixel font (SP31)`, async ({
      browser,
    }) => {
      const host = await userWith(browser, `cj${locale.slice(0, 2)}`, {
        locale,
      });
      try {
        await inChannel([host], "cj");
        const space = await host.chat.openSpace();
        await walkIn(space, "mage");
        await say(space, line);
        await expect(space.getByTestId("space-said")).toContainText(line);

        // The canvas asks for the glyphs it draws, and the region's own face —
        // not another region's, not the fallback — is the one that loads.
        await expect
          .poll(() =>
            space.evaluate(
              (f) =>
                [...document.fonts].some(
                  (face) =>
                    face.family.replace(/"/g, "") === f &&
                    face.status === "loaded",
                ),
              family,
            ),
          )
          .toBe(true);
        await shot(space, `bubble-${locale}`);
      } finally {
        await closeUsers([host]);
      }
    });
  }

  test("a hurt character shows the HP bar (SP32)", async ({ browser }) => {
    const host = await newSignedInUser(browser, "hp");
    const guest = await newSignedInUser(browser, "hg");
    try {
      await inChannel([host, guest], "hp");
      const a = await openConstruct(host, "ranger");
      const b = await openConstruct(guest, "sailor");
      const target = await a.walker.here();

      // The guest steps up to the host, facing them, and swings once.
      await b.walker.goTo({ x: target.x, y: target.y + 2 });
      await b.walker.goTo({ x: target.x, y: target.y + 1 });
      await b.space.locator("canvas").first().focus();
      await b.space.keyboard.press(" ");

      // One hit hurts and does not knock out: the bar is up, the ranger standing.
      await expect
        .poll(async () => (await a.walker.here()).hp ?? 100)
        .toBeLessThan(100);
      expect((await a.walker.here()).hp).toBeGreaterThan(0);
      // Back a step, so the attacker's own nameplate does not cover the bar.
      await b.walker.goTo({ x: target.x, y: target.y + 3 });
      await a.space.waitForTimeout(400);
      await shot(a.space, "hp-bar-after-a-hit");
    } finally {
      await closeUsers([host, guest]);
    }
  });

  test("the Build menu and the card of what is in hand (SP33)", async ({
    browser,
  }) => {
    const host = await newSignedInUser(browser, "bm");
    try {
      await inChannel([host], "bm");
      const { space, walker, room } = await openConstruct(host, "ranger");
      const self = await walker.here();

      // Shut, nothing but the Build key is over the room.
      await expect(space.getByTestId("construct-drawer")).toBeHidden();
      await expect(space.getByTestId("construct-holding")).toBeHidden();
      await shot(space, "construct-menu-shut");
      await space.keyboard.press("b");
      await drawerSettled(space);
      await shot(space, "construct-menu-open");
      await space.keyboard.press("b");
      await expect(space.getByTestId("construct-drawer")).toBeHidden();

      // In hand: the card names the piece; Drop lets go, and the floor is the
      // floor again.
      await chooseInMenu(space, "furniture", { kind: "chair" });
      await expect(space.getByTestId("construct-holding")).toContainText(
        "Chair",
      );
      await shot(space, "construct-holding-chair");
      await space.getByTestId("construct-drop").click();
      await expect(space.getByTestId("construct-holding")).toBeHidden();
      const empty = await tilePoint(space, self, {
        x: self.x + 2,
        y: self.y + 2,
      });
      await space.mouse.click(empty.x, empty.y);
      await space.waitForTimeout(400);
      expect(room.items).toHaveLength(0);

      // A placed piece, picked: the card removes it.
      await chooseInMenu(space, "furniture", { kind: "chair" });
      await space.mouse.click(empty.x, empty.y);
      await expect.poll(() => room.items.length).toBe(1);
      await space.getByTestId("construct-drop").click();
      await space.waitForTimeout(250);
      await space.mouse.click(empty.x, empty.y);
      await expect(space.getByTestId("construct-remove")).toBeEnabled();
      await shot(space, "construct-holding-picked");
      await space.getByTestId("construct-remove").click();
      await expect.poll(() => room.items.length).toBe(0);
      await expect(space.getByTestId("construct-holding")).toBeHidden();
    } finally {
      await closeUsers([host]);
    }
  });

  test("an arcade cabinet shelves its games with their covers (SP34)", async ({
    browser,
  }) => {
    const host = await newSignedInUser(browser, "cv");
    try {
      await inChannel([host], "cv");
      const { space, walker } = await openConstruct(host, "mage");
      const self = await walker.here();
      const cabinet = { x: self.x + 3, y: self.y + 2 };

      await chooseInMenu(space, "fun", { kind: "arcade" });
      const at = await tilePoint(space, self, cabinet);
      await space.mouse.click(at.x, at.y);
      await space.keyboard.press("Escape");
      await space.waitForTimeout(250);
      await walker.goTo({ x: cabinet.x - 1, y: cabinet.y });
      await space.keyboard.press("e");
      const panel = space.getByTestId("space-panel");
      await expect(panel).toBeVisible();
      const covers = panel.locator("img.space-panel-cover");
      await expect(covers.first()).toBeVisible();
      expect(await covers.count()).toBeGreaterThan(3);
      await expect(
        panel.locator('[data-space-panel-icon="arcade"]'),
      ).toBeVisible();
      await covers
        .first()
        .evaluate(
          (img: HTMLImageElement) =>
            img.complete ||
            new Promise((done) => img.addEventListener("load", done)),
        );
      await shot(space, "construct-arcade-covers");
      await space.getByTestId("space-panel-close").click();
    } finally {
      await closeUsers([host]);
    }
  });

  test("a handheld pad and a one-line say bar on a desktop (SP35)", async ({
    browser,
  }) => {
    const host = await newSignedInUser(browser, "hh");
    try {
      await inChannel([host], "hh");
      const space = await host.chat.openSpace();
      await walkIn(space, "ranger");
      await mapDrawn(space);
      await handheldAndOneLine(space);
      await fitsTheScreen(space);
      await shot(space, "desktop-pad-say-one-line");
    } finally {
      await closeUsers([host]);
    }
  });

  test("the one-line say bar fits a small phone in Russian (SP35)", async ({
    browser,
  }) => {
    const host = await userWith(browser, "sm", {
      locale: "ru",
      viewport: SMALL_PHONE,
    });
    try {
      await inChannel([host], "sm");
      const space = await host.chat.openSpace();
      await walkIn(space, "ranger");
      await handheldAndOneLine(space);
      const field = (await space.getByTestId("space-say-input").boundingBox())!;
      expect(field.width).toBeGreaterThanOrEqual(90);
      // The count is the tower and a number here; its sentence stays for a
      // screen reader.
      await expect(
        space.getByTestId("space-status-count").locator(".space-icon--space"),
      ).toBeVisible();
      await fitsTheScreen(space);
      await shot(space, "small-phone-ru-one-line");
    } finally {
      await closeUsers([host]);
    }
  });
});
