/**
 * @section O - Chat UI Micro-Journeys
 * @flow O19 [done] Status bar mute toggle reflects mute state and survives rerender (features P2)
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

/**
 * The status bar's own reading of mute: the label and the icon it swaps.
 *
 * Mute is server state now, so there is nothing in the browser to read. Whether
 * a muted client actually stays silent is proved in `chat-sound-settings` (U4),
 * which counts the sounds it starts; repeating that here would be the same
 * proof twice. What belongs to the status bar is that its control tells the
 * truth and keeps telling it across a rerender.
 */
async function expectMuteControl(chat: ChatPage, muted: boolean) {
  await expect(chat.statusBarMuteToggle).toHaveAttribute(
    "aria-label",
    muted ? "Unmute" : "Mute",
  );
  await expect(chat.statusBarMuteToggle.locator("svg")).toHaveCount(1);
}

test.describe("Status bar", () => {
  test("mute toggle reflects mute state and survives rerender (O19)", async ({
    page,
  }) => {
    const chat = await signedInUser(page);
    const rerenderMessage = `statusbar rerender ${Date.now()}`;

    await expect(chat.statusBarApp).toBeVisible();
    await expectMuteControl(chat, false);

    await chat.statusBarMuteToggle.click();
    await expectMuteControl(chat, true);

    await chat.sendMessage(rerenderMessage);
    await chat.expectMessageVisible(rerenderMessage);
    await expectMuteControl(chat, true);

    await chat.statusBarMuteToggle.click();
    await expectMuteControl(chat, false);
  });
});
