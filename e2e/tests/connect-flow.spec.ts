/**
 * @section Auth And Lifecycle
 * @flow A [done] Brand-new user registers a nickname and lands on `/chat`
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";

test.describe("Connect flow", () => {
  test("brand-new user registers a nickname and lands on /chat", async ({
    page,
  }) => {
    const connect = new ConnectPage(page);
    const nick = uniqueNickname();

    await connect.open();
    // The connect screen still titles itself through page_title — only the chat
    // hands document.title to a client-side owner.
    await expect(page).toHaveTitle("Connect - RetroHexChat");

    await connect.enterNickname(nick);
    await connect.registerWithPassword("testpass123");

    // After registration ConnectLive's JS hook posts a hidden form to
    // /chat/session, SessionController stores the nickname, and Phoenix
    // redirects to /chat where ChatLive mounts and names the tab after the
    // conversation on screen. Which conversation that is depends on the
    // auto-join, so assert only that the tab carries this user's nick —
    // chat-window-title.spec.ts owns the exact wording.
    await expect(page).toHaveURL(/\/chat(\?.*)?$/);
    await expect(page).toHaveTitle(new RegExp(`\\[${nick}\\]$`));
  });
});
