/**
 * @section M - Admin, Server Operations, Bots
 * @flow M20 [done] The Arcade desktop icon opens an icon launcher, game details, then launches a WASM session through a noopener anchor at its own address
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { Browser, BrowserContext, Page, test, expect } from "@playwright/test";
import { ConnectPage } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";
import { adminNick, adminPassword } from "../helpers/env";
import { shot } from "../helpers/screenshots";

const ADMIN_NICK = adminNick();
const ADMIN_PW = adminPassword();

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  page: Page;
};

async function knownSignedInUser(
  browser: Browser,
  nick: string,
  password: string,
  locale?: string,
): Promise<TestUser> {
  const ctx = await browser.newContext(
    locale ? { locale: locale.replace("_", "-") } : {},
  );
  const page: Page = await ctx.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);

  await connect.open(locale);
  await connect.signIn(nick, password);
  await chat.waitUntilConnected();

  return { chat, ctx, page };
}

test.describe("In-chat Arcade", () => {
  test("Games -> Arcade opens the icon launcher, previews, and launches DOOM", async ({
    browser,
  }) => {
    const user = await knownSignedInUser(
      browser,
      ADMIN_NICK,
      ADMIN_PW,
      "pt_BR",
    );

    try {
      // One double-click from the desktop, with no folder in between.
      await expect(user.chat.arcadeIcon).toBeVisible();
      await expect(
        user.page.getByTestId("menu-game-doom_shareware"),
      ).toHaveCount(0);
      await user.chat.arcadeIcon.dblclick();

      await expect(user.chat.arcadeWindow).toBeVisible();
      await expect(user.chat.arcadeLibrary).toBeVisible();
      await expect(user.chat.arcadeIconGrid).toBeVisible();
      await expect(
        user.page.getByTestId("solo-game-doom_shareware"),
      ).toHaveCount(0);
      await shot(user.chat.arcadeWindow, "arcade-icon-launcher");

      const doomIcon = user.page.getByTestId("arcade-game-doom_shareware");
      await expect(doomIcon).toBeVisible();

      await doomIcon.click();
      await expect(user.page.getByTestId("arcade-game-preview")).toBeVisible();
      await expect(
        user.page.getByTestId("solo-game-start-doom_shareware"),
      ).toBeVisible();
      await shot(user.chat.arcadeWindow, "doom-game-preview");

      // The game opens through an anchor with `rel="noopener"`, which is what
      // buys it an event loop of its own — measured at 1203 ms against 12 ms.
      // The address is ours and shareable; where the bundle lives is a
      // redirect away.
      const start = user.page.getByTestId("solo-game-start-doom_shareware");
      await expect(start).toHaveAttribute(
        "href",
        "/play/arcade/doom_shareware",
      );
      await expect(start).toHaveAttribute("target", "_blank");
      await expect(start).toHaveAttribute("rel", "noopener");

      // The first click only asks. The domain call that starts the game is held
      // with the tab rather than fired beside it, so at this point nothing has
      // begun — a reader who cancels here has not started a game.
      await start.click();
      const confirm = user.page.getByTestId("open-tab-confirm-open");
      await expect(confirm).toBeVisible();
      await expect(
        user.page.getByTestId("arcade-playing-state"),
      ).not.toBeVisible();

      const popupPromise = user.page.waitForEvent("popup");
      await confirm.click();
      const gameWindow = await popupPromise;
      await gameWindow.waitForLoadState("domcontentloaded");

      // Confirming did both: the tab opened and the server was told.
      await expect(user.page.getByTestId("arcade-playing-state")).toBeVisible();
      expect(await gameWindow.evaluate(() => window.opener === null)).toBe(
        true,
      );
      await expect(user.page.getByTestId("arcade-reopen")).toBeVisible();
      await shot(user.chat.arcadeWindow, "doom-session-started");

      await user.page.getByTestId("arcade-back").click();
      await expect(user.chat.arcadeLibrary).toBeVisible();
      await expect(user.chat.arcadeIconGrid).toBeVisible();
      await user.page.mouse.move(16, 16);
      await shot(user.chat.arcadeWindow, "arcade-returned-to-launcher");
    } finally {
      await user.ctx.close();
    }
  });
});
