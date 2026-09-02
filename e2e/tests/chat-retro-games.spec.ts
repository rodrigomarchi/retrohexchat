/**
 * @section M - Admin, Server Operations, Bots
 * @flow M36 [done] Games menu -> Retro Games opens the catalogue in a tab of its own and a game icon starts a solo session (features P2)
 * @flow M37 [done] Desktop game shortcuts reach Retro Games and the Arcade (features P2)
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";
import { shot } from "../helpers/screenshots";

test.describe("Retro Games from the chat", () => {
  test("Games -> Retro Games opens the catalogue in a tab and launches Pixel Tanks", async ({
    page,
  }) => {
    const connect = new ConnectPage(page);
    const chat = new ChatPage(page);

    await connect.open();
    await connect.enterNickname(uniqueNickname("retro"));
    await connect.registerWithPassword("pass12345");
    await chat.waitUntilConnected();

    // The chat has no window for the games any more, so nothing about them is
    // on this page before the entry is followed and nothing after it either.
    await expect(page.getByTestId("retro-games-window")).toHaveCount(0);

    const games = await chat.openRetroGames();
    await expect(page.getByTestId("retro-games-window")).toHaveCount(0);

    await expect(games.getByTestId("retro-games-icon-grid")).toBeVisible();
    await expect(games.getByTestId("retro-games-catalog")).toHaveCount(0);
    await shot(
      games.getByTestId("retro-games-window"),
      "retro-games-icon-launcher",
    );

    const pixelTanksIcon = games.getByTestId("retro-game-pixel_tanks");
    await expect(pixelTanksIcon).toBeVisible();
    await pixelTanksIcon.click();

    await expect(
      games.getByTestId("retro-game-session-pixel_tanks"),
    ).toBeVisible();
    await expect(
      games.getByTestId("retro-game-canvas-pixel_tanks"),
    ).toBeVisible();
    await shot(games.getByTestId("retro-games-window"), "pixel-tanks-ready");

    await games.getByTestId("retro-game-back").click();
    await expect(games.getByTestId("retro-games-library")).toBeVisible();
    await expect(games.getByTestId("retro-games-icon-grid")).toBeVisible();
  });

  test("desktop game shortcuts reach Retro Games and the Arcade", async ({
    page,
  }) => {
    const connect = new ConnectPage(page);
    const chat = new ChatPage(page);

    await connect.open();
    await connect.enterNickname(uniqueNickname("deskgame"));
    await connect.registerWithPassword("pass12345");
    await chat.waitUntilConnected();

    // The catalogue leaves the desktop; the arcade is still a window on it.
    await chat.openRetroGames();
    await chat.openArcadeFromDesktopShortcut();
  });
});
