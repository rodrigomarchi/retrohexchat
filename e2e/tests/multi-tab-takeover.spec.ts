/**
 * @section Auth And Lifecycle
 * @flow K [done] A second browser context with the same nickname leaves the first one connected
 * @flow K12 [done] A fourth screen ends the one unused for longest and leaves the rest connected
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";
import { shot } from "../helpers/screenshots";

test.describe("Several screens, one nickname", () => {
  test("a second context does not end the first (K)", async ({ browser }) => {
    // Two separate browser contexts so they share neither cookies nor session.
    const ctxA = await browser.newContext();
    const ctxB = await browser.newContext();
    const pageA = await ctxA.newPage();
    const pageB = await ctxB.newPage();

    const nick = uniqueNickname();
    const pw = "testpass123";

    try {
      const connectA = new ConnectPage(pageA);
      const chatA = new ChatPage(pageA);
      await connectA.open();
      await shot(pageA, "connect-session-notice");
      await connectA.enterNickname(nick);
      await connectA.registerWithPassword(pw);
      await chatA.waitUntilConnected();

      const connectB = new ConnectPage(pageB);
      const chatB = new ChatPage(pageB);
      await connectB.open();
      await connectB.enterNickname(nick);
      await connectB.authenticateWithPassword(pw);
      await chatB.waitUntilConnected();

      // The whole point of the change: A is still here. It used to be sent to
      // /connect the instant B finished authenticating.
      await expect(pageA).toHaveURL(/\/chat(\?.*)?$/);
      await expect(chatA.chatInput).toBeVisible();

      // And both are really live, not merely still rendering a dead page.
      const line = `both screens alive ${Date.now()}`;
      await chatB.sendMessage(line);
      await chatA.expectMessageVisible(line);
      await shot(pageA, "first-screen-still-live");
    } finally {
      await ctxA.close();
      await ctxB.close();
    }
  });

  test("a fourth screen ends the oldest and spares the others (K12)", async ({
    browser,
  }) => {
    const contexts = [];
    const pages = [];

    const nick = uniqueNickname("cap");
    const pw = "testpass123";

    try {
      for (let i = 0; i < 4; i++) {
        const ctx = await browser.newContext();
        contexts.push(ctx);
        pages.push(await ctx.newPage());
      }

      const connect0 = new ConnectPage(pages[0]);
      const chat0 = new ChatPage(pages[0]);
      await connect0.open();
      await connect0.enterNickname(nick);
      await connect0.registerWithPassword(pw);
      await chat0.waitUntilConnected();

      // Screens two and three join the first without ending anything.
      for (let i = 1; i < 3; i++) {
        const connect = new ConnectPage(pages[i]);
        const chat = new ChatPage(pages[i]);
        await connect.open();
        await connect.enterNickname(nick);
        await connect.authenticateWithPassword(pw);
        await chat.waitUntilConnected();
      }

      await expect(pages[0]).toHaveURL(/\/chat(\?.*)?$/);

      // The fourth is one too many, and the oldest is the one that gives way.
      const connect3 = new ConnectPage(pages[3]);
      const chat3 = new ChatPage(pages[3]);
      await connect3.open();
      await connect3.enterNickname(nick);
      await connect3.authenticateWithPassword(pw);
      await chat3.waitUntilConnected();

      await expect(pages[0]).toHaveURL(/\/connect\?reason=/);
      const banner = pages[0].getByTestId("session-alert");
      await expect(banner).toBeVisible();
      await expect(banner).toContainText("Session ended");
      await expect(banner).toContainText("oldest window");

      // The two in the middle are untouched.
      await expect(pages[1]).toHaveURL(/\/chat(\?.*)?$/);
      await expect(pages[2]).toHaveURL(/\/chat(\?.*)?$/);
    } finally {
      for (const ctx of contexts) {
        await ctx.close();
      }
    }
  });
});
