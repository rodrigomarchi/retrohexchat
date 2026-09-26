/**
 * @section U - Dialog CRUD And Settings Depth
 * @flow U19 [done] An administrator adds a server emoji from its window, and everybody writing :name: sees the picture while an unknown name stays text (features P2)
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";
import { adminNick, adminPassword } from "../helpers/env";
import { shot } from "../helpers/screenshots";

// The smallest thing a browser will accept as a picture: one magenta pixel.
const ONE_PIXEL_PNG = Buffer.from(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==",
  "base64",
);

test.describe("Server emoji", () => {
  test("an administrator adds one and the whole server can write it (U10)", async ({
    browser,
  }) => {
    const ctxAdmin = await browser.newContext();
    const ctxReader = await browser.newContext();
    const pageAdmin = await ctxAdmin.newPage();
    const pageReader = await ctxReader.newPage();

    const channel = `#emo${Math.random().toString(36).slice(2, 8)}`;
    const name = `e${Math.random().toString(36).slice(2, 8)}`;
    const readerNick = uniqueNickname("rea");

    try {
      const adminConnect = new ConnectPage(pageAdmin);
      const admin = new ChatPage(pageAdmin);
      await adminConnect.open();
      await adminConnect.signIn(adminNick(), adminPassword());
      await admin.waitUntilConnected();
      await admin.sendMessage(`/join ${channel}`);
      await admin.expectTabVisible(channel);

      // The window opens with nothing in it: a list you can only reach once it
      // has contents is a list nobody discovers.
      await admin.openStartGroup(
        pageAdmin.getByTestId("start-menu-admin-submenu"),
        pageAdmin.getByTestId("start-menu-item-open_server_emoji_dialog"),
      );
      await pageAdmin
        .getByTestId("start-menu-item-open_server_emoji_dialog")
        .click();

      const window = pageAdmin.locator('[data-testid="server-emoji-window"]');
      await expect(window).toBeVisible();
      await shot(pageAdmin, "server-emoji-empty");

      // A picture and a name, in the order somebody has them.
      await window.locator('input[type="file"]').setInputFiles({
        name: `${name}.png`,
        mimeType: "image/png",
        buffer: ONE_PIXEL_PNG,
      });
      await window.getByTestId("server-emoji-name").fill(name);
      await window.getByTestId("server-emoji-submit").click();

      await expect(
        window.locator(`[data-testid="server-emoji-row-${name}"]`),
      ).toBeVisible();
      await shot(pageAdmin, "server-emoji-added");

      // Out of the way: the point of the next frame is the conversation.
      await window.locator('[data-window-control="close"]').click();
      await expect(window).toBeHidden();

      // A second reader, who was never near the window, writes it by hand.
      const readerConnect = new ConnectPage(pageReader);
      const reader = new ChatPage(pageReader);
      await readerConnect.open();
      await readerConnect.enterNickname(readerNick);
      await readerConnect.registerWithPassword("pass12345");
      await reader.waitUntilConnected();
      await reader.sendMessage(`/join ${channel}`);
      await reader.expectTabVisible(channel);

      await reader.sendMessage(`well :${name}: then`);

      const drawn = pageAdmin.locator(
        `[data-testid="chat-message-list"] img.chat-emoji`,
      );
      await expect(drawn.first()).toBeVisible();
      await expect(drawn.first()).toHaveAttribute("alt", `:${name}:`);

      // And the name this server does not have stays a word.
      await reader.sendMessage(":nothing_here: stays text");
      await expect(
        pageAdmin.locator('[data-testid="chat-message-list"]'),
      ).toContainText(":nothing_here:");
      await expect(drawn).toHaveCount(1);

      await shot(pageAdmin, "server-emoji-in-conversation");
    } finally {
      await ctxAdmin.close();
      await ctxReader.close();
    }
  });
});
