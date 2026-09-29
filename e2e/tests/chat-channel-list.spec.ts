/**
 * @section H - Channels, Server Messages, Local Window State
 * @flow H8 [done] `/list` opens channel list; search and the row press join (features P1)
 * @flow H8b [done] a registered channel everybody left stays listed, says when it was last used, and still joins
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { Browser, expect, test } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";
import { shot } from "../helpers/screenshots";

function uniqueChannel(prefix = "list"): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(
  page: import("@playwright/test").Page,
  prefix = "e2e",
) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);
  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword("pass12345");
  await chat.waitUntilConnected();
  return { chat, nick };
}

async function setupListedChannel(browser: Browser, channel: string) {
  const ownerContext = await browser.newContext();
  const joinerContext = await browser.newContext();
  const ownerPage = await ownerContext.newPage();
  const joinerPage = await joinerContext.newPage();

  const owner = await signedInUser(ownerPage, "owner");
  const joiner = await signedInUser(joinerPage, "joiner");

  await owner.chat.sendMessage(`/join ${channel}`);
  await owner.chat.expectTabVisible(channel);

  return {
    ownerContext,
    joinerContext,
    joinerChat: joiner.chat,
  };
}

test.describe("Channel list dialog", () => {
  test("/list filters a unique channel and the row press joins it (H8)", async ({
    browser,
  }) => {
    const channel = uniqueChannel("listed");
    const { ownerContext, joinerContext, joinerChat } =
      await setupListedChannel(browser, channel);

    try {
      await joinerChat.sendMessage("/list");

      await expect(joinerChat.channelListSearch).toBeVisible();

      await joinerChat.channelListSearch.fill(channel.slice(1));
      await expect(joinerChat.channelListRow(channel)).toBeVisible();

      // The row says what its press does, and the press is the whole gesture:
      // there is no button under the list waiting for a selection.
      await expect(joinerChat.channelListRowAction(channel)).toHaveText("Join");
      await shot(joinerChat.channelListDialog, "row-is-the-door");
      await joinerChat.channelListRow(channel).click();

      await joinerChat.expectTabVisible(channel);
      await expect(joinerChat.channelListSearch).toBeHidden();
    } finally {
      await ownerContext.close();
      await joinerContext.close();
    }
  });

  test("a registered channel nobody is in stays listed and still joins (H8b)", async ({
    browser,
  }) => {
    const channel = uniqueChannel("cold");
    const ownerContext = await browser.newContext();
    const joinerContext = await browser.newContext();

    try {
      const ownerPage = await ownerContext.newPage();
      const owner = await signedInUser(ownerPage, "coldowner");

      // Registering is what makes the room outlive its last occupant: an
      // unregistered channel's process stops the moment it empties and the
      // room really is gone.
      await owner.chat.sendMessage(`/join ${channel}`);
      await owner.chat.expectTabVisible(channel);
      await owner.chat.sendMessage("/cs register");
      await owner.chat.sendMessage(`/part ${channel}`);
      await ownerContext.close();

      const joinerPage = await joinerContext.newPage();
      const joiner = await signedInUser(joinerPage, "coldjoiner");

      await joiner.chat.sendMessage("/list");
      await expect(joiner.chat.channelListSearch).toBeVisible();
      await joiner.chat.channelListSearch.fill(channel.slice(1));

      const row = joiner.chat.channelListRow(channel);
      await expect(row).toBeVisible();
      // The search input is debounced, so the row above is still visible from
      // the unfiltered list. Waiting for an unrelated row to go is what proves
      // the filtered list has actually landed — and it is what makes the
      // screenshot below evidence of the filtered window rather than of the
      // one that happened to be on screen 300ms earlier.
      await expect(joiner.chat.channelListRow("#lobby")).toBeHidden();
      await expect(
        joinerPage.getByTestId(`channel-list-activity-${channel}`),
      ).toBeVisible();
      await shot(joiner.chat.channelListDialog, "cold-channel-row");

      await row.click();
      await joiner.chat.expectTabVisible(channel);
      await shot(joinerPage, "cold-channel-joined");
    } finally {
      await ownerContext.close().catch(() => {});
      await joinerContext.close();
    }
  });
});
