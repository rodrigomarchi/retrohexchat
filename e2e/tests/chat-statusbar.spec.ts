/**
 * @section O - Chat UI Micro-Journeys
 * @flow O19 [done] Status bar mute toggle affects client state and survives rerender (features P2)
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { Page, test, expect } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";

async function signedInUser(page: Page) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);

  await connect.open();
  await connect.enterNickname(uniqueNickname("status"));
  await connect.registerWithPassword("pass12345");
  await chat.waitUntilConnected();

  return chat;
}

async function expectClientMuteState(page: Page, muted: boolean) {
  await expect
    .poll(() =>
      page.evaluate(() => localStorage.getItem("retro_hex_chat_mute")),
    )
    .toBe(muted.toString());
}

test.describe("Status bar", () => {
  test("mute toggle updates client audio state and survives rerender (O19)", async ({
    page,
  }) => {
    const chat = await signedInUser(page);
    const rerenderMessage = `statusbar rerender ${Date.now()}`;

    await expect(chat.statusBarApp).toBeVisible();
    await expect(chat.statusBarMuteToggle).toHaveAttribute(
      "aria-label",
      "Mute",
    );

    await chat.statusBarMuteToggle.click();
    await expect(chat.statusBarMuteToggle).toHaveAttribute(
      "aria-label",
      "Unmute",
    );
    await expectClientMuteState(page, true);

    await chat.sendMessage(rerenderMessage);
    await chat.expectMessageVisible(rerenderMessage);
    await expect(chat.statusBarMuteToggle).toHaveAttribute(
      "aria-label",
      "Unmute",
    );
    await expectClientMuteState(page, true);

    await chat.statusBarMuteToggle.click();
    await expect(chat.statusBarMuteToggle).toHaveAttribute(
      "aria-label",
      "Mute",
    );
    await expectClientMuteState(page, false);
  });
});
