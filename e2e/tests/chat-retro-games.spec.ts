/**
 * @section M - Admin, Server Operations, Bots
 * @flow M36 [done] Games menu -> Retro Games opens an icon launcher and game icons open solo sessions (features P2)
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";
import { shot } from "../helpers/screenshots";

test.describe("In-chat Retro Games", () => {
  test("Games -> Retro Games opens the icon launcher and launches Pixel Tanks", async ({
    page,
  }) => {
    const connect = new ConnectPage(page);
    const chat = new ChatPage(page);

    await connect.open();
    await connect.enterNickname(uniqueNickname("retro"));
    await connect.registerWithPassword("pass12345");
    await chat.waitUntilConnected();

    await chat.gamesMenuTrigger.click();
    await expect(chat.retroGamesMenuItem).toBeVisible();
    await expect(page.getByTestId("menu-retro-game-pixel_tanks")).toHaveCount(
      0,
    );
    await chat.retroGamesMenuItem.click();

    await expect(chat.retroGamesWindow).toBeVisible();
    await expect(chat.retroGamesLibrary).toBeVisible();
    await expect(chat.retroGamesIconGrid).toBeVisible();
    await expect(page.getByTestId("retro-games-catalog")).toHaveCount(0);
    await shot(chat.retroGamesWindow, "retro-games-icon-launcher");

    const pixelTanksIcon = page.getByTestId("retro-game-pixel_tanks");
    await expect(pixelTanksIcon).toBeVisible();
    await pixelTanksIcon.click();

    await expect(
      page.getByTestId("retro-game-session-pixel_tanks"),
    ).toBeVisible();
    await expect(
      page.getByTestId("retro-game-canvas-pixel_tanks"),
    ).toBeVisible();
    await shot(chat.retroGamesWindow, "pixel-tanks-ready");

    await page.getByTestId("retro-game-back").click();
    await expect(chat.retroGamesLibrary).toBeVisible();
    await expect(chat.retroGamesIconGrid).toBeVisible();
  });
});
