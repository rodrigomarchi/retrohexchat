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
 * The reader's place in the scrollback, held through the things that used to
 * take it away.
 *
 * Both failures this covers were invisible to the rest of the suite because the
 * suite scrolls by writing `scrollTop` directly. The bug lived in what LiveView
 * does to an element that pushes an event: it stamps `data-phx-ref-lock` on it
 * and applies every patch arriving during the round trip to a *detached clone*,
 * then swaps the clone back. While the hook that asked for older messages sat
 * on the scrolling element, fetching a page destroyed the position it was
 * fetching for, and the swap-back reached the DOM as a wholesale
 * add-and-remove that the hook read as "the list was reset" and answered by
 * jumping to the newest message.
 *
 * So this drives the real gesture and asserts on where the reader ends up.
 */

const SEEDED = 120;
const WHEEL_PX = 200;

type ScrollbackMetrics = {
  scrollTop: number;
  scrollHeight: number;
  clientHeight: number;
  bottomGap: number;
  rows: number;
};

function seedText(marker: number, index: number): string {
  return `place-${marker}-${String(index).padStart(3, "0")}`;
}

async function seedHistory(chat: ChatPage, marker: number, count: number) {
  for (let index = 1; index <= count; index += 1) {
    await chat.sendMessage(seedText(marker, index));
  }
  await chat.expectMessageVisible(seedText(marker, count), 30_000);
}

async function metrics(chat: ChatPage): Promise<ScrollbackMetrics> {
  return chat.messageList.evaluate((el) => ({
    scrollTop: Math.round(el.scrollTop),
    scrollHeight: Math.round(el.scrollHeight),
    clientHeight: Math.round(el.clientHeight),
    bottomGap: Math.round(el.scrollHeight - el.scrollTop - el.clientHeight),
    rows: el.querySelectorAll("[data-message-id]").length,
  }));
}

/** Scrolls with a real wheel over the list, the way a reader does. */
async function wheelUp(chat: ChatPage, notches: number) {
  const box = await chat.messageList.boundingBox();
  expect(box).not.toBeNull();
  await chat.page.mouse.move(box!.x + box!.width / 2, box!.y + box!.height / 2);

  for (let i = 0; i < notches; i += 1) {
    await chat.page.mouse.wheel(0, -WHEEL_PX);
    await chat.page.waitForTimeout(120);
  }
}

test.describe("Chat scrollback position", () => {
  test("paging back leaves the reader where they were reading", async ({
    browser,
  }) => {
    test.setTimeout(300_000);

    const alice = await newSignedInUser(browser, "plca");
    const channel = uniqueChannel("plc");
    const marker = Date.now();

    try {
      await alice.chat.sendMessage(`/join ${channel}`);
      await alice.chat.expectTabVisible(channel);
      await alice.chat.switchToTab(channel);
      await seedHistory(alice.chat, marker, SEEDED);

      // Reload so the channel loads one page from the database and the rest has
      // to be paginated — otherwise everything is already in the stream.
      await alice.page.reload();
      await alice.chat.waitUntilConnected();
      await alice.chat.expectTabVisible(channel);
      await alice.chat.switchToTab(channel);
      await expect
        .poll(async () => (await metrics(alice.chat)).rows, { timeout: 30_000 })
        .toBeGreaterThan(10);
      await alice.page.waitForTimeout(3_000);

      const firstPage = await metrics(alice.chat);
      expect(firstPage.bottomGap).toBeLessThanOrEqual(4);

      await shot(alice.page, "first-page-pinned");

      // Distance from the end of the list is the thing to watch, because it is
      // the one quantity a page landing above the reader must not change: the
      // rows and the offset both grow by the height that arrived. So across a
      // scroll-back it only ever goes up, by roughly what the wheel asked for.
      // A jump to the newest message collapses it; a jump to the top of the
      // history makes it leap. Sampling per notch catches either, wherever in
      // the gesture the page happens to land.
      const box = await alice.chat.messageList.boundingBox();
      expect(box).not.toBeNull();
      await alice.page.mouse.move(
        box!.x + box!.width / 2,
        box!.y + box!.height / 2,
      );

      const samples: ScrollbackMetrics[] = [];
      for (let notch = 0; notch < 14; notch += 1) {
        await alice.page.mouse.wheel(0, -WHEEL_PX);
        await alice.page.waitForTimeout(250);
        samples.push(await metrics(alice.chat));
      }

      await shot(alice.page, "after-older-page");

      const last = samples.at(-1)!;
      expect(last.rows).toBeGreaterThan(firstPage.rows);
      expect(last.bottomGap).toBeGreaterThan(WHEEL_PX);

      samples.forEach((sample, index) => {
        const previous = index === 0 ? firstPage : samples[index - 1];
        const moved = sample.bottomGap - previous.bottomGap;

        expect(
          moved,
          `notch ${index} moved the reader towards the newest message`,
        ).toBeGreaterThanOrEqual(-4);

        expect(
          moved,
          `notch ${index} threw the reader ${moved}px, far past the wheel`,
        ).toBeLessThanOrEqual(WHEEL_PX * 3);
      });
    } finally {
      await closeUsers([alice] satisfies TestUser[]);
    }
  });

  test("a message arriving while reading history does not move the reader", async ({
    browser,
  }) => {
    test.setTimeout(300_000);

    const alice = await newSignedInUser(browser, "plma");
    const bob = await newSignedInUser(browser, "plmb");
    const channel = uniqueChannel("plm");
    const marker = Date.now();

    try {
      for (const user of [alice, bob]) {
        await user.chat.sendMessage(`/join ${channel}`);
        await user.chat.expectTabVisible(channel);
        await user.chat.switchToTab(channel);
      }

      await seedHistory(alice.chat, marker, 60);
      await alice.page.waitForTimeout(2_000);

      await wheelUp(alice.chat, 4);
      const before = await metrics(alice.chat);
      expect(before.bottomGap).toBeGreaterThan(50);

      const incoming = `place-incoming-${marker}`;
      await bob.chat.sendMessage(incoming);
      await expect(alice.chat.messageRowByText(incoming)).toContainText(
        incoming,
        { timeout: 20_000 },
      );
      await alice.page.waitForTimeout(1_500);

      const after = await metrics(alice.chat);
      const grew = after.scrollHeight - before.scrollHeight;

      // The line landed below them, so their offset must not have changed.
      expect(after.scrollTop).toBe(before.scrollTop);
      expect(after.bottomGap).toBeGreaterThanOrEqual(
        before.bottomGap + grew - 4,
      );
    } finally {
      await closeUsers([alice, bob] satisfies TestUser[]);
    }
  });

  test("stays on the newest message while the reader is at the end", async ({
    browser,
  }) => {
    test.setTimeout(180_000);

    const alice = await newSignedInUser(browser, "plpa");
    const bob = await newSignedInUser(browser, "plpb");
    const channel = uniqueChannel("plp");
    const marker = Date.now();

    try {
      for (const user of [alice, bob]) {
        await user.chat.sendMessage(`/join ${channel}`);
        await user.chat.expectTabVisible(channel);
        await user.chat.switchToTab(channel);
      }

      await seedHistory(alice.chat, marker, 40);
      await expect
        .poll(async () => (await metrics(alice.chat)).bottomGap)
        .toBeLessThanOrEqual(4);

      for (let i = 1; i <= 3; i += 1) {
        const line = `place-live-${marker}-${i}`;
        await bob.chat.sendMessage(line);
        await alice.chat.expectMessageVisible(line, 20_000);
        await expect
          .poll(async () => (await metrics(alice.chat)).bottomGap)
          .toBeLessThanOrEqual(4);
      }
    } finally {
      await closeUsers([alice, bob] satisfies TestUser[]);
    }
  });
});
