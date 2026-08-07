/**
 * @section R/Y - Security, Safety, And Rendering Additions
 * @flow R10 [done] Empty message edit opens delete confirmation and cancel restores normal input state (features P1)
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
  await connect.enterNickname(uniqueNickname("editempty"));
  await connect.registerWithPassword("pass12345");
  await chat.waitUntilConnected();

  return chat;
}

function uniqueChannel(prefix = "editempty"): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

test.describe("Message edit/delete edge cases", () => {
  test("editing a message to empty opens delete confirmation and cancel restores normal input state (R10)", async ({
    page,
  }) => {
    const chat = await signedInUser(page);
    const channel = uniqueChannel();
    const marker = Date.now();
    const original = `empty-edit-original-${marker}`;
    const afterCancel = `empty-edit-after-cancel-${marker}`;

    await chat.sendMessage(`/join ${channel}`);
    await chat.expectTabVisible(channel);
    await chat.expectTabSelected(channel);

    await chat.sendMessage(original);
    const originalRow = chat.messageRowByText(original);
    await expect(originalRow).toBeVisible();

    await chat.chatInput.press("ArrowUp");
    await expect(chat.chatInput).toHaveValue(original);

    await chat.chatInput.fill("");
    await chat.chatInput.press("Enter");

    await expect(chat.deleteConfirmButton).toBeVisible();
    await expect(chat.chatInput).toHaveValue("");
    await expect(chat.chatSendButton).toBeDisabled();

    await chat.deleteCancelButton.click();

    await expect(chat.deleteConfirmButton).toBeHidden();
    await expect(originalRow).toBeVisible();
    await expect(chat.messageList.getByTestId("deleted-message")).toHaveCount(
      0,
    );
    await expect(chat.chatInput).toBeEnabled();
    await expect(chat.chatInput).toHaveValue("");
    await expect(chat.chatSendButton).toBeDisabled();

    await chat.sendMessage(afterCancel);
    await chat.expectMessageVisible(afterCancel);
  });
});
