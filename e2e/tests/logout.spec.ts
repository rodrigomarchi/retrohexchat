/**
 * @section Auth And Lifecycle
 * @flow L [done] Logged-in user disconnects via UI and lands on `/connect`
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";

test.describe("Logout", () => {
  test("logged-in user clicks File -> Disconnect -> Confirm and lands on /connect (L)", async ({
    page,
  }) => {
    const connect = new ConnectPage(page);
    const chat = new ChatPage(page);
    const nick = uniqueNickname();

    await connect.open();
    await connect.enterNickname(nick);
    await connect.registerWithPassword("testpass123");
    await chat.waitUntilConnected();

    await chat.disconnect();

    // Disconnecting ends the session (`/chat/session/clear?reason=logout`) and
    // opens a clean sign-in window: the reason banner is for a session that
    // ended on its own, like ?reason=expired, never for leaving on purpose.
    await expect(page).toHaveURL(/\/connect$/);
    await expect(connect.nicknameInput).toBeVisible();
  });
});
