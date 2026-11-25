/**
 * @section N - P2P, File, Call, Game
 * @flow N104 [done] In #debris-field, !challenge is answered by Scoreboard with this week's challenge — Debris Field, the most wins against other players — and where it stands; Play on the game's line opens the game in a tab of its own, its stage naming First to 7, and a match against the computer at Hard, played among the rocks, ends with the result
 * @flow N105 [done] Find a partner on #debris-field's line, a friend's Join takes the seat, the duel is played to the end and Scoreboard says the result in the channel; asked again, !recent names both players and !challenge says who leads the week
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { expect, Page, test } from "@playwright/test";
import { closeUsers, newSignedInUser } from "../helpers/chatUsers";
import {
  autopilot,
  matchInTheChannel,
  playToTheResult,
  provisionGameChannel,
} from "../helpers/retroGames";
import { shot } from "../helpers/screenshots";

const GAME = {
  id: "debris_field",
  name: "Debris Field",
  slug: "debris-field",
  way: "debris_field",
  score: { p1: 4, p2: 7 },
};

const CHALLENGE =
  "This week's challenge is Debris Field. Win the most matches against other players.";

/** Scoreboard's newest answer in the room that contains `text`. */
const answer = (page: Page, text: string | RegExp) =>
  page.locator(".chat-message__text").filter({ hasText: text }).last();

test.describe("Debris Field", () => {
  test("in #debris-field, !challenge names the week's challenge, and against the computer at Hard to the end (N104)", async ({
    browser,
  }) => {
    // Two ships at hard among the rocks: under a minute to seven, two at worst.
    test.setTimeout(6 * 60_000);
    const ana = await newSignedInUser(browser, "rocksolo");
    const founder = await newSignedInUser(browser, "rockfound");
    try {
      await autopilot(ana.ctx);
      // The channel as provisioning sets it up: Scoreboard stands in it.
      await provisionGameChannel(
        founder.page.request,
        GAME.id,
        founder.nick,
        GAME.score,
      );
      await ana.page.goto(`/c/${GAME.slug}`);
      await ana.chat.waitUntilConnected();
      await ana.page.waitForTimeout(1500);
      await ana.chat.sendMessage("!challenge");
      await expect(answer(ana.page, CHALLENGE)).toBeVisible();
      await expect(answer(ana.page, CHALLENGE)).toContainText(
        /Nobody leads it yet\.|leads it\./,
      );
      await shot(ana.page, "rocks-challenge");

      const line = ana.page.getByTestId("game-channel-bar");
      await line.getByTestId("game-channel-play").click();
      const [game] = await Promise.all([
        ana.ctx.waitForEvent("page"),
        ana.page.getByTestId("open-tab-confirm-open").click(),
      ]);
      await expect(game).toHaveURL(/\/play\/debris_field$/);
      await expect(
        game.getByTestId("game-stage-menu").getByTestId("retro-game-goal"),
      ).toHaveText("First to 7");
      await game.getByTestId("retro-game-difficulty-hard").click();
      await shot(game, "rocks-ready");
      await playToTheResult(game, "rocks-solo", 4 * 60_000);
      await expect(game.getByTestId("retro-game-verdict")).toHaveText(
        /You won|AI won/,
      );
    } finally {
      await closeUsers([ana, founder]);
    }
  });

  test("a duel found in #debris-field is played to the end, and the room's !recent and !challenge count it (N105)", async ({
    browser,
  }) => {
    test.setTimeout(8 * 60_000);
    const asker = await newSignedInUser(browser, "rockask");
    try {
      const players = await matchInTheChannel(
        browser,
        GAME,
        "rocks",
        4 * 60_000,
        "channel",
      );
      await asker.page.goto(`/c/${GAME.slug}`);
      await asker.chat.waitUntilConnected();
      await asker.page.waitForTimeout(1500);

      await asker.chat.sendMessage("!recent");
      const recent = answer(asker.page, players.host);
      await expect(recent).toBeVisible();
      await expect(recent).toContainText(players.guest);

      await asker.chat.sendMessage("!challenge");
      const standing = answer(asker.page, CHALLENGE);
      await expect(standing).toBeVisible();
      await expect(standing).toContainText("leads it.");
      await shot(asker.page, "rocks-challenge-after");
    } finally {
      await closeUsers([asker]);
    }
  });
});
