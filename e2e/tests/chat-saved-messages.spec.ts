/**
 * @section S - Message Lifecycle Additions
 * @flow S13 [done] Saving a message from its menu keeps it in the Saved Messages window, privately, with a note (features P1)
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";
import { shot } from "../helpers/screenshots";

test("saving a message keeps it, privately, with a note (S13)", async ({
  page,
}) => {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname("sav");
  const channel = `#saved${Math.random().toString(36).slice(2, 8)}`;

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword("pass12345");
  await chat.waitUntilConnected();

  await chat.sendMessage(`/join ${channel}`);
  await chat.expectTabVisible(channel);
  await chat.sendMessage("the wiki address is at example.test/handbook");
  await chat.sendMessage("and the build link is example.test/nightly");

  const savedMenuItem = page.getByTestId("start-menu-item-open_saved_dialog");
  const savedWindow = page.locator('[data-testid="saved-window"]');

  async function openSavedWindow() {
    await chat.openStartGroup(
      page.getByTestId("start-menu-tools-submenu"),
      savedMenuItem,
    );
    await savedMenuItem.click();
    await expect(savedWindow).toBeVisible();
  }

  // Empty state first: the window has to open with nothing in it.
  await openSavedWindow();
  await shot(page, "saved-window-empty");
  await savedWindow.locator('[data-window-control="close"]').click();
  await expect(savedWindow).toBeHidden();

  // Then two saved lines, one with a note.
  await chat.openMessageContextMenu("the wiki address");
  await page.click('[data-testid="context-menu-item-ctx_chat_save_message"]');
  await chat.openMessageContextMenu("the build link");
  await page.click('[data-testid="context-menu-item-ctx_chat_save_message"]');

  // And the menu on a line already kept.
  await chat.openMessageContextMenu("the wiki address");
  await expect(
    page.locator('[data-testid="context-menu-item-ctx_chat_unsave_message"]'),
  ).toBeVisible();
  await shot(page, "saved-context-menu-unsave");
  await page.keyboard.press("Escape");

  await openSavedWindow();
  await expect(savedWindow.locator('[data-testid^="saved-row-"]')).toHaveCount(
    2,
  );

  const firstNote = savedWindow.locator('[data-testid^="saved-note-"]').first();
  await firstNote.fill("ask about this on Monday");
  await firstNote.press("Enter");

  await shot(page, "saved-window-filled");
});
