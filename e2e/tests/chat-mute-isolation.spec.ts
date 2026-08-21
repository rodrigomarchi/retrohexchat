/**
 * @section AA - Reconnect, Multi-Context, Browser State, And Destructive Safety
 * @flow AA8 [done] Mute survives reload for the account that set it, silences its sound preview, and does not leak to another session (features P2)
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { Browser, BrowserContext, Page, expect, test } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";
import {
  expectNoSoundStarts,
  expectSoundStarts,
  installAudioSpy,
  resetAudioSpy,
} from "../helpers/audioSpy";

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  page: Page;
  nick: string;
};

async function newSignedInUser(
  browser: Browser,
  prefix = "aa8",
): Promise<TestUser> {
  const ctx = await browser.newContext();
  await installAudioSpy(ctx);
  const page = await ctx.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword("pass12345");
  await chat.waitUntilConnected();

  return { chat, ctx, page, nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe("Mute isolation between sessions", () => {
  test("mute survives reload for its own account and does not leak to another (AA8)", async ({
    browser,
  }) => {
    const mutedUser = await newSignedInUser(browser, "aa8m");
    const isolatedUser = await newSignedInUser(browser, "aa8i");

    try {
      await expect(mutedUser.chat.trayMuteToggle).toHaveAttribute(
        "aria-label",
        "Mute",
      );
      await mutedUser.chat.trayMuteToggle.click();
      await expect(mutedUser.chat.trayMuteToggle).toHaveAttribute(
        "aria-label",
        "Unmute",
      );

      await mutedUser.page.reload();
      await mutedUser.chat.waitUntilConnected();
      await expect(mutedUser.chat.trayMuteToggle).toHaveAttribute(
        "aria-label",
        "Unmute",
      );

      await mutedUser.chat.openSoundSettingsFromMenu();
      await resetAudioSpy(mutedUser.page);
      await mutedUser.chat.soundPreviewButton("message").click();
      await expectNoSoundStarts(mutedUser.page);
      await mutedUser.chat.soundSettingsDialog
        .getByRole("button", { name: "Cancel" })
        .click();

      await expect(isolatedUser.chat.trayMuteToggle).toHaveAttribute(
        "aria-label",
        "Mute",
      );

      await isolatedUser.chat.openSoundSettingsFromMenu();
      await resetAudioSpy(isolatedUser.page);
      await isolatedUser.chat.soundPreviewButton("message").click();
      await expectSoundStarts(isolatedUser.page, 1);
    } finally {
      await closeUsers([mutedUser, isolatedUser]);
    }
  });
});
