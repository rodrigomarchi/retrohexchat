/**
 * @section Auth And Lifecycle
 * @flow A [done] Brand-new user registers a nickname in the sign-in window and lands in the chat
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { CHAT_URL } from "../helpers/urls";

test.describe("Connect flow", () => {
  test("brand-new user registers a nickname and lands in the chat", async ({
    page,
  }) => {
    const connect = new ConnectPage(page);
    const nick = uniqueNickname();

    await connect.open();
    // The sign-in window in front names the tab; the chat names it once it is
    // the window in front.
    await expect(page).toHaveTitle("Connect - RetroHexChat");

    await connect.enterNickname(nick);
    await connect.registerWithPassword("testpass123");

    // After registration the sign-in form's hook posts a hidden form to
    // /chat/session, SessionController stores the nickname, and Phoenix
    // redirects to the desktop, where the chat names the tab after the
    // conversation on screen. Which conversation that is depends on the
    // auto-join, so assert only that the tab carries this user's nick —
    // chat-window-title.spec.ts owns the exact wording.
    await expect(page).toHaveURL(CHAT_URL);
    await expect(page).toHaveTitle(new RegExp(`\\[${nick}\\]$`));
  });
});
