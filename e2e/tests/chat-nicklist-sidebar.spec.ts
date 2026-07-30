import { Browser, BrowserContext, Page, expect, test } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";
import { shot } from "../helpers/screenshots";

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = "nickui"): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = "nu") {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open(process.env.E2E_LOCALE);
  await connect.enterNickname(nick);
  await connect.registerWithPassword("pass12345");
  await chat.waitUntilConnected();

  return { chat, nick };
}

async function newSignedInUser(
  browser: Browser,
  prefix = "nu",
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const { chat, nick } = await signedInUser(page, prefix);

  return { chat, ctx, nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe("Nicklist sidebar", () => {
  test("renders a role-grouped IRC roster with status badges in the platform", async ({
    browser,
  }) => {
    const channel = uniqueChannel();
    const owner = await newSignedInUser(browser, "nko");
    const operator = await newSignedInUser(browser, "nkp");
    const voiced = await newSignedInUser(browser, "nkv");
    const away = await newSignedInUser(browser, "nka");
    const muted = await newSignedInUser(browser, "nkm");

    try {
      for (const user of [owner, operator, voiced, away, muted]) {
        await user.chat.page.setViewportSize({ width: 1600, height: 900 });
        await user.chat.sendMessage(`/join ${channel}`);
        await user.chat.expectTabVisible(channel);
      }

      await owner.chat.switchToTab(channel);
      await owner.chat.sendMessage(`/op ${operator.nick}`);
      await owner.chat.sendMessage(`/voice ${voiced.nick}`);
      await owner.chat.sendMessage(`/mute ${muted.nick}`);
      await owner.chat.expectMessageVisible(
        `${muted.nick} has been muted in ${channel}.`,
      );

      const awayMessage = `nicklist-away-${Date.now()}`;
      await away.chat.switchToTab(channel);
      await away.chat.sendMessage(`/away ${awayMessage}`);
      await away.chat.expectMessageVisible(`You are now away: ${awayMessage}`);

      await owner.chat.switchToTab(channel);
      await owner.chat.expectNickInList(owner.nick);
      await owner.chat.expectNickRole(owner.nick, "owner");
      await owner.chat.expectNickRole(operator.nick, "operator");
      await owner.chat.expectNickRole(voiced.nick, "voiced");
      await owner.chat.expectNickStatus(away.nick, "away");

      await expect(
        owner.chat.page.getByTestId("nicklist-header"),
      ).toContainText(channel);
      await expect(
        owner.chat.page.getByTestId("nicklist-section-owner"),
      ).toContainText(owner.nick);
      await expect(
        owner.chat.page.getByTestId("nicklist-section-operator"),
      ).toContainText(operator.nick);
      await expect(
        owner.chat.page.getByTestId("nicklist-section-voiced"),
      ).toContainText(voiced.nick);
      await expect(
        owner.chat.page.getByTestId("nicklist-section-regular"),
      ).toContainText(away.nick);
      await expect(owner.chat.nicklistItem(muted.nick)).toHaveAttribute(
        "data-muted",
        "true",
      );
      await expect(
        owner.chat.page.getByTestId("nicklist-online-count"),
      ).toHaveText("4");
      await expect(
        owner.chat.page.getByTestId("nicklist-away-count"),
      ).toHaveText("1");
      await expect(
        owner.chat.page.getByTestId("nicklist-muted-count"),
      ).toHaveText("1");

      await shot(owner.chat.page, "nicklist-platform");
      await shot(owner.chat.nicklist, "nicklist-sidebar");
    } finally {
      await closeUsers([owner, operator, voiced, away, muted]);
    }
  });
});
