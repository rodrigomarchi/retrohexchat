/**
 * @section N - P2P, File, Call, Game
 * @flow N116 [done] Hex Hockey's home lists its three formats — Hex Hockey (three periods), Blitz and Showdown; Play on each opens the game in a tab of its own, its menu naming the match, and against the computer at Hard each is a match under way
 * @flow N117 [done] Climbing the ranking: a player with no rating yet plays Blitz with Find a partner on the home's Blitz row, a friend taking the seat in #hex-hockey; after the match both are in the Rating list of the home's Ranking tab, one above the 1200 everybody starts at and one below; a second Blitz match against another friend moves the player's rating again, and the You tab gives the player's rating and place
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { expect, Page, test } from "@playwright/test";
import { closeUsers, newSignedInUser, TestUser } from "../helpers/chatUsers";
import {
  autopilot,
  openHome,
  playFromHome,
  provisionGameChannel,
  seatMatch,
} from "../helpers/retroGames";
import { shot } from "../helpers/screenshots";

const SLUG = "hex-hockey";
const WAYS = ["hex_hockey", "hex_hockey_blitz", "hex_hockey_showdown"];
const BLITZ = {
  slug: SLUG,
  way: "hex_hockey_blitz",
  name: "Hex Hockey: Blitz",
};
// Two hard skaters in Blitz: one three-minute period, the pauses between
// goals, sudden death when it is tied — under six minutes.
const MATCH_TIMEOUT = 7 * 60_000;

/** `who`'s line in the home's Rating list, and the rating on it. */
async function ratingOf(page: Page, who: TestUser): Promise<number | null> {
  await page.getByTestId("game-home-tab-ranking").click();
  const row = page
    .getByTestId("game-community-ratings")
    .locator("li")
    .filter({ hasText: who.nick });
  if ((await row.count()) === 0) return null;
  const text = (await row.first().textContent()) ?? "";
  return Number(text.trim().split(/\s+/).pop());
}

test.describe("Hex Hockey", () => {
  test("the home lists three formats, each a match against the computer (N116)", async ({
    browser,
  }) => {
    test.setTimeout(4 * 60_000);
    const ana = await newSignedInUser(browser, "hockeysolo");
    try {
      await autopilot(ana.ctx);
      await openHome(ana, SLUG);
      for (const id of WAYS) {
        await expect(ana.page.getByTestId(`game-way-${id}`)).toBeVisible();
      }
      await expect(ana.page.locator('[data-testid^="game-way-"]')).toHaveCount(
        WAYS.length,
      );
      await shot(ana.page, "hockey-home");
      for (const id of WAYS) {
        const game = await playFromHome(ana, id);
        await expect(
          game.getByTestId("game-stage-menu").getByTestId("retro-game-goal"),
        ).toBeVisible();
        await game.getByTestId("retro-game-difficulty-hard").click();
        await game.getByTestId("retro-game-start-ai").click();
        await expect(game.getByTestId("game-stage-menu")).toBeHidden();
        await game.waitForTimeout(12_000);
        await shot(game, `${id}-match`);
        await game.close();
        await ana.page.bringToFront();
      }
    } finally {
      await closeUsers([ana]);
    }
  });

  test("climbing the ranking: two Blitz matches move a player's rating (N117)", async ({
    browser,
  }) => {
    test.setTimeout(2 * MATCH_TIMEOUT + 4 * 60_000);
    const [pix, kes, nov] = await Promise.all(
      ["hkpix", "hkkes", "hknov"].map((name) => newSignedInUser(browser, name)),
    );
    const founder = await newSignedInUser(browser, "hkfound");
    try {
      for (const player of [pix, kes, nov]) await autopilot(player.ctx);
      await provisionGameChannel(
        founder.page.request,
        "hex_hockey",
        founder.nick,
        {
          p1: 3,
          p2: 1,
        },
      );
      for (const friend of [kes, nov]) {
        await friend.page.goto(`/c/${SLUG}`);
        await friend.chat.waitUntilConnected();
        await expect(friend.page.getByTestId("game-channel-bar")).toBeVisible();
      }

      // No rating before the first match between people.
      await openHome(pix, SLUG);
      expect(await ratingOf(pix.page, pix)).toBeNull();
      await pix.page.getByTestId("game-home-tab-you").click();
      await expect(pix.page.getByTestId("game-you-rating")).toBeHidden();

      // Match one: both in the list, on either side of where everybody starts.
      const one = await seatMatch(
        pix,
        kes,
        BLITZ,
        "hockey-match-one",
        MATCH_TIMEOUT,
      );
      await openHome(pix, SLUG);
      const afterOne = await ratingOf(pix.page, pix);
      const kestrel = await ratingOf(pix.page, kes);
      expect(afterOne).not.toBeNull();
      expect(kestrel).not.toBeNull();
      const [up, down] =
        one.winner === pix ? [afterOne!, kestrel!] : [kestrel!, afterOne!];
      expect(up).toBeGreaterThan(1200);
      expect(down).toBeLessThan(1200);
      await shot(pix.page, "hockey-ranking-after-one");

      // Match two, another friend: the rating moves again.
      await seatMatch(pix, nov, BLITZ, "hockey-match-two", MATCH_TIMEOUT);
      await openHome(pix, SLUG);
      const afterTwo = await ratingOf(pix.page, pix);
      expect(afterTwo).not.toBe(afterOne);
      await shot(pix.page, "hockey-ranking-after-two");
      await pix.page.getByTestId("game-home-tab-you").click();
      await expect(pix.page.getByTestId("game-you-rating")).toContainText(
        String(afterTwo),
      );
      await expect(pix.page.getByTestId("game-you-rating")).toContainText(
        "Place",
      );
      await shot(pix.page, "hockey-you-rating");
    } finally {
      await closeUsers([pix, kes, nov, founder]);
    }
  });
});
