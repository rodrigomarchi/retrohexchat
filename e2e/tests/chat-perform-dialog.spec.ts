/**
 * @section U - Dialog CRUD And Settings Depth
 * @flow U6 [done] Perform window edit/move/toggle-enabled paths mirror slash command behavior and reconnect execution (features P1)
 * @flow U7 [done] Auto-Join window add/edit/remove paths mirror slash command behavior and reconnect execution (features P1)
 * @flow U6b [done] Removing the last row keeps the keyboard inside the list instead of dropping it on the page
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { Page, test, expect } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";

function uniqueChannel(prefix = "pfdlg"): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(
  page: Page,
  prefix = "pfdlg",
  password = "pass12345",
) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword(password);
  await chat.waitUntilConnected();

  return { chat, nick, password };
}

async function reconnectRegisteredUser(
  page: Page,
  chat: ChatPage,
  nick: string,
  password: string,
) {
  const connect = new ConnectPage(page);

  await chat.disconnect();
  await connect.open();
  await connect.enterNickname(nick);
  await connect.authenticateWithPassword(password);
  await chat.waitUntilConnected();
}

test.describe("Perform dialog", () => {
  test("edits, moves, and toggles perform commands with reconnect behavior (U6)", async ({
    page,
  }) => {
    const { chat, nick, password } = await signedInUser(page);
    const firstChannel = uniqueChannel("pfold");
    const editedChannel = uniqueChannel("pfedit");
    const movedChannel = uniqueChannel("pfmove");
    const firstCommand = `/join ${firstChannel}`;
    const editedCommand = `/join ${editedChannel}`;
    const movedCommand = `/join ${movedChannel}`;

    await chat.openPerformDialogFromMenu();
    await chat.addPerformCommand(firstCommand);
    await chat.addPerformCommand(movedCommand);

    await chat.editPerformCommand(firstCommand, editedCommand);
    await chat.movePerformCommandUp(movedCommand);

    // Reordering must not cost the arrow its focus: the row stays, so the
    // browser has somewhere real to leave it.
    await expect(
      page.locator('[data-testid^="perform-move-up-"]:focus'),
    ).toHaveCount(1);

    await expect(chat.performEnabledCheckbox()).toBeChecked();
    await chat.performEnabledCheckbox().click();
    await expect(chat.performEnabledCheckbox()).not.toBeChecked();
    // The remove button leaves with the row it removes. When nothing takes its
    // index — the last row — the browser drops focus on the page body unless
    // the list catches it, and a reader tidying a list from the bottom loses
    // their place on every press. Added and removed here so the command list
    // below is the one the rest of this test is about.
    const rows = page.locator(".action-list__row");
    await chat.addPerformCommand(`/join ${uniqueChannel("pffocus")}`);
    const last = (await rows.count()) - 1;
    await page.getByTestId(`perform-remove-${last}`).focus();
    await page.getByTestId(`perform-remove-${last}`).click();
    await expect(rows).toHaveCount(last);
    await expect(page.locator(".action-list:focus")).toHaveCount(1);

    await chat.closePerformDialog();

    await chat.sendMessage("/clear");
    await chat.sendMessage("/perform list");
    await chat.expectMessageVisible(`0: ${movedCommand}`);
    await chat.expectMessageVisible(`1: ${editedCommand}`);
    await chat.expectMessageHidden(firstCommand);

    await page.waitForTimeout(500);
    await reconnectRegisteredUser(page, chat, nick, password);
    await chat.expectTabHidden(movedChannel);
    await chat.expectTabHidden(editedChannel);

    await chat.openPerformDialogFromMenu();
    await expect(chat.performEnabledCheckbox()).not.toBeChecked();
    await chat.performEnabledCheckbox().click();
    await expect(chat.performEnabledCheckbox()).toBeChecked();
    await chat.closePerformDialog();

    await page.waitForTimeout(500);
    await reconnectRegisteredUser(page, chat, nick, password);
    await chat.expectTabVisible(movedChannel);
    await chat.expectTabVisible(editedChannel);
    await chat.expectTabSelected("#lobby");

    await chat.switchToStatusTab();
    await chat.expectStatusMessageVisible(`* Performing: ${movedCommand}`);
    await chat.expectStatusMessageVisible(`* Performing: ${editedCommand}`);
  });

  test("Auto-Join window adds, edits, removes, and affects reconnect behavior (U7)", async ({
    page,
  }) => {
    const { chat, nick, password } = await signedInUser(page, "ajdlg");
    const keyedChannel = uniqueChannel("ajkey");
    const removedChannel = uniqueChannel("ajrm");
    const editedKey = `edited-${Date.now()}`;

    await chat.openAutojoinDialogFromMenu();
    await chat.addAutojoinEntry(keyedChannel, "first-key");
    await expect(chat.autojoinRow(keyedChannel)).toContainText("***");
    await chat.addAutojoinEntry(removedChannel);

    await chat.editAutojoinKey(keyedChannel, editedKey);
    await chat.rowPress(chat.autojoinRow(keyedChannel)).click();
    await expect(
      chat.autojoinEditDialog.locator("#autojoin-edit-key"),
    ).toHaveValue(editedKey);
    await chat.autojoinEditDialog
      .getByRole("button", { name: "Cancel" })
      .click();
    await expect(chat.autojoinEditDialog).toBeHidden();

    await chat.removeAutojoinEntry(removedChannel);
    await chat.closeAutojoinDialog();

    await chat.sendMessage("/clear");
    await chat.sendMessage("/autojoin list");
    await chat.expectMessageVisible(`${keyedChannel} (key: ****)`);
    await chat.expectMessageHidden(removedChannel);

    await page.waitForTimeout(500);
    await reconnectRegisteredUser(page, chat, nick, password);
    await chat.expectTabVisible(keyedChannel);
    await chat.expectTabHidden(removedChannel);
    await chat.expectTabSelected("#lobby");

    await chat.switchToStatusTab();
    await chat.expectStatusMessageVisible(`* Auto-joining ${keyedChannel}...`);

    await chat.openAutojoinDialogFromMenu();
    await chat.removeAutojoinEntry(keyedChannel);
    await chat.closeAutojoinDialog();

    await chat.switchToTab("#lobby");
    await chat.sendMessage("/clear");
    await chat.sendMessage("/autojoin list");
    await chat.expectMessageVisible("Your auto-join list is empty");
  });
});
