import { Browser, BrowserContext, Page, test, expect } from "@playwright/test";
import { ConnectPage } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";

const ADMIN_NICK = "TestAdmin";
const ADMIN_PW = "adminpass1";

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  page: Page;
};

async function knownSignedInUser(
  browser: Browser,
  nick: string,
  password: string,
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page: Page = await ctx.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);

  await connect.open();
  await connect.signIn(nick, password);
  await chat.waitUntilConnected();

  return { chat, ctx, page };
}

test.describe("In-chat Arcade", () => {
  test("Games → Arcade opens the game-picker window and previews a game", async ({
    browser,
  }) => {
    const user = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);

    try {
      await user.chat.openArcadeFromGamesMenu();

      // The game grid is rendered inside the managed window.
      const doomTile = user.page.getByTestId("solo-game-doom_shareware");
      await expect(doomTile).toBeVisible();

      // Previewing a game reveals its Start control (about/controls/tips panel).
      await doomTile.click();
      await expect(
        user.page.getByTestId("solo-game-start-doom_shareware"),
      ).toBeVisible();
    } finally {
      await user.ctx.close();
    }
  });
});
