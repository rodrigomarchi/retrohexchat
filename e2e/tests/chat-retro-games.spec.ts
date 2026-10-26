/**
 * @section M - Admin, Server Operations, Bots
 * @flow M36 [done] The Games folder is the catalogue: a game icon opens the game's home over the chat, and its Play opens the game in a tab of its own (features P2)
 * @flow M37 [done] Start -> Games -> Retro Games opens the folder, and the Arcade is still a window (features P2)
 * @flow M41 [done] End pressed mid-match writes the match down as it stood: the score and "Ended early", with nobody named the winner (features P2)
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";
import { shot } from "../helpers/screenshots";
import { waitForView } from "../helpers/liveView";

test.describe("Retro Games from the chat", () => {
  test("the Games folder opens Pixel Tanks' home, and its Play opens the game in a tab", async ({
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

    // One game per tab: no library to go back to, the home is in the chat's tab.
    await expect(games.getByTestId("retro-game-back")).toHaveCount(0);
    await expect(page.getByTestId("game-home")).toBeVisible();
    await shot(page, "pixel-tanks-home");
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

  test("End mid-match writes the match down as it stood", async ({ page }) => {
    const connect = new ConnectPage(page);
    const chat = new ChatPage(page);

    await connect.open();
    await connect.enterNickname(uniqueNickname("quit"));
    await connect.registerWithPassword("pass12345");
    await chat.waitUntilConnected();

    await chat.openGamesFolder();
    const games = await chat.openGameFromFolder("hex_pong");
    await waitForView(games);

    // On a wide window the button and the whole game are on screen, not
    // clipped below it: a click by test id would reach them either way.
    await games.setViewportSize({ width: 1500, height: 900 });
    await expect(games.getByTestId("retro-game-start-ai")).toBeInViewport({
      ratio: 1,
    });
    await expect(
      games.getByTestId("retro-game-canvas-hex_pong"),
    ).toBeInViewport({ ratio: 1 });
    await shot(games, "wide-window-ready");
    await games.getByTestId("retro-game-start-ai").click();
    await expect(games.getByTestId("retro-game-end-match")).toBeInViewport({
      ratio: 1,
    });
    // Long enough to be a match the server keeps: anything under 3 s is not.
    await games.waitForTimeout(4000);
    await games.getByTestId("retro-game-end-match").click();

    const result = games.getByTestId("retro-game-result");
    await expect(result).toBeVisible();
    await expect(result.getByTestId("retro-game-ended-early")).toBeVisible();
    await expect(result.getByTestId("retro-game-verdict")).toHaveCount(0);
    await shot(result, "hex-pong-ended-early");

    // Again starts another match from a fresh engine.
    await games.getByTestId("retro-game-play-again").click();
    await expect(games.getByTestId("retro-game-start-ai")).toBeVisible();
  });
});
