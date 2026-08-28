/**
 * @section Auth And Lifecycle
 * @flow K2 [done] A game surface tab and the chat tab coexist in one browser context, and a chat takeover ends only the chat
 * @flow K3 [done] A game address with no session lands on connect and reaches the game once the nickname is registered
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { expect, test } from "@playwright/test";
import { ChatPage } from "../pages/ChatPage";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";

const PASSWORD = "testpass123";

// The chat announces a takeover on the person's inbox when it mounts, which is
// what ends a previous chat session. Everything here is about a second tab that
// is NOT the chat: it has to survive that announcement.
test.describe("A surface tab beside the chat", () => {
  test("coexists with the chat, and a takeover ends only the chat (K2)", async ({
    browser,
  }) => {
    // One context: the same cookie, the same session — which is the case that
    // used to be impossible. Two contexts would prove something weaker.
    const context = await browser.newContext();
    const chatTab = await context.newPage();
    const gameTab = await context.newPage();

    const nick = uniqueNickname();

    try {
      const connect = new ConnectPage(chatTab);
      const chat = new ChatPage(chatTab);
      await connect.open();
      await connect.enterNickname(nick);
      await connect.registerWithPassword(PASSWORD);
      await chat.waitUntilConnected();

      // Opening the game surface must not disturb the chat.
      await gameTab.goto("/play/hex_pong");
      await expect(gameTab.getByTestId("retro-games-window")).toBeVisible();
      await expect(chatTab).toHaveURL(/\/chat(\?.*)?$/);
      await expect(chatTab.getByTestId("session-alert")).toHaveCount(0);
      await expect(chat.menuBar).toBeVisible();

      // And the chat must not disturb the game surface: a third tab taking the
      // nickname over ends the chat and leaves the game running.
      const secondChatTab = await context.newPage();
      const secondConnect = new ConnectPage(secondChatTab);
      const secondChat = new ChatPage(secondChatTab);
      await secondConnect.open();
      await secondConnect.enterNickname(nick);
      await secondConnect.authenticateWithPassword(PASSWORD);
      await secondChat.waitUntilConnected();

      await expect(chatTab).toHaveURL(/\/connect\?reason=/);
      await expect(gameTab).toHaveURL(/\/play\/hex_pong$/);
      await expect(gameTab.getByTestId("retro-games-window")).toBeVisible();

      // The way back is always on screen, including for someone who arrived
      // from a shared link and has no chat tab of their own.
      await expect(gameTab.getByTestId("play-back-to-chat")).toBeVisible();
    } finally {
      await context.close();
    }
  });

  test("a game address reaches the game once there is a session (K3)", async ({
    browser,
  }) => {
    const context = await browser.newContext();
    const page = await context.newPage();
    const nick = uniqueNickname();

    try {
      // Arriving with no session at all lands on connect, not on an error.
      await page.goto("/play/hex_pong");
      await expect(page).toHaveURL(/\/connect/);

      const connect = new ConnectPage(page);
      await connect.open();
      await connect.enterNickname(nick);
      await connect.registerWithPassword(PASSWORD);
      await new ChatPage(page).waitUntilConnected();

      await page.goto("/play/hex_pong");
      await expect(page.getByTestId("retro-games-window")).toBeVisible();
      await expect(
        page.getByTestId("retro-game-session-hex_pong"),
      ).toBeVisible();
    } finally {
      await context.close();
    }
  });
});
