/**
 * @section O - Chat UI Micro-Journeys
 * @flow O16 [done] Address Book add/edit/remove contact, notify, color, control entries (features P2)
 * @flow O17 [done] Custom nick color applies to chat nick rendering (features P2)
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { Locator, Page, test, expect } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";

async function signedInUser(page: Page, prefix = "addr") {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword("pass12345");
  await chat.waitUntilConnected();

  return { chat, nick };
}

async function submitDialogForm(form: Locator) {
  await form.getByRole("button", { name: "OK" }).click();
}

test.describe("Address Book", () => {
  test("dialog manages contacts, notify entries, nick colors, and control entries (O16)", async ({
    page,
  }) => {
    const { chat } = await signedInUser(page);
    const contactNick = uniqueNickname("ct");
    const notifyNick = uniqueNickname("nt");
    const colorNick = uniqueNickname("clr");
    const controlNick = uniqueNickname("ig");
    const contactNote = `contact-note-${Date.now()}`;
    const contactEdited = `contact-edited-${Date.now()}`;
    const notifyNote = `notify-note-${Date.now()}`;
    const notifyEdited = `notify-edited-${Date.now()}`;

    await chat.openAddressBookFromMenu();

    await chat.addressBookDialog.getByTestId("contact-add").click();
    let form = page.getByTestId("contact-add-form");
    await form.locator("#contact-add-nick").fill(contactNick);
    await form.locator("#contact-add-note").fill(contactNote);
    await submitDialogForm(form);
    await expect(chat.addressBookContactRow(contactNick)).toContainText(
      contactNote,
    );

    await page.getByTestId(`contact-edit-${contactNick}`).click();
    form = page.getByTestId("contact-edit-form");
    await form.locator("#contact-edit-note").fill(contactEdited);
    await submitDialogForm(form);
    await expect(chat.addressBookContactRow(contactNick)).toContainText(
      contactEdited,
    );

    await page.getByTestId(`contact-remove-${contactNick}`).click();
    await expect(chat.addressBookContactRow(contactNick)).toHaveCount(0);

    await chat.openNotifyListFromMenu();
    await chat.notifyListDialog.getByTestId("notify-list-add").click();
    form = page.getByTestId("notify-add-form");
    await form.locator("#notify-add-nickname").fill(notifyNick);
    await form.locator("#notify-add-note").fill(notifyNote);
    await submitDialogForm(form);
    await expect(chat.notifyListRow(notifyNick)).toContainText(notifyNote);
    await expect(chat.notifyListRow(notifyNick)).toContainText("Offline");

    // The row press is the whole gesture — it names the entry and opens it.
    await chat.notifyListRow(notifyNick).click();
    form = page.getByTestId("notify-edit-form");
    await form.locator("#notify-edit-note").fill(notifyEdited);
    await submitDialogForm(form);
    await expect(chat.notifyListRow(notifyNick)).toContainText(notifyEdited);

    await chat.notifyListDialog
      .getByTestId(`notify-list-remove-${notifyNick}`)
      .click();
    await expect(chat.notifyListRow(notifyNick)).toHaveCount(0);

    await chat.openNickColorsFromMenu();
    await chat.nickColorsDialog.getByTestId("nick-color-add").click();
    form = page.getByTestId("nick-color-add-form");
    await form.locator("#nick-color-add-nick").fill(colorNick);
    await chat.pickColor(form, 4);
    await submitDialogForm(form);
    await expect(chat.addressBookNickColorRow(colorNick)).toHaveAttribute(
      "data-color-index",
      "4",
    );

    await page.getByTestId(`nick-color-edit-${colorNick}`).click();
    form = page.getByTestId("nick-color-edit-form");
    await chat.pickColor(form, 5);
    await submitDialogForm(form);
    await expect(chat.addressBookNickColorRow(colorNick)).toHaveAttribute(
      "data-color-index",
      "5",
    );

    await page.getByTestId(`nick-color-remove-${colorNick}`).click();
    await expect(chat.addressBookNickColorRow(colorNick)).toHaveCount(0);

    await chat.openIgnoreListFromMenu();
    await chat.ignoreListDialog.getByTestId("control-add").click();
    form = page.getByTestId("control-add-form");
    await form.locator("#control-add-nick").fill(controlNick);
    await form.locator("#control-add-type").selectOption("messages");
    await submitDialogForm(form);
    await expect(chat.addressBookControlRow(controlNick)).toContainText(
      "messages",
    );

    await page.getByTestId(`control-remove-${controlNick}`).click();
    await expect(chat.addressBookControlRow(controlNick)).toHaveCount(0);

    await chat.closeAddressBook();
  });

  test("custom nick color applies to message nick rendering (O17)", async ({
    page,
  }) => {
    const { chat, nick } = await signedInUser(page, "clrusr");
    const message = `custom color message ${Date.now()}`;

    await chat.openAddressBookFromMenu();
    await chat.openNickColorsFromMenu();

    await chat.nickColorsDialog.getByTestId("nick-color-add").click();
    const form = page.getByTestId("nick-color-add-form");
    await form.locator("#nick-color-add-nick").fill(nick);
    await chat.pickColor(form, 4);
    await submitDialogForm(form);
    await expect(chat.addressBookNickColorRow(nick)).toHaveAttribute(
      "data-color-index",
      "4",
    );

    await chat.closeAddressBook();
    await chat.sendMessage(message);
    await chat.expectMessageVisible(message);

    await expect(chat.messageNickByText(message, nick)).toHaveClass(/irc-fg-4/);
  });
});
