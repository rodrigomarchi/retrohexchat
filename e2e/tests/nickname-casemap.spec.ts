/**
 * @section W - Presence, Identity, Nick Changes, Whois/Whowas
 * @flow W14 [done] Another case of a registered nickname asks for its password and signs in shown as typed
 * @flow W15 [done] `/msg alice` reaches whoever is online as AlIcE, live
 * @flow W16 [done] `/op alice` finds the member AlIcE and the nick list keeps her spelling
 * @flow W17 [done] An identified user changes only the case of their nickname without a password
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { expect, test } from "@playwright/test";
import {
  closeUsers,
  newSignedInUser,
  TestUser,
  uniqueChannel,
} from "../helpers/chatUsers";
import { ChatPage } from "../pages/ChatPage";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";

/** A nickname with capitals in it, so other cases of it are visibly other spellings. */
function mixedCase(prefix: string): string {
  const nick = uniqueNickname(prefix);
  return (
    nick.slice(0, 1).toUpperCase() +
    nick.slice(1, -1) +
    nick.slice(-1).toUpperCase()
  );
}

async function signedInAs(
  browser: import("@playwright/test").Browser,
  nick: string,
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword("pass12345");
  await chat.waitUntilConnected();
  return { chat, connect, ctx, page, nick, password: "pass12345" };
}

test.describe("One nickname whatever its case", () => {
  test("another case of a registered nickname asks for its password (W14)", async ({
    browser,
  }) => {
    const owner = await signedInAs(browser, mixedCase("cm"));
    await owner.chat.disconnect();
    await owner.ctx.close();

    const ctx = await browser.newContext();
    const page = await ctx.newPage();
    const connect = new ConnectPage(page);
    const chat = new ChatPage(page);
    const typed = owner.nick.toLowerCase();

    try {
      await connect.open();
      await connect.enterNickname(typed);
      // The registration's password, not a new registration.
      await expect(connect.authPasswordInput).toBeVisible();
      await connect.authenticateWithPassword(owner.password);
      await chat.waitUntilConnected();

      await chat.expectNickInList(typed);
      await expect(
        page.locator('[data-testid="chat-window"] .window-title-meta'),
      ).toContainText("Identified");
    } finally {
      await ctx.close();
    }
  });

  test("/msg alice reaches AlIcE live (W15)", async ({ browser }) => {
    const alice = await signedInAs(browser, mixedCase("cp"));
    const bob = await newSignedInUser(browser, "cpbob");
    const text = `case-pm-${Date.now()}`;

    try {
      await bob.chat.sendMessage(`/msg ${alice.nick.toLowerCase()} ${text}`);

      await alice.chat.expectTabVisible(bob.nick);
      await alice.chat.switchToTab(bob.nick);
      await alice.chat.expectMessageVisible(text);
    } finally {
      await closeUsers([alice, bob]);
    }
  });

  test("/op alice finds AlIcE in the channel (W16)", async ({ browser }) => {
    const owner = await newSignedInUser(browser, "coown");
    const alice = await signedInAs(browser, mixedCase("co"));
    const channel = uniqueChannel("case");

    try {
      await owner.chat.sendMessage(`/join ${channel}`);
      await owner.chat.expectTabVisible(channel);
      await alice.chat.sendMessage(`/join ${channel}`);
      await alice.chat.expectTabVisible(channel);
      await owner.chat.switchToTab(channel);
      await owner.chat.expectNickInList(alice.nick);

      await owner.chat.sendMessage(`/op ${alice.nick.toUpperCase()}`);

      await owner.chat.expectNickRole(alice.nick, "operator");
    } finally {
      await closeUsers([owner, alice]);
    }
  });

  test("a change of case needs no password (W17)", async ({ browser }) => {
    const alice = await signedInAs(browser, mixedCase("cn"));
    const recased = alice.nick.toUpperCase();

    try {
      await alice.chat.sendMessage(`/nick ${recased}`);
      await expect(alice.chat.nickChangeDialog).toBeVisible();
      await expect(alice.chat.nickChangePassword).toBeHidden();

      await alice.chat.confirmNickChange();

      await alice.chat.expectNickInList(recased);
      await expect(
        alice.page.locator('[data-testid="chat-window"] .window-title-meta'),
      ).toContainText("Identified");
    } finally {
      await closeUsers([alice]);
    }
  });
});
