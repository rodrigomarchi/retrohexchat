/**
 * @section X - Channel Modes, Services, Permissions, Persistence Edges
 * @flow X6 [done] ChanServ registered channel access survives an empty channel and later founder/member rejoins (features P1)
 * @flow X16 [done] a registered channel keeps its topic and modes while empty; an unregistered one forgets them
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { Browser, BrowserContext, Page, expect, test } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = "cspersist"): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = "cspersist") {
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
  prefix = "cspersist",
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const { chat, nick } = await signedInUser(page, prefix);

  return { chat, ctx, nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

test.describe("ChanServ persistence", () => {
  test("registered channel access survives empty channel and later rejoin (X6)", async ({
    browser,
  }) => {
    const founder = await newSignedInUser(browser, "x6found");
    const aop = await newSignedInUser(browser, "x6aop");
    const channel = uniqueChannel("x6cs");

    try {
      await founder.chat.sendMessage(`/join ${channel}`);
      await founder.chat.expectTabVisible(channel);

      await founder.chat.sendMessage("/cs register");
      await founder.chat.expectMessageVisible(
        `[ChanServ] Channel ${channel} registered by ${founder.nick}`,
      );

      await founder.chat.sendMessage(`/cs aop add ${aop.nick}`);
      await founder.chat.expectMessageVisible(
        `[ChanServ] ${aop.nick} added to aop list of ${channel}`,
      );

      await founder.chat.sendMessage(`/part ${channel}`);
      await founder.chat.expectTabHidden(channel);

      await aop.chat.sendMessage(`/join ${channel}`);
      await aop.chat.expectTabVisible(channel);
      await aop.chat.expectNickRole(aop.nick, "operator");

      await aop.chat.sendMessage(`/part ${channel}`);
      await aop.chat.expectTabHidden(channel);

      await founder.chat.sendMessage(`/join ${channel}`);
      await founder.chat.expectTabVisible(channel);
      await founder.chat.expectNickRole(founder.nick, "owner");

      await founder.chat.sendMessage("/cs info");
      await founder.chat.expectMessageVisible(
        `[ChanServ] ${channel}: founder=${founder.nick}`,
      );
    } finally {
      await closeUsers([founder, aop]);
    }
  });

  test("a registered channel keeps its topic and modes while empty, an unregistered one does not (X16)", async ({
    browser,
  }) => {
    const founder = await newSignedInUser(browser, "x16found");
    const visitor = await newSignedInUser(browser, "x16visit");
    const registered = uniqueChannel("x16reg");
    const unregistered = uniqueChannel("x16tmp");
    const topic = `kept-${Date.now()}`;
    const lostTopic = `lost-${Date.now()}`;

    try {
      await founder.chat.sendMessage(`/join ${registered}`);
      await founder.chat.expectTabVisible(registered);
      await founder.chat.sendMessage("/cs register");
      await founder.chat.expectMessageVisible(
        `[ChanServ] Channel ${registered} registered by ${founder.nick}`,
      );
      await founder.chat.sendMessage(`/topic ${topic}`);
      await expect(founder.chat.topicBar).toContainText(topic);
      await founder.chat.sendMessage("/mode +m");
      await founder.chat.expectMessageVisible(`${founder.nick} sets mode +m`);
      await founder.chat.sendMessage(`/part ${registered}`);
      await founder.chat.expectTabHidden(registered);

      // Nobody is inside now. The next person in finds the room as it was left.
      await visitor.chat.sendMessage(`/join ${registered}`);
      await visitor.chat.expectTabVisible(registered);
      await expect(visitor.chat.topicBar).toContainText(topic);
      await expect(visitor.chat.topicBar).toContainText("+m");

      await founder.chat.sendMessage(`/join ${unregistered}`);
      await founder.chat.expectTabVisible(unregistered);
      await founder.chat.sendMessage(`/topic ${lostTopic}`);
      await expect(founder.chat.topicBar).toContainText(lostTopic);
      await founder.chat.sendMessage(`/part ${unregistered}`);
      await founder.chat.expectTabHidden(unregistered);

      // The unregistered room closed with its last member: this join founds a
      // new one, and the visitor owns it.
      await visitor.chat.sendMessage(`/join ${unregistered}`);
      await visitor.chat.expectTabVisible(unregistered);
      await expect(visitor.chat.topicBar).toContainText("No topic set");
      await visitor.chat.expectNickRole(visitor.nick, "owner");
    } finally {
      await closeUsers([founder, visitor]);
    }
  });
});
