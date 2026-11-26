/**
 * @section N - P2P, File, Call, Game
 * @flow N115 [done] A Sudden Death tournament in #hex-tennis: two semifinals, each made with Find a partner on the home's Sudden Death row — a seat's card in the channel, a friend already there takes it with Join, both ready, the host starts — are played to the end one after the other and Scoreboard says each result in the channel; the two winners meet in a final made the same way, played to the end, its result on both screens and its card in the finalists' private conversation
 * @flow N114 [done] Hex Tennis's home lists its three formats — Hex Tennis (a full set), Quick Match and Sudden Death; Play on each opens the game in a tab of its own, and against the computer at Hard each is a match under way; Quick Match is played to the result
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
  playToTheResult,
  provisionGameChannel,
  seatMatch,
} from "../helpers/retroGames";
import { shot } from "../helpers/screenshots";

const SLUG = "hex-tennis";
const SUDDEN = {
  slug: SLUG,
  way: "hex_tennis_sudden",
  name: "Hex Tennis: Sudden Death",
};
const WAYS = ["hex_tennis", "hex_tennis_quick", "hex_tennis_sudden"];
// Two hard players: Quick Match takes one to three minutes.
const MATCH_TIMEOUT = 6 * 60_000;

test.describe("Hex Tennis", () => {
  test("the home lists three formats, each a match against the computer; Quick Match played to the result (N114)", async ({
    browser,
  }) => {
    test.setTimeout(MATCH_TIMEOUT + 4 * 60_000);
    const ana = await newSignedInUser(browser, "tennissolo");
    try {
      await autopilot(ana.ctx);
      await openHome(ana, SLUG);
      for (const id of WAYS) {
        await expect(ana.page.getByTestId(`game-way-${id}`)).toBeVisible();
      }
      await expect(ana.page.locator('[data-testid^="game-way-"]')).toHaveCount(
        WAYS.length,
      );
      await shot(ana.page, "tennis-home");

      for (const id of [WAYS[0], WAYS[2]]) {
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

      const game = await playFromHome(ana, WAYS[1]);
      await expect(
        game.getByTestId("game-stage-menu").getByTestId("retro-game-goal"),
      ).toBeVisible();
      await shot(game, "tennis-quick-ready");
      await game.getByTestId("retro-game-difficulty-hard").click();
      await playToTheResult(game, "tennis-quick", MATCH_TIMEOUT);
    } finally {
      await closeUsers([ana]);
    }
  });

  test("a Sudden Death tournament: two semifinals in the channel, then the final between their winners (N115)", async ({
    browser,
  }) => {
    test.setTimeout(3 * MATCH_TIMEOUT + 4 * 60_000);
    const players = await Promise.all(
      ["tna", "tnb", "tnc", "tnd"].map((name) =>
        newSignedInUser(browser, name),
      ),
    );
    const founder = await newSignedInUser(browser, "tnfound");
    try {
      for (const player of players) await autopilot(player.ctx);
      await provisionGameChannel(
        founder.page.request,
        "hex_tennis",
        founder.nick,
        {
          p1: 6,
          p2: 4,
        },
      );
      for (const player of players) await inTheChannel(player);

      const [a, b, c, d] = players;
      const one = await seatMatch(a, b, SUDDEN, "tennis-semi-one");
      await expect(resultCard(a.page, a, b)).toBeVisible({ timeout: 30_000 });
      const two = await seatMatch(c, d, SUDDEN, "tennis-semi-two");
      // Both semifinals said in the channel, one card each.
      await expect(resultCard(a.page, c, d)).toBeVisible({ timeout: 30_000 });
      await expect(resultCard(a.page, a, b)).toBeVisible();
      // Both over: nothing left to watch under the topic.
      await expect(
        a.page.getByTestId("game-channel-bar").getByTestId("live-match-link"),
      ).toHaveCount(0, { timeout: 15_000 });
      await shot(a.page, "tennis-semifinals-in-channel");

      for (const finalist of [one.winner, two.winner])
        await inTheChannel(finalist);
      const final = await seatMatch(
        one.winner,
        two.winner,
        SUDDEN,
        "tennis-final",
      );
      // The final's card lands in the finalists' own conversation.
      await final.winner.chat.sendMessage(`/query ${final.loser.nick}`);
      const card = final.winner.page
        .locator('[data-testid^="game-result-card-"]')
        .filter({ hasText: final.loser.nick });
      await expect(card).toBeVisible({ timeout: 30_000 });
      await shot(final.winner.page, "tennis-final-in-private");
    } finally {
      await closeUsers([...players, founder]);
    }
  });
});

/** Scoreboard's card of the match between `one` and `two`, on `page`. */
const resultCard = (page: Page, one: TestUser, two: TestUser) =>
  page
    .locator('[data-testid^="game-result-card-"]')
    .filter({ hasText: one.nick })
    .filter({ hasText: two.nick });

/** `who` in #hex-tennis, at its address. */
async function inTheChannel(who: TestUser) {
  await who.page.bringToFront();
  await who.page.goto(`/c/${SLUG}`);
  await who.chat.waitUntilConnected();
  await expect(who.page.getByTestId("game-channel-bar")).toBeVisible();
}
