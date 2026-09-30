/**
 * @section M - Admin, Server Operations, Bots
 * @flow M36 [done] The Games folder is the catalogue and a game icon opens that game in a tab of its own (features P2)
 * @flow M37 [done] Start -> Games -> Retro Games opens the folder, and the Arcade is still a window (features P2)
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";
import { shot } from "../helpers/screenshots";

test.describe("Retro Games from the chat", () => {
  test("the Games folder lists the games and an icon opens Pixel Tanks in a tab", async ({
    page,
  }) => {
    const connect = new ConnectPage(page);
    const chat = new ChatPage(page);

    await connect.open();
    await connect.enterNickname(uniqueNickname("retro"));
    await connect.registerWithPassword("pass12345");
    await chat.waitUntilConnected();

    // The chat has no window for the games any more, so nothing about them is
    // on this page before a game is opened and nothing after it either.
    await expect(page.getByTestId("retro-games-window")).toHaveCount(0);

    // The catalogue is the folder: a game per icon, and no shortcut standing
    // between the reader and the list — that shortcut was the bug.
    // Two programs, two icons, no folder inside a folder.
    await expect(chat.gamesFolderIcon).toBeVisible();
    await expect(chat.arcadeIcon).toBeVisible();
    await shot(page.locator(".desktop__shortcuts"), "desktop-game-icons");

    await chat.openGamesFolder();
    await expect(chat.gamesFolderGrid).toBeVisible();
    await expect(chat.gameFolderIcon("pixel_tanks")).toBeVisible();
    await expect(chat.gameFolderIcon("hex_pong")).toBeVisible();
    await expect(
      page.getByTestId("desktop-launcher-item-retro-games"),
    ).toHaveCount(0);
    // Games only: the arcade is its own icon on the desktop.
    await expect(
      page.getByTestId("desktop-launcher-item-open_arcade"),
    ).toHaveCount(0);
    await shot(chat.gamesFolderWindow, "games-folder-catalogue");

    const games = await chat.openGameFromFolder("pixel_tanks");
    await expect(page.getByTestId("retro-games-window")).toHaveCount(0);

    // The tab lands on the game that was chosen, already selected.
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

  test("Start reaches the same folder, and the Arcade is still a window", async ({
    page,
  }) => {
    const connect = new ConnectPage(page);
    const chat = new ChatPage(page);

    await connect.open();
    await connect.enterNickname(uniqueNickname("deskgame"));
    await connect.registerWithPassword("pass12345");
    await chat.waitUntilConnected();

    // Start carries the way to the catalogue, not a second copy of it.
    await chat.openGamesFolderFromStart();
    await expect(chat.gameFolderIcon("pixel_tanks")).toBeVisible();

    await chat.openArcadeFromDesktopShortcut();
  });
});
