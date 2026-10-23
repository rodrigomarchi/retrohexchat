/**
 * @section V - Conversations, Tabs, Unread, Mute, And No-Focus-Steal Depth
 * @flow V1 [done] Conversation sidebar section collapse/expand state survives rerenders and does not affect active tab (features P2)
 * @flow V2 [done] Popular channel item joins/switches channel through browser UI without command typing (features P2)
 * @flow V3 [done] Browse all channels from conversations sidebar opens the channel list and preserves the previous filter search (features P2)
 * @flow V13 [done] A visitor's sidebar suggests by subject: a Games section opening with #retro-games and the game rooms, empty ones included, then News with the rooms in the reader's language first, then the popular channels about anything else — each row carrying only its language flag, on a desktop and on a phone
 * @flow V14 [done] "See more…" under a featured section opens the Channel List narrowed to that subject, said by a strip above the rooms; the Category list switches the subject, the strip's X shows every room again, and a member and a visitor get the same — on a desktop and on a phone
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { Browser, BrowserContext, Page, test, expect } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";
import { shot } from "../helpers/screenshots";
import { waitForView } from "../helpers/liveView";

const PHONE = { viewport: { width: 390, height: 844 }, hasTouch: true };

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  nick: string;
};

function uniqueChannel(prefix = "conv"): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = "conv", locale?: string) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open(locale ?? process.env.E2E_LOCALE);
  await connect.enterNickname(nick);
  await connect.registerWithPassword("pass12345");
  await chat.waitUntilConnected();

  return { chat, nick };
}

async function newSignedInUser(
  browser: Browser,
  prefix = "conv",
): Promise<TestUser> {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const { chat, nick } = await signedInUser(page, prefix);

  return { chat, ctx, nick };
}

async function closeUsers(users: TestUser[]) {
  await Promise.all(users.map((user) => user.ctx.close()));
}

// A news room somebody is in, in `locale`: the founder registers it and says
// what it is about and which language it speaks, and stays in it.
async function openNewsRoom(browser: Browser, locale: string, prefix: string) {
  const channel = uniqueChannel(prefix);
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const { chat, nick } = await signedInUser(page, "cnf");

  await chat.sendMessage(`/join ${channel}`);
  await chat.expectTabVisible(channel);
  await chat.sendMessage("/cs register");
  await chat.sendMessage(`/cs language ${locale}`);
  await chat.sendMessage("/cs category news");
  await expect(
    chat.channelConversationItem(channel).locator('[data-category="news"]'),
  ).toBeVisible();

  return { founder: { chat, ctx, nick } as TestUser, channel };
}

// The Games section opens with #retro-games and offers the game rooms,
// empty ones included. A fresh e2e database has none — production gets
// them from the provisioning script — so the test registers the feed and
// five rooms about games itself. The feed may already be registered (the
// provisioning spec registers it, with the games category) and is then left
// as it is.
async function openGameRooms(browser: Browser) {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const { chat, nick } = await signedInUser(page, "cng");
  const rooms = [
    "#retro-games",
    ...[1, 2, 3, 4, 5].map(() => uniqueChannel("gameroom")),
  ];

  for (const channel of rooms) {
    await chat.sendMessage(`/join ${channel}`);
    await chat.expectTabVisible(channel);
    await chat.sendMessage("/cs register");
    await chat.sendMessage("/cs category games");
    if (channel !== "#retro-games") {
      await expect(
        chat
          .channelConversationItem(channel)
          .locator('[data-category="games"]'),
      ).toBeVisible();
    }
  }

  return { founder: { chat, ctx, nick } as TestUser, rooms };
}

async function openAsVisitor(page: Page, path: string) {
  await page.addInitScript(() => {
    try {
      window.localStorage.setItem("retro_hex_chat_tips_suppressed", "true");
    } catch {
      /* localStorage unavailable — the tips only overlay, they do not block */
    }
  });
  await page.goto(path);
  await waitForView(page);
  await expect(page.getByTestId("visitor-composer")).toBeVisible();
}

function section(page: Page, category: string) {
  return page.getByTestId(`conversations-section-${category}`);
}

test.describe("Conversations sidebar", () => {
  test("section collapse survives unread rerender without changing active tab (V1)", async ({
    browser,
  }) => {
    const channelA = uniqueChannel("conva");
    const channelB = uniqueChannel("convb");
    const alice = await newSignedInUser(browser, "cva");
    const bob = await newSignedInUser(browser, "cvb");
    const unreadMessage = `collapsed-sidebar-unread-${Date.now()}`;

    try {
      await alice.chat.sendMessage(`/join ${channelA}`);
      await alice.chat.expectTabVisible(channelA);
      await alice.chat.sendMessage(`/join ${channelB}`);
      await alice.chat.expectTabVisible(channelB);

      await bob.chat.sendMessage(`/join ${channelA}`);
      await bob.chat.expectTabVisible(channelA);
      await bob.chat.sendMessage(`/join ${channelB}`);
      await bob.chat.expectTabVisible(channelB);

      await alice.chat.switchToTab(channelA);
      await alice.chat.expectTabSelected(channelA);
      await bob.chat.switchToTab(channelB);

      await alice.chat.expectConversationSectionExpanded("channels", true);
      await alice.chat.toggleConversationSection("channels");
      await alice.chat.expectConversationSectionExpanded("channels", false);
      await alice.chat.expectTabSelected(channelA);

      await bob.chat.sendMessage(unreadMessage);

      await alice.chat.expectConversationSectionExpanded("channels", false);
      await alice.chat.expectTabSelected(channelA);
      await alice.chat.expectMessageHidden(unreadMessage);

      await alice.chat.toggleConversationSection("channels");
      await alice.chat.expectConversationSectionExpanded("channels", true);
      await expect(alice.chat.channelConversationItem(channelA)).toBeVisible();
      await expect(alice.chat.channelConversationItem(channelB)).toBeVisible();
      await expect(alice.chat.channelUnreadBadge(channelB)).toBeVisible();
      await alice.chat.expectTabSelected(channelA);
    } finally {
      await closeUsers([alice, bob]);
    }
  });

  // Which channels are suggested — unjoined, public, busiest first, ten at most
  // — is decided by `ConversationsReadModel.popular_channels/2` and covered
  // against a known list in its own test. A channel invented here only ranks on
  // an empty server, so this drives whatever the sidebar is actually offering:
  // what the browser has to prove is that clicking one joins and switches.
  test("popular channel item joins and switches channel through the sidebar", async ({
    browser,
  }) => {
    const busyChannel = uniqueChannel("popular");
    const bob = await newSignedInUser(browser, "cpb");
    let alice: TestUser | undefined;

    try {
      await bob.chat.sendMessage(`/join ${busyChannel}`);
      await bob.chat.expectTabVisible(busyChannel);

      alice = await newSignedInUser(browser, "cpa");
      await alice.chat.expandConversationSection("popular");

      const firstSuggestion = alice.chat.conversationsSidebar
        .locator('[data-testid^="popular-"]')
        .first();
      await expect(firstSuggestion).toBeVisible();

      const popularChannel = (await firstSuggestion.getAttribute(
        "data-testid",
      ))!.replace(/^popular-/, "");
      await shot(alice.chat.page, "popular-channels-platform");
      await shot(alice.chat.conversationsSidebar, "popular-channels-sidebar");

      await alice.chat.joinPopularChannel(popularChannel);
      await expect(
        alice.chat.channelConversationItem(popularChannel),
      ).toBeVisible();
      await expect(alice.chat.popularChannelItem(popularChannel)).toHaveCount(
        0,
      );
    } finally {
      await closeUsers([bob, ...(alice ? [alice] : [])]);
    }
  });

  test("browse all channels from sidebar preserves channel list search pre-state (V3)", async ({
    browser,
  }) => {
    const homeChannel = uniqueChannel("home");
    const targetChannel = uniqueChannel("browse");
    const searchTerm = targetChannel.slice(1);
    const alice = await newSignedInUser(browser, "cba");
    const bob = await newSignedInUser(browser, "cbb");

    try {
      await bob.chat.sendMessage(`/join ${targetChannel}`);
      await bob.chat.expectTabVisible(targetChannel);

      await alice.chat.sendMessage(`/join ${homeChannel}`);
      await alice.chat.expectTabVisible(homeChannel);
      await alice.chat.expectTabSelected(homeChannel);

      await alice.chat.sendMessage("/list");
      await expect(alice.chat.channelListDialog).toBeVisible();
      await alice.chat.channelListSearch.fill(searchTerm);
      await expect(alice.chat.channelListRow(targetChannel)).toBeVisible();
      // Wait for the (debounced) filter to actually register server-side before
      // closing — the non-matching home channel must drop out of the list.
      await expect(alice.chat.channelListRow(homeChannel)).toBeHidden();

      await alice.chat.closeChannelList();
      await alice.chat.expectTabSelected(homeChannel);

      await alice.chat.browseAllChannelsFromConversations();
      await shot(alice.chat.channelListDialog, "browse-all-channels-dialog");
      await expect(alice.chat.channelListSearch).toHaveValue(searchTerm);
      await expect(alice.chat.channelListRow(targetChannel)).toBeVisible();

      await alice.chat.channelListRow(targetChannel).click();
      await alice.chat.expectTabVisible(targetChannel);
      await alice.chat.expectTabSelected(targetChannel);
    } finally {
      await closeUsers([alice, bob]);
    }
  });

  test("a visitor's sidebar suggests games, then news in their language, then the rest (V13)", async ({
    browser,
  }) => {
    const gameRooms = await openGameRooms(browser);
    const ours = await openNewsRoom(browser, "pt_BR", "jornal");
    const theirs = await openNewsRoom(browser, "ja", "shimbun");
    const visitorCtx = await browser.newContext();
    const visitor = await visitorCtx.newPage();
    const phoneCtx = await browser.newContext(PHONE);
    const phone = await phoneCtx.newPage();

    try {
      await openAsVisitor(visitor, "/pt-BR");

      // Games first, open, leading with the feed; a game's room is offered
      // whether or not anybody is in it.
      const games = section(visitor, "games");
      await expect(games).toBeVisible();
      await expect(
        games.locator(".chat-conversations-section__trigger"),
      ).toHaveAttribute("aria-expanded", "true");
      const gameRows = games.locator('[data-testid^="popular-"]');
      await expect(gameRows.first()).toHaveAttribute(
        "data-testid",
        "popular-#retro-games",
      );
      await expect(gameRows).toHaveCount(6);
      await expect(games.getByTestId("conversations-more-games")).toBeVisible();

      // The section says the subject; a row keeps only its language.
      await expect(
        games.locator(
          '.chat-conversations-section__trigger [data-category="games"]',
        ),
      ).toBeVisible();
      await expect(
        gameRows.locator('[data-testid="channel-category"]'),
      ).toHaveCount(0);

      // News: the reader's language ahead of a room in another one.
      const news = section(visitor, "news");
      await expect(news.getByTestId(`popular-${ours.channel}`)).toBeVisible();
      await expect(news.getByTestId(`popular-${theirs.channel}`)).toBeVisible();
      const newsNames = await news
        .locator('[data-testid^="popular-"]')
        .evaluateAll((rows) =>
          rows.map((row) => row.getAttribute("data-channel")),
        );
      expect(newsNames.indexOf(ours.channel)).toBeLessThan(
        newsNames.indexOf(theirs.channel),
      );

      // Below them, the popular channels about anything else — never a room
      // already offered above.
      const popular = section(visitor, "popular");
      await expect(popular).toBeVisible();
      await expect(popular.getByTestId(`popular-${ours.channel}`)).toHaveCount(
        0,
      );
      await expect(popular.getByTestId("popular-#retro-games")).toHaveCount(0);

      await shot(visitor, "visitor-sidebar-desktop");
      await shot(visitor.getByTestId("conversations"), "visitor-sidebar");

      // A row is a door here too: the visitor reads the room it names.
      await news.getByTestId(`popular-${ours.channel}`).click();
      await expect(visitor.getByTestId("tab-bar")).toContainText(ours.channel);

      // The same sections on a phone, in the drawer the toolbar opens.
      await openAsVisitor(phone, "/pt-BR");
      await phone.getByTestId("conversation-toolbar-conversations").click();
      await expect(section(phone, "games")).toBeVisible();
      await expect(
        section(phone, "games").getByTestId("popular-#retro-games"),
      ).toBeVisible();
      await shot(phone, "visitor-sidebar-phone");
      await section(phone, "news").scrollIntoViewIfNeeded();
      await shot(phone, "visitor-sidebar-phone-news");
    } finally {
      await visitorCtx.close();
      await phoneCtx.close();
      await closeUsers([ours.founder, theirs.founder, gameRooms.founder]);
    }
  });

  test("see more opens the Channel List on the section's subject (V14)", async ({
    browser,
  }) => {
    const gameRooms = await openGameRooms(browser);
    const room = await openNewsRoom(browser, "en", "headlines");
    const alice = await newSignedInUser(browser, "csm");
    const visitorCtx = await browser.newContext(PHONE);
    const visitor = await visitorCtx.newPage();
    const page = alice.chat.page;
    const panel = page.getByTestId("channel-list-panel");
    const strip = page.getByTestId("channel-list-category-strip");

    try {
      await section(page, "news")
        .getByTestId("conversations-more-news")
        .click();
      await expect(alice.chat.channelListDialog).toBeVisible();

      // Narrowed to news, and saying so above the rooms.
      await expect(strip).toBeVisible();
      await expect(strip.locator('[data-category="news"]')).toBeVisible();
      await expect(alice.chat.channelListRow(room.channel)).toBeVisible();
      await expect(alice.chat.channelListRow("#retro-games")).toHaveCount(0);
      await expect(
        panel.locator(
          '[data-testid^="channel-list-row-"] [data-testid="channel-category"]:not([data-category="news"])',
        ),
      ).toHaveCount(0);
      await shot(page, "channel-list-news-desktop");
      await shot(alice.chat.channelListDialog, "channel-list-news");

      // The Category list switches the subject.
      await page.locator(".cl-category-trigger").click();
      await shot(alice.chat.channelListDialog, "channel-list-category-open");
      // Every subject is reachable: the list scrolls inside the window
      // instead of losing its last rows under the window's edge.
      const last = page.getByTestId("channel-list-category-help");
      await last.scrollIntoViewIfNeeded();
      await expect(last).toBeInViewport();
      await shot(
        alice.chat.channelListDialog,
        "channel-list-category-scrolled",
      );
      await page.getByTestId("channel-list-category-games").click();
      await expect(alice.chat.channelListRow("#retro-games")).toBeVisible();
      await expect(alice.chat.channelListRow(room.channel)).toHaveCount(0);
      await expect(strip.locator('[data-category="games"]')).toBeVisible();
      await shot(alice.chat.channelListDialog, "channel-list-games");

      // The strip's X shows every room again.
      await page.getByTestId("channel-list-category-clear").click();
      await expect(strip).toHaveCount(0);
      await expect(alice.chat.channelListRow("#retro-games")).toBeVisible();
      await expect(alice.chat.channelListRow(room.channel)).toBeVisible();

      // A visitor on a phone gets the same window, the same way.
      await openAsVisitor(visitor, "/");
      await visitor.getByTestId("conversation-toolbar-conversations").click();
      await section(visitor, "games")
        .getByTestId("conversations-more-games")
        .click();
      const visitorStrip = visitor.getByTestId("channel-list-category-strip");
      await expect(
        visitorStrip.locator('[data-category="games"]'),
      ).toBeVisible();
      await expect(
        visitor.getByTestId("channel-list-row-#retro-games"),
      ).toBeVisible();
      await shot(visitor, "channel-list-games-phone");
    } finally {
      await visitorCtx.close();
      await closeUsers([alice, room.founder, gameRooms.founder]);
    }
  });
});
