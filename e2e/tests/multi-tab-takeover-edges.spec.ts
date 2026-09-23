/**
 * @section AA - Reconnect, Multi-Context, Browser State, And Destructive Safety
 * @flow AA4 [done] A second context of the same nickname leaves the first one's unsaved draft and open dialog intact, and starts clean itself
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { expect, test } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";

test.describe("Two screens, unfinished work on one", () => {
  test("the second screen inherits no local state and disturbs none (AA4)", async ({
    browser,
  }) => {
    const ctxA = await browser.newContext();
    const ctxB = await browser.newContext();
    const pageA = await ctxA.newPage();
    const pageB = await ctxB.newPage();
    const nick = uniqueNickname("aa4");
    const password = "testpass123";
    const draft = `aa4 unsent draft ${Date.now()}`;
    const alias = `aa4${Math.random().toString(36).slice(2, 7)}`;
    const expansion = `/me aa4 unsaved alias ${Date.now()}`;
    const message = `aa4 new session alive ${Date.now()}`;

    try {
      const connectA = new ConnectPage(pageA);
      const chatA = new ChatPage(pageA);
      await connectA.open();
      await connectA.enterNickname(nick);
      await connectA.registerWithPassword(password);
      await chatA.waitUntilConnected();

      await chatA.chatInput.fill(draft);
      await chatA.openAliasEditorFromMenu();
      await chatA.startAliasAdd();
      await chatA.fillAliasDraft(alias, expansion);
      await expect(chatA.aliasDialog).toBeVisible();
      await expect(
        chatA.aliasEditForm.getByTestId("alias-name-input"),
      ).toHaveValue(alias);

      const connectB = new ConnectPage(pageB);
      const chatB = new ChatPage(pageB);
      await connectB.open();
      await connectB.enterNickname(nick);
      await connectB.authenticateWithPassword(password);
      await chatB.waitUntilConnected();

      // What one screen has half-finished is its own: the draft is still typed
      // and the dialog is still open, because the second screen no longer ends
      // the first.
      await expect(pageA).toHaveURL(/\/chat(\?.*)?$/);
      await expect(chatA.chatInput).toHaveValue(draft);
      await expect(chatA.aliasDialog).toBeVisible();

      // And none of it leaks the other way: the new screen starts clean.
      await chatB.expectTabSelected("#lobby");
      await expect(chatB.aliasDialog).toBeHidden();
      await expect(chatB.chatInput).toHaveValue("");
      await chatB.sendMessage(message);
      await chatB.expectMessageVisible(message);

      // The line sent from B reaches A, which is the proof A is still live
      // rather than merely still painted.
      await chatA.expectMessageVisible(message);
    } finally {
      await ctxA.close();
      await ctxB.close();
    }
  });
});
