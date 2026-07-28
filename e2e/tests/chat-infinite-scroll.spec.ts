import { expect, test } from "@playwright/test";
import {
  closeUsers,
  newSignedInUser,
  type TestUser,
  uniqueChannel,
} from "../helpers/chatUsers";
import { ChatPage } from "../pages/ChatPage";
import { shot } from "../helpers/screenshots";

/**
 * Scrollback pagination, through the real gesture.
 *
 * The server hands the chat one page of 50 messages and a cursor; the rest
 * arrives as the reader scrolls back. Three properties matter enough to hold a
 * browser open for:
 *
 *  1. Older messages arrive, and the reader's place does not move when they do.
 *  2. A message hidden by the ignore list does not end pagination — `has_more`
 *     comes from the database, before any presentation filter runs. This is the
 *     bug the pagination contract was built to make inexpressible.
 *  3. The top of a fully-loaded history is marked, so it cannot be mistaken for
 *     a page that never arrived.
 *
 * Seeding is done by one nick talking to itself on purpose: flood protection
 * exempts your own messages, so a single user can fill a channel at speed
 * without auto-ignoring themselves halfway through.
 */

const PAGE_SIZE = 50;
const SEEDED = PAGE_SIZE + 8;

function seedText(marker: number, index: number): string {
  return `scrollback-${marker}-${String(index).padStart(3, "0")}`;
}

/** Fills a channel past one page, from the caller's own nick. */
async function seedHistory(chat: ChatPage, marker: number, count: number) {
  for (let index = 1; index <= count; index += 1) {
    await chat.sendMessage(seedText(marker, index));
  }

  await chat.expectMessageVisible(seedText(marker, count), 20_000);
}

/**
 * Reloads so the channel loads its history from the database.
 *
 * Without this the messages just sent are already in the stream and there is
 * nothing to paginate — the first page has to come back from the server for
 * `has_more` and the cursor to mean anything.
 */
async function reopenChannel(user: TestUser, channel: string) {
  await user.page.reload();
  await user.chat.waitUntilConnected();

  const restored = await user.chat
    .tab(channel)
    .isVisible()
    .catch(() => false);

  if (!restored) {
    await user.chat.sendMessage(`/join ${channel}`);
  }

  await user.chat.expectTabVisible(channel);
  await user.chat.switchToTab(channel);
  await waitForSettledHistory(user.chat);
}

/**
 * Waits out the reconnect restore before touching the scrollback.
 *
 * A reload starts a rejoin walk — one channel every 100ms — and when it reaches
 * the end it restores the active tab by reloading that channel's first page,
 * which resets the message stream. Paginate inside that window and the older
 * page is fetched, rendered, and then wiped by the restore a moment later. The
 * list is stable once two readings a beat apart agree.
 */
async function waitForSettledHistory(chat: ChatPage) {
  let previous = "";

  await expect
    .poll(
      async () => {
        const current = await chat.messageList.evaluate((el) => {
          const rows = el.querySelectorAll("[data-message-id]");
          return `${rows.length}:${rows[0]?.id ?? ""}`;
        });
        const stable = current !== "" && current === previous;
        previous = current;
        return stable;
      },
      { timeout: 30_000, intervals: [600] },
    )
    .toBe(true);
}

async function scrollMetrics(chat: ChatPage) {
  return chat.messageList.evaluate((el) => ({
    scrollTop: Math.round(el.scrollTop),
    scrollHeight: Math.round(el.scrollHeight),
  }));
}

test.describe("Chat infinite scroll", () => {
  test("loads older messages on scroll back, keeps the reader's place, and marks the top", async ({
    browser,
  }) => {
    test.setTimeout(180_000);

    const alice = await newSignedInUser(browser, "infa");
    const channel = uniqueChannel("infs");
    const marker = Date.now();

    try {
      await alice.chat.sendMessage(`/join ${channel}`);
      await alice.chat.expectTabVisible(channel);
      await alice.chat.switchToTab(channel);

      await seedHistory(alice.chat, marker, SEEDED);
      await reopenChannel(alice, channel);

      // The first page is the newest 50, so the oldest seeded messages are not
      // in the document at all — not merely scrolled out of view.
      await alice.chat.expectMessageVisible(seedText(marker, SEEDED), 20_000);
      await expect(
        alice.chat.messageRows.filter({ hasText: seedText(marker, 1) }),
      ).toHaveCount(0);

      // Nothing has been loaded past the first page, so the top is still open.
      await expect(alice.page.getByTestId("chat-history-end")).toHaveCount(0);
      await shot(alice.page, "first-page-loaded");

      const oldestBefore = await alice.chat.messageRows
        .first()
        .getAttribute("id");
      const before = await scrollMetrics(alice.chat);

      await alice.chat.scrollMessagesToTop();

      await expect(
        alice.chat.messageRowByText(seedText(marker, 1)),
      ).toBeVisible({ timeout: 20_000 });

      // Wait for the rows to be laid out, not merely present: a row is visible
      // to Playwright before the viewport has reflowed around it, and reading
      // scrollHeight in that window reports the height it had beforehand.
      await expect
        .poll(async () => (await scrollMetrics(alice.chat)).scrollHeight, {
          timeout: 20_000,
        })
        .toBeGreaterThan(before.scrollHeight);

      const after = await scrollMetrics(alice.chat);
      const grew = after.scrollHeight - before.scrollHeight;

      // Keeping the reader's place *is* this: the viewport was scrolled to the
      // top, so preserving what they were looking at means scrollTop moved down
      // by exactly the height that appeared above it. Anything less and the
      // content they were reading jumps away under them.
      expect(Math.abs(after.scrollTop - grew)).toBeLessThanOrEqual(4);

      // Everything is loaded now, so the scrollback closes with a marker rather
      // than leaving the reader waiting at the edge.
      await expect(alice.page.getByTestId("chat-history-end")).toBeVisible({
        timeout: 20_000,
      });
      // Framed as the whole page: the marker is a sibling above the scrolling
      // list, so cropping to the list would cut off the very thing being shown.
      await shot(alice.page, "history-end-marker");
    } finally {
      await closeUsers([alice] satisfies TestUser[]);
    }
  });

  test("keeps paginating when the first page is hidden by the ignore list", async ({
    browser,
  }) => {
    test.setTimeout(180_000);

    const alice = await newSignedInUser(browser, "infi");
    const bob = await newSignedInUser(browser, "infb");
    const channel = uniqueChannel("infg");
    const marker = Date.now();

    try {
      await alice.chat.sendMessage(`/join ${channel}`);
      await alice.chat.expectTabVisible(channel);
      await alice.chat.switchToTab(channel);

      await seedHistory(alice.chat, marker, SEEDED);

      // Bob's messages are the newest, so they fill the top of the first page.
      await bob.chat.sendMessage(`/join ${channel}`);
      await bob.chat.expectTabVisible(channel);
      await bob.chat.switchToTab(channel);

      const noisy = `scrollback-noise-${marker}`;
      await bob.chat.sendMessage(noisy);
      await alice.chat.expectMessageVisible(noisy, 20_000);

      await alice.chat.sendMessage(`/ignore ${bob.nick}`);
      await reopenChannel(alice, channel);

      // Bob's message is on the first page the database returned and is filtered
      // out before rendering. If that filter reached `has_more`, the scrollback
      // would be dead from here on.
      await expect(
        alice.chat.messageRows.filter({ hasText: noisy }),
      ).toHaveCount(0);
      await expect(alice.page.getByTestId("chat-history-end")).toHaveCount(0);

      await alice.chat.scrollMessagesToTop();

      await expect(
        alice.chat.messageRowByText(seedText(marker, 1)),
      ).toBeVisible({ timeout: 20_000 });
      await shot(alice.page, "paginated-past-ignored-author");
    } finally {
      await closeUsers([alice, bob] satisfies TestUser[]);
    }
  });
});
