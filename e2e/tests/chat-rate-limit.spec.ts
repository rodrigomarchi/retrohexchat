/**
 * @section R/Y - Security, Safety, And Rendering Additions
 * @flow R9 [done] P2P command errors and failed sends leave no stale pending messages or disabled input (features P2)
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { Browser, BrowserContext, Page, test, expect } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = "ratelimit"): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix: string) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword("pass12345");
  await chat.waitUntilConnected();

  return { chat, nick };
}

async function newSignedInUser(
  browser: Browser,
  prefix: string,
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const user = await signedInUser(page, prefix);

  return { chat: user.chat, ctx, nick: user.nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

async function expectNoPendingMessages(chat: ChatPage) {
  await expect(
    chat.messageList.locator('[data-msg-status="pending"]'),
  ).toHaveCount(0);
}

async function expectInputIdle(chat: ChatPage) {
  await expect(chat.chatInput).toBeEnabled();
  await expect(chat.chatInput).toHaveValue("");
  await expect(chat.chatSendButton).toBeDisabled();
}

test.describe("Rate-limit and send-error input state", () => {
  // How many sessions a person may create in a window is enforced by
  // `RateLimiter.check_session_rate/3` and covered in its own test. It cannot be
  // reached from the composer any more — a duplicate request is refused before
  // it counts — so what is driven here is the refusal a user can actually
  // provoke.
  test("P2P command errors leave no pending messages and keep input usable (R9)", async ({
    browser,
  }) => {
    const alice = await newSignedInUser(browser, "rcla");
    const bob = await newSignedInUser(browser, "rclb");
    const afterError = `after-p2p-error-${Date.now()}`;

    try {
      // Creating the session IS inviting, so /p2p sends the request straight
      // away and writes its card into the conversation. Nobody is put inside
      // anything: the card is the door, in a tab of its own.
      await alice.chat.sendMessage(`/p2p ${bob.nick}`);
      await expect(
        alice.chat.page.getByTestId("p2p-starting-room"),
      ).toHaveCount(0);
      await expect(
        alice.chat.page.getByTestId("p2p-peer-entry"),
      ).toHaveAttribute("href", /\/p2p\//);
      await alice.chat.expectMessageVisible(
        `P2P request sent to ${bob.nick}. Open it from the card below.`,
      );

      // Asking again is refused, and the refusal is what this spec is about:
      // an error answering a command must leave the composer clean.
      await alice.chat.sendMessage(`/p2p ${bob.nick}`);
      await alice.chat.expectMessageVisible(
        "An active lobby already exists with this user",
      );

      await expectNoPendingMessages(alice.chat);
      await expectInputIdle(alice.chat);

      await alice.chat.sendMessage(afterError);
      await alice.chat.expectMessageVisible(afterError);
    } finally {
      await closeUsers([alice, bob]);
    }
  });

  test("failed channel sends clear pending state and leave input ready after flood-style errors (R9)", async ({
    browser,
  }) => {
    const channel = uniqueChannel();
    const alice = await newSignedInUser(browser, "rfla");
    const bob = await newSignedInUser(browser, "rflb");
    const blocked = `moderated-blocked-${Date.now()}`;

    try {
      await alice.chat.sendMessage(`/join ${channel}`);
      await alice.chat.expectTabVisible(channel);
      await bob.chat.sendMessage(`/join ${channel}`);
      await bob.chat.expectTabVisible(channel);
      await alice.chat.switchToTab(channel);
      await bob.chat.switchToTab(channel);

      await alice.chat.sendMessage("/mode +m");
      await alice.chat.expectMessageVisible(`${alice.nick} sets mode +m`);

      await bob.chat.sendMessage(blocked);
      const failedRow = bob.chat.messageRowByText(blocked);
      await expect(failedRow).toHaveAttribute("data-msg-status", "failed");
      await expect(failedRow.getByTestId("retry-message")).toBeVisible();
      await alice.chat.expectMessageHidden(blocked);

      await expectNoPendingMessages(bob.chat);
      await expectInputIdle(bob.chat);

      await bob.chat.chatInput.fill("draft after failed send");
      await expect(bob.chat.chatSendButton).toBeEnabled();
    } finally {
      await closeUsers([alice, bob]);
    }
  });
});
