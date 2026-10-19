/**
 * @section N - P2P, File, Call, Game
 * @flow N64 [done] A game's channel names its game under the topic, and Find a partner puts one seat's card in the channel; pressing it again points at the same card
 * @flow N65 [done] A match between two people is written down once: GameServ says it in the game's channel with a card, and the same card lands in the two players' private conversation
 * @flow N66 [done] A visitor reads a game's channel and its public page — ranking, latest matches, the channel's last lines — and pressing Find a partner opens the sign-in window
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { APIRequestContext, expect, test } from "@playwright/test";
import { closeUsers, newSignedInUser, TestUser } from "../helpers/chatUsers";
import { shot } from "../helpers/screenshots";
import { bringForward } from "../helpers/siteWindows";

const GAME_CHANNEL = "#hex-pong";

// A match recorded through the server's own ledger, as if it had been played:
// the canvas is not what these flows are about, the card it leaves behind is.
async function recordMatch(
  request: APIRequestContext,
  match: { p1: string; p2?: string; payload: object; difficulty?: string },
) {
  const response = await request.post("/api/e2e/game-results", {
    data: { game_id: "hex_pong", duration_seconds: 140, ...match },
  });
  expect(response.ok(), await response.text()).toBeTruthy();
}

// A game's channel at its own address: the address wins over whatever channel
// the last session ended in, and keeps winning once the restore has run.
async function openGameChannel(user: TestUser) {
  await user.page.goto("/c/hex-pong");
  await user.chat.waitUntilConnected();
  await expect(user.page.getByTestId("game-channel-bar")).toBeVisible();
  await user.page.waitForTimeout(1500);
  await expect(user.page.getByTestId("game-channel-bar")).toBeVisible();
}

test.describe("Game channels", () => {
  test("the strip under the topic offers a seat, once (N64)", async ({
    browser,
  }) => {
    const ana = await newSignedInUser(browser, "gch");

    try {
      // Made by the server, as the boot job makes every game's channel.
      await recordMatch(ana.page.request, {
        p1: ana.nick,
        payload: { score: { p1: 2, p2: 11 }, winner: 2 },
        difficulty: "easy",
      });

      await openGameChannel(ana);
      await shot(ana.page, "game-channel-open");
      const bar = ana.page.getByTestId("game-channel-bar");
      await expect(bar).toContainText("Hex Pong");
      await shot(bar, "game-channel-bar");

      await ana.page.getByTestId("game-channel-lfg").click();
      const seat = ana.chat.messageRowByText(
        `${ana.nick} is looking for a partner in Hex Pong`,
      );
      await expect(seat).toBeVisible();
      await expect(seat.getByTestId("share-message-card")).toBeVisible();
      await shot(seat, "game-channel-seat-card");

      // The card is still the newest line: a second press brings nothing new.
      await ana.page.getByTestId("game-channel-lfg").click();
      await expect(
        ana.page.getByText(`${ana.nick} is looking for a partner in Hex Pong`),
      ).toHaveCount(1);
      await shot(ana.page, "game-channel-seat-pointed-at");
    } finally {
      await closeUsers([ana]);
    }
  });

  test("a match between two people is said in the channel and the conversation (N65)", async ({
    browser,
  }) => {
    const ana = await newSignedInUser(browser, "gca");
    const beto = await newSignedInUser(browser, "gcb");

    try {
      await recordMatch(ana.page.request, {
        p1: ana.nick,
        p2: beto.nick,
        payload: { score: { p1: 11, p2: 7 }, winner: 1 },
      });

      await openGameChannel(ana);
      const card = ana.page
        .locator('[data-testid^="game-result-card-"]')
        .last();
      await expect(card).toBeVisible();
      await expect(card).toContainText(`${ana.nick} 11 × 7 ${beto.nick}`);
      await expect(card).toContainText(`Winner: ${ana.nick}`);
      // In the game's own channel there is no way into it.
      await expect(card.getByTestId("game-result-channel")).toHaveCount(0);
      await shot(card, "game-channel-result-card");

      // The two players' conversation has the same match, with the way into
      // the game's channel.
      await beto.chat.sendMessage(`/query ${ana.nick}`);
      const pmCard = beto.page
        .locator('[data-testid^="game-result-card-"]')
        .last();
      await expect(pmCard).toBeVisible();
      await expect(pmCard.getByTestId("game-result-channel")).toHaveText(
        GAME_CHANNEL,
      );
      await shot(pmCard, "private-conversation-result-card");

      await pmCard.getByTestId("game-result-channel").click();
      await expect(beto.page).toHaveURL(/\/c\/hex-pong/);
      await expect(beto.page.getByTestId("game-channel-bar")).toBeVisible();
    } finally {
      await closeUsers([ana, beto]);
    }
  });

  test("a visitor reads the game's channel and page, and is asked to sign in to play (N66)", async ({
    browser,
  }) => {
    const ana = await newSignedInUser(browser, "gcv");
    const beto = await newSignedInUser(browser, "gcw");
    const visitorContext = await browser.newContext();
    const visitor = await visitorContext.newPage();

    try {
      await recordMatch(ana.page.request, {
        p1: ana.nick,
        p2: beto.nick,
        payload: { score: { p1: 9, p2: 11 }, winner: 2 },
      });

      // The page a search lands on: the ranking and the latest matches are
      // in it before any socket connects.
      await visitor.goto("/games/hex-pong");
      // The ranking is the week's top five, which earlier runs share; the
      // latest match is this one, newest first.
      await expect(visitor.getByTestId("game-community-week")).toBeVisible();
      await expect(
        visitor.getByTestId("game-community-recent").locator("li").first(),
      ).toContainText(`${ana.nick} 9 × 11 ${beto.nick}`);
      await shot(visitor, "game-page-community");

      // The channel is readable without an account; acting on it is not.
      await bringForward(visitor, "site-community");
      await shot(visitor, "game-page-community-in-front");
      await visitor.getByTestId("game-community-channel").click();
      await expect(visitor).toHaveURL(/\/c\/hex-pong/);
      await expect(visitor.getByTestId("game-channel-bar")).toBeVisible();
      await expect(
        visitor.locator('[data-testid^="game-result-card-"]').last(),
      ).toBeVisible();
      await shot(visitor, "visitor-game-channel");

      await visitor.getByTestId("game-channel-lfg").click();
      await expect(
        visitor.getByTestId("document-window-connect"),
      ).toBeVisible();
      await expect(visitor).toHaveURL(/\/connect\?.*signup=games/);
      await shot(visitor, "visitor-asked-to-sign-in-to-play");
    } finally {
      await closeUsers([ana, beto]);
      await visitorContext.close();
    }
  });
});
