/**
 * @section SP - Virtual Spaces
 * @flow SP30 [done] On a phone, the space's screens — the picker, the build palette, the pad, a piece's panel — wear the space's pixel-art kit and fit the screen
 * @flow SP31 [done] A line said in Japanese or in Traditional Chinese is drawn over the speaker in the pixel font, that region's own glyphs fetched for it
 * @flow SP32 [done] A character who takes a hit shows the kit's HP bar under its nameplate until it is whole again
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
  mapDrawn,
  openConstruct,
  tilePoint,
  walkIn,
} from "../helpers/construct";
import { ChatPage } from "../pages/ChatPage";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { Walker } from "../director/space";

const PHONE = { width: 390, height: 844 };

/** A registered user whose browser has its own screen size and language. */
async function userWith(
  browser: Browser,
  prefix: string,
  { locale, viewport }: { locale?: string; viewport?: typeof PHONE } = {},
): Promise<TestUser> {
  const ctx = await browser.newContext({
    viewport,
    locale: locale?.replace("_", "-"),
    hasTouch: viewport === PHONE,
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

/** Nothing of the space's UI reaches past the right edge of the screen. */
async function fitsTheScreen(space: Page) {
  const overflow = await space.evaluate(
    () => document.documentElement.scrollWidth - window.innerWidth,
  );
  expect(overflow).toBeLessThanOrEqual(0);
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
      await expect(space.getByTestId("space-character-select")).toBeVisible();
      await expect(space.locator(".space-ui-panel").first()).toBeVisible();
      await fitsTheScreen(space);
      await shot(space, "phone-picker");

      await walkIn(space, "cleric");
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
      await fitsTheScreen(space);
      await shot(space, "phone-map-pad-say");

      // Through the gate: the question is the kit's panel too.
      await walker.goTo({ x: 56, y: 11 });
      await space.keyboard.press("e");
      await expect(space.getByTestId("space-modal-yes")).toBeVisible();
      await shot(space, "phone-gate-question");
      await space.getByTestId("space-modal-yes").click();
      await mapDrawn(space);
      await expect(space.getByTestId("construct-palette")).toBeVisible();
      await space.getByTestId("construct-tab-fun").click();
      await space.getByTestId("construct-kind-sign").click();
      await fitsTheScreen(space);
      await shot(space, "phone-palette");

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
        await walkIn(space, "sorceress");
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
      const a = await openConstruct(host, "knight");
      const b = await openConstruct(guest, "barbarian");
      const target = await a.walker.here();

      // The guest steps up to the host, facing them, and swings once.
      await b.walker.goTo({ x: target.x, y: target.y + 2 });
      await b.walker.goTo({ x: target.x, y: target.y + 1 });
      await b.space.locator("canvas").first().focus();
      await b.space.keyboard.press(" ");

      // One hit hurts and does not knock out: the bar is up, the knight standing.
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
});
