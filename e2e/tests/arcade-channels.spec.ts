/**
 * @section N - P2P, File, Call, Game
 * @flow N72 [done] An arcade game's channel names its game under the topic and Pixel tells whoever arrives what the game is and its controls; Play opens the in-app Arcade on that game, and starting it is said by Pixel in the game's channel and in #arcade, each line with its card
 * @flow N73 [done] An arcade game's page is its home: Play with the game's sheet, who played it lately, who plays it most, the reader's own plays and the channel's last lines
 * @flow N74 [done] A visitor reads an arcade game's channel and its page; pressing Play opens the sign-in window, which returns to the same game
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { APIRequestContext, devices, expect, test } from "@playwright/test";
import { closeUsers, newSignedInUser, TestUser } from "../helpers/chatUsers";
import { shot } from "../helpers/screenshots";
import { waitForView } from "../helpers/liveView";

const GAME = "doom_shareware";
const GAME_NAME = "DOOM: Knee-Deep in the Dead";

// The game's room and #arcade, set up the way the provisioning script leaves
// them: registered, archived, with Pixel announcing in them.
async function provisionRooms(request: APIRequestContext, founder: string) {
  const response = await request.post("/api/e2e/arcade-rooms", {
    data: { game_id: GAME, founder },
  });
  expect(response.ok(), await response.text()).toBeTruthy();
}

async function openChannel(user: TestUser, slug: string) {
  await user.page.goto(`/c/${slug}`);
  await user.chat.waitUntilConnected();
  await user.page.waitForTimeout(1500);
}

// Press Play in the Arcade, confirm the tab, and close the game's tab: the
// game itself is not what these flows are about, the line it leaves is.
async function startGame(user: TestUser) {
  const start = user.page.getByTestId(`solo-game-start-${GAME}`);
  await expect(start).toBeVisible();
  await start.click();
  const popupPromise = user.page.waitForEvent("popup");
  await user.page.getByTestId("open-tab-confirm-open").click();
  const gameTab = await popupPromise;
  await expect(user.page.getByTestId("arcade-playing-state")).toBeVisible();
  await gameTab.close();
}

test.describe("Arcade channels", () => {
  test("Play from the game's channel, and the start is said with a card (N72)", async ({
    browser,
  }) => {
    const ana = await newSignedInUser(browser, "arc");

    try {
      await provisionRooms(ana.page.request, ana.nick);
      await openChannel(ana, "doom-shareware");

      const bar = ana.page.getByTestId("game-channel-bar");
      await expect(bar).toBeVisible();
      await expect(bar).toContainText(GAME_NAME);
      await expect(ana.page.getByTestId("game-channel-lfg")).toHaveCount(0);
      // Pixel tells whoever arrives what the game is and how to control it.
      await expect(
        ana.chat.messageRowByText(`${GAME_NAME} controls:`).first(),
      ).toBeVisible();
      await shot(ana.page, "arcade-channel-open");
      await shot(bar, "arcade-channel-bar");

      await ana.page.getByTestId("game-channel-play").click();
      await expect(ana.chat.arcadeWindow).toBeVisible();
      await shot(ana.page, "arcade-opened-from-channel");
      await startGame(ana);

      // Back in the room, Pixel has said it, with the card standing in for
      // the sentence. In the game's own room there is no way into it.
      await openChannel(ana, "doom-shareware");
      const card = ana.page
        .locator('[data-testid^="arcade-play-card-"]')
        .last();
      await expect(card).toBeVisible();
      await expect(card).toContainText(`${ana.nick} started the game`);
      await expect(card.getByTestId("arcade-play-channel")).toHaveCount(0);
      await shot(ana.page, "arcade-channel-after-start");
      await shot(card, "arcade-channel-play-card");

      // #arcade hears it too, with the way into the game's room.
      await openChannel(ana, "arcade");
      const feedCard = ana.page
        .locator('[data-testid^="arcade-play-card-"]')
        .last();
      await expect(feedCard).toBeVisible();
      await expect(feedCard.getByTestId("arcade-play-channel")).toHaveText(
        "#doom-shareware",
      );
      await shot(ana.page, "arcade-feed-after-start");
      await shot(feedCard, "arcade-feed-play-card");

      // The card's Play opens the Arcade on the same game.
      await feedCard.getByTestId("arcade-play-play").click();
      await expect(ana.chat.arcadeWindow).toBeVisible();
      await shot(ana.page, "arcade-opened-from-card");
    } finally {
      await closeUsers([ana]);
    }
  });

  test("the game's page lists who played it and the reader's own plays (N73)", async ({
    browser,
  }) => {
    const ana = await newSignedInUser(browser, "arh");

    try {
      await provisionRooms(ana.page.request, ana.nick);
      await ana.page.goto(`/?arcade=${GAME}`);
      await ana.chat.waitUntilConnected();
      await startGame(ana);

      await ana.page.goto("/games/doom-shareware");
      await waitForView(ana.page);
      const home = ana.page.getByTestId("game-home");
      await expect(home).toBeVisible();
      await shot(ana.page, "arcade-home-play");

      await ana.page.getByTestId("game-home-tab-players").click();
      await expect(ana.page.getByTestId("arcade-home-recent")).toContainText(
        ana.nick,
      );
      await shot(home, "arcade-home-who-played");

      await ana.page.getByTestId("game-home-tab-ranking").click();
      await expect(ana.page.getByTestId("arcade-home-week")).toContainText(
        ana.nick,
      );
      await shot(home, "arcade-home-top-players");

      await ana.page.getByTestId("game-home-tab-you").click();
      await expect(ana.page.getByTestId("game-you-plays")).toBeVisible();
      await shot(home, "arcade-home-you");

      await ana.page.getByTestId("game-home-tab-channel").click();
      await expect(
        ana.page.getByTestId("game-community-channel"),
      ).toBeVisible();
      await shot(home, "arcade-home-channel");
    } finally {
      await closeUsers([ana]);
    }
  });

  test("a visitor reads the room and the page, and Play asks for an account (N74)", async ({
    browser,
  }) => {
    const host = await newSignedInUser(browser, "arv");
    await provisionRooms(host.page.request, host.nick);
    await closeUsers([host]);

    for (const [label, options] of [
      ["desktop", {}],
      ["phone", devices["Pixel 5"]],
    ] as const) {
      const ctx = await browser.newContext(options);
      const page = await ctx.newPage();

      try {
        await page.goto("/games/doom-shareware");
        await waitForView(page);
        await expect(page.getByTestId("game-home")).toBeVisible();
        await shot(page, `visitor-arcade-home-${label}`);
        await page.getByTestId("game-home-tab-players").click();
        await shot(page, `visitor-arcade-home-who-played-${label}`);
        await page.getByTestId("game-home-tab-you").click();
        await shot(page, `visitor-arcade-home-you-${label}`);

        // Five tabs are wider than a phone: they wrap onto a second row
        // instead of pushing the panel sideways.
        const strip = page
          .getByTestId("game-home-tab-channel")
          .locator("xpath=..");
        const width = await strip.evaluate((el) => ({
          scroll: el.scrollWidth,
          client: el.clientWidth,
        }));
        expect(width.scroll).toBeLessThanOrEqual(width.client);
        await page.getByTestId("game-home-tab-channel").click();
        await expect(page.getByTestId("game-community-channel")).toBeVisible();
        await shot(page, `visitor-arcade-home-channel-${label}`);

        await page.goto("/c/doom-shareware");
        await waitForView(page);
        const bar = page.getByTestId("game-channel-bar");
        await expect(bar).toBeVisible();
        await shot(page, `visitor-arcade-channel-${label}`);

        await page.getByTestId("game-channel-play").click();
        await expect(page).toHaveURL(
          /\/connect\?(?=.*signup=games)(?=.*return_to=%2F%3Farcade%3Ddoom_shareware)/,
        );
        await shot(page, `visitor-arcade-play-asks-to-sign-in-${label}`);
      } finally {
        await ctx.close();
      }
    }
  });
});
