/**
 * @section Backlog T - Desktop Shell, Menus, Toolbars, Dialogs, And Keyboard
 * @flow T13 [done] Taskbar collapses a window family into one grouped entry, expands it, and drops back to a plain button (features P2)
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { Page, test, expect } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";

async function signedInUser(page: Page, prefix = "tbg") {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword("pass12345");
  await chat.waitUntilConnected();

  return { chat, nick };
}

test.describe("Taskbar groups", () => {
  test("a window family collapses into one taskbar entry once two are open (T6)", async ({
    page,
  }) => {
    const { chat } = await signedInUser(page);

    // One account window open: it keeps its own button, no group.
    await chat.openAccountProfileFromMenu();
    await expect(chat.taskbarButton("profile")).toBeVisible();
    await expect(chat.taskbarGroup("account")).toHaveCount(0);

    // A second one collapses the family into a single entry.
    await chat.openAwayFromMenu();
    await expect(chat.taskbarGroup("account")).toBeVisible();
    await expect(chat.taskbarGroup("account")).toContainText("2");

    // The panel is closed until the group is clicked.
    await expect(chat.taskbarGroupPanel("account")).toBeHidden();
    await chat.taskbarGroup("account").click();
    await expect(chat.taskbarGroupPanel("account")).toBeVisible();

    // Picking a window out of the panel focuses it and closes the panel.
    await chat.taskbarGroupPanel("account").getByText("Profile").click();
    await expect(chat.taskbarGroupPanel("account")).toBeHidden();
    await expect(chat.profileDialog).toBeVisible();

    // Closing one member drops the family back to a plain button. Profile is the
    // focused window after the pick, so it is the one on top and clickable.
    await chat.profileDialog.locator('[data-window-control="close"]').click();
    await expect(chat.taskbarGroup("account")).toHaveCount(0);
    await expect(chat.taskbarButton("away")).toBeVisible();
  });
});
