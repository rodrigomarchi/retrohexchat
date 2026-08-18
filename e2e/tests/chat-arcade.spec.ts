/**
 * @section M - Admin, Server Operations, Bots
 * @flow M20 [done] Games menu -> Arcade opens an icon launcher, game details, then launches WASM sessions (features P2)
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
      await user.chat.gamesMenuTrigger.click();
      await expect(user.chat.arcadeMenuItem).toBeVisible();
      await expect(
        user.page.getByTestId("menu-game-doom_shareware"),
      ).toHaveCount(0);
      await user.chat.arcadeMenuItem.click();

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

      const popupPromise = user.page.waitForEvent("popup");
      await user.page.getByTestId("solo-game-start-doom_shareware").click();
      const gameWindow = await popupPromise;
      await gameWindow.waitForLoadState("domcontentloaded");

      await expect(user.page.getByTestId("arcade-playing-state")).toBeVisible();
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
