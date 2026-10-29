/**
 * @section M - Admin, Server Operations, Bots
 * @flow M36 [done] The Games folder holds a folder per category, each a window of game cards: a card opens the game's home over the chat, and its Play opens the game in a tab of its own (features P2)
 * @flow M37 [done] Start -> Games -> Retro Games opens the folder, a category's group lists its games, a game opens its home, and the Arcade is a folder of its own (features P2)
 * @flow M42 [done] On a phone, Start drills one level per tap down Games -> Arcade -> First-Person Shooters, its header leads back up, and a category's window shows its cards two to a row
 * @flow M41 [done] End pressed mid-match (from the menu over it) writes the match down as it stood: the score and "Ended early", with nobody named the winner (features P2)
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { devices, test, expect } from "@playwright/test";
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

    // Two catalogues, two folders, side by side on the desktop.
    await expect(chat.gamesFolderIcon).toBeVisible();
    await expect(chat.arcadeIcon).toBeVisible();
    await shot(page.locator(".desktop__shortcuts"), "desktop-game-icons");

    // The folder holds a folder per category; a category holds the cards.
    await chat.openGamesFolder();
    await expect(chat.gamesFolderGrid).toBeVisible();
    for (const category of [
      "sports",
      "shooters",
      "action",
      "cards",
      "puzzles",
    ]) {
      await expect(
        chat.gamesFolderGrid.getByTestId(
          `desktop-launcher-item-folder-games-${category}`,
        ),
      ).toBeVisible();
    }
    await expect(chat.gameFolderIcon("pixel_tanks")).toHaveCount(0);
    await shot(chat.gamesFolderWindow, "games-folder-categories");

    await chat.openCategoryOf(
      chat.gamesFolderWindow,
      "desktop-launcher-item-game-pixel_tanks",
    );
    const shooters = page.getByTestId("desktop-launcher-window-games-shooters");
    await expect(chat.gameFolderIcon("pixel_tanks")).toBeInViewport();
    await expect(chat.gameFolderIcon("hex_invaders")).toBeVisible();
    await shot(shooters, "shooters-cards");

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

  test("Start reaches the same folders, down to a game, and the Arcade is a folder", async ({
    page,
  }) => {
    const connect = new ConnectPage(page);
    const chat = new ChatPage(page);

    await connect.open();
    await connect.enterNickname(uniqueNickname("deskgame"));
    await connect.registerWithPassword("pass12345");
    await chat.waitUntilConnected();

    // Start walks the same tree: its first row opens the folder itself.
    await chat.openGamesFolderFromStart();
    await expect(
      chat.gamesFolderGrid.getByTestId(
        "desktop-launcher-item-folder-games-sports",
      ),
    ).toBeVisible();

    // A group inside a group inside a group, each flying out beside the last.
    const sports = page.getByTestId("start-menu-folder-games-sports");
    const hexPong = page.getByTestId("start-menu-item-game-hex_pong");
    await chat.openStartPath(
      [chat.startGamesSubmenuTrigger, chat.startRetroGamesTrigger, sports],
      hexPong,
    );
    await expect(hexPong).toBeInViewport();
    await expect(
      page.getByTestId("start-menu-item-open-games-sports"),
    ).toBeInViewport();
    await shot(page, "start-games-retro-sports");

    await hexPong.click();
    await expect(page.getByTestId("game-home")).toBeVisible();

    await chat.openArcadeFolder();
    await expect(
      chat.arcadeFolderGrid.getByTestId(
        "desktop-launcher-item-folder-arcade-fps",
      ),
    ).toBeVisible();
    await shot(chat.arcadeFolderWindow, "arcade-folder-categories");

    // A narrow desktop, still too wide to stack: the third flyout has no room
    // on the right and opens to the left of its row instead.
    await page.setViewportSize({ width: 820, height: 720 });
    const doom = page.getByTestId("start-menu-item-game-doom_shareware");
    await chat.openStartPath(
      [
        chat.startGamesSubmenuTrigger,
        page.getByTestId("start-menu-folder-arcade"),
        page.getByTestId("start-menu-folder-arcade-fps"),
      ],
      doom,
    );
    await expect(doom).toBeInViewport({ ratio: 1 });
    await shot(page, "narrow-start-arcade-fps");
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
    await expect(games.getByTestId("game-stage-menu-key")).toBeInViewport({
      ratio: 1,
    });
    // Long enough to be a match the server keeps: anything under 3 s is not.
    await games.waitForTimeout(4000);
    // End is in the menu, over the match it holds.
    await games.getByTestId("game-stage-menu-key").click();
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

  test.describe("on a phone", () => {
    // The phone's screen and touch, without the browser it names: that is a
    // choice of worker, which a describe block cannot make.
    const { defaultBrowserType: _browser, ...phone } = devices["Pixel 5"];
    test.use(phone);

    test("Start drills down the game folders one level at a time", async ({
      page,
    }) => {
      const connect = new ConnectPage(page);
      const chat = new ChatPage(page);

      await connect.open();
      await connect.enterNickname(uniqueNickname("phgame"));
      await connect.registerWithPassword("pass12345");
      await chat.waitUntilConnected();

      const arcade = page.getByTestId("start-menu-folder-arcade");
      const fps = page.getByTestId("start-menu-folder-arcade-fps");
      const doom = page.getByTestId("start-menu-item-game-doom_shareware");
      await chat.openStartPath(
        [chat.startGamesSubmenuTrigger, arcade, fps],
        doom,
      );

      // Only the deepest level shows: its header, its Open row, its games.
      await expect(doom).toBeInViewport();
      await expect(fps).toBeInViewport();
      await expect(arcade).toBeHidden();
      await expect(chat.startGamesSubmenuTrigger).toBeHidden();
      await expect(
        page.getByTestId("start-menu-folder-arcade-adventure"),
      ).toBeHidden();
      await shot(page, "phone-start-arcade-fps");

      // The header goes back up one level, to the Arcade's categories.
      await fps.click();
      await expect(arcade).toBeInViewport();
      await expect(
        page.getByTestId("start-menu-folder-arcade-adventure"),
      ).toBeInViewport();
      await expect(doom).toBeHidden();
      await shot(page, "phone-start-arcade");

      // The category's Open row brings its window, full screen.
      await fps.click();
      await page.getByTestId("start-menu-item-open-arcade-fps").click();
      const window = page.getByTestId("desktop-launcher-window-arcade-fps");
      await expect(window).toBeVisible();
      const first = window.getByTestId("arcade-game-doom_shareware");
      const second = window.getByTestId("arcade-game-freedoom1");
      const [a, b] = [await first.boundingBox(), await second.boundingBox()];
      expect(a && b && Math.abs(a.y - b.y) < 2 && b.x > a.x).toBe(true);
      await shot(page, "phone-arcade-fps-cards");
    });
  });
});
