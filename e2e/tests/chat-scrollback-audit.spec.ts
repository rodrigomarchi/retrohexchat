/**
 * @section P - Persistence, Reconnect, History, No-Focus-Steal
 * @flow P10d [done] A 1000-message channel walks back to its first message: every window consecutive, no page fetched and dropped (features P1)
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { expect, test } from "@playwright/test";
import {
  closeUsers,
  newSignedInUser,
  type TestUser,
} from "../helpers/chatUsers";
import { isLocalTarget, localOnlyReason } from "../helpers/env";
import { seedChannelHistory, seedPrivateHistory } from "../helpers/seedHistory";
import { shot } from "../helpers/screenshots";
import type { ChatPage } from "../pages/ChatPage";

/**
 * The scrollback, walked end to end over a history no reader could type.
 *
 * `chat-infinite-scroll.spec.ts` proves the first page boundary: one page
 * arrives, the reader's place holds. That is one hop. This spec asks the
 * question a reader actually asks of a long channel — can I get back to the
 * beginning, and is what I read on the way the truth? — over 1000 numbered
 * messages, checking after every hop that the rows on screen are consecutive,
 * in order, and that the window has genuinely moved older.
 */

const CHANNEL = "#audit1k";
const SEEDED = 1000;
const PM_SEEDED = 300;
const MAX_ROUNDS = 40;

type Snapshot = {
  rows: number;
  oldest: number | null;
  newest: number | null;
  gaps: number[];
  duplicates: number[];
  outOfOrder: boolean;
  scrollTop: number;
  scrollHeight: number;
};

/**
 * The message numbers on screen, in DOM order, plus the scroll geometry.
 *
 * Reading the numbers out of the rows rather than counting them is the point:
 * a count says "50 rows arrived", the numbers say *which* 50, which is the
 * only way a skipped or repeated page shows up at all.
 */
async function snapshot(chat: ChatPage): Promise<Snapshot> {
  return chat.messageList.evaluate((el) => {
    const numbers = Array.from(el.querySelectorAll("[data-message-id]"))
      .map((row) => row.textContent?.match(/msg-(\d{4})/)?.[1])
      .filter((value): value is string => !!value)
      .map(Number);

    const gaps: number[] = [];
    const duplicates: number[] = [];
    let outOfOrder = false;

    for (let i = 1; i < numbers.length; i += 1) {
      const step = numbers[i] - numbers[i - 1];
      if (step === 0) duplicates.push(numbers[i]);
      else if (step < 0) outOfOrder = true;
      else if (step > 1) {
        for (
          let missing = numbers[i - 1] + 1;
          missing < numbers[i];
          missing += 1
        ) {
          gaps.push(missing);
        }
      }
    }

    return {
      rows: numbers.length,
      oldest: numbers.length ? numbers[0] : null,
      newest: numbers.length ? numbers[numbers.length - 1] : null,
      gaps,
      duplicates,
      outOfOrder,
      scrollTop: Math.round(el.scrollTop),
      scrollHeight: Math.round(el.scrollHeight),
    };
  });
}

/** Waits until two readings a beat apart agree, so a snapshot is not mid-patch. */
async function settle(chat: ChatPage) {
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
      { timeout: 30_000, intervals: [400] },
    )
    .toBe(true);
}

test.describe("Chat scrollback over a long history", () => {
  // The history is written straight into the database by `mix run`, which reaches
  // the local one whatever the browser is pointed at. Against a deployment the
  // rows land somewhere nobody is reading and `msg-1000` never arrives.
  test.skip(
    !isLocalTarget(),
    localOnlyReason(
      "the 1000-message history is seeded into the local database",
    ),
  );

  test("walks a thousand messages back to the first one", async ({
    browser,
  }) => {
    test.setTimeout(420_000);

    seedChannelHistory(CHANNEL, SEEDED);

    const alice = await newSignedInUser(browser, "scrl");

    try {
      await alice.chat.sendMessage(`/join ${CHANNEL}`);
      await alice.chat.expectTabVisible(CHANNEL);
      await alice.chat.switchToTab(CHANNEL);
      await alice.chat.expectMessageVisible("msg-1000", 30_000);
      await settle(alice.chat);

      const journey: Array<Snapshot & { round: number; moved: boolean }> = [];
      const first = await snapshot(alice.chat);
      journey.push({ ...first, round: 0, moved: true });

      await shot(alice.page, "first-page-newest-1000");

      let stalls = 0;

      for (let round = 1; round <= MAX_ROUNDS; round += 1) {
        const before = await snapshot(alice.chat);
        if (before.oldest === 1) break;

        await alice.chat.scrollMessagesToTop();

        const moved = await alice.chat.messageList
          .evaluate(
            (el, previousOldest) =>
              new Promise<boolean>((resolve) => {
                const read = () => {
                  const row = el.querySelector("[data-message-id]");
                  const match = row?.textContent?.match(/msg-(\d{4})/);
                  return match ? Number(match[1]) : null;
                };
                if (read() !== previousOldest) return resolve(true);

                const observer = new MutationObserver(() => {
                  if (read() !== previousOldest) {
                    observer.disconnect();
                    clearTimeout(timer);
                    resolve(true);
                  }
                });
                observer.observe(el, { childList: true, subtree: true });
                const timer = setTimeout(() => {
                  observer.disconnect();
                  resolve(false);
                }, 6_000);
              }),
            before.oldest,
          )
          .catch(() => false);

        const after = await snapshot(alice.chat);
        journey.push({ ...after, round, moved });

        if (!moved || after.oldest === before.oldest) {
          stalls += 1;
          if (stalls >= 3) break;
        } else {
          stalls = 0;
        }

        if (round === 1) await shot(alice.page, "after-first-page-back");
      }

      const trace = journey
        .map(
          (step) =>
            `round ${String(step.round).padStart(2)}  rows=${String(step.rows).padStart(3)}  ` +
            `window=${step.oldest}..${step.newest}  moved=${step.moved}  ` +
            `gaps=${step.gaps.length}  dups=${step.duplicates.length}  ` +
            `outOfOrder=${step.outOfOrder}  scrollTop=${step.scrollTop}/${step.scrollHeight}`,
        )
        .join("\n");

      // eslint-disable-next-line no-console
      console.log(`\nScrollback journey over ${SEEDED} messages:\n${trace}\n`);
      await test.info().attach("scrollback-journey", {
        body: trace,
        contentType: "text/plain",
      });

      await shot(alice.page, "final-window");

      const broken = journey.filter(
        (step) =>
          step.gaps.length > 0 || step.duplicates.length > 0 || step.outOfOrder,
      );
      expect(
        broken,
        "every window on screen must be consecutive, ascending and free of repeats",
      ).toEqual([]);

      const last = journey[journey.length - 1];
      expect(
        last.oldest,
        `scrolling back stopped at msg-${last.oldest} instead of reaching msg-0001`,
      ).toBe(1);
    } finally {
      await closeUsers([alice] satisfies TestUser[]);
    }
  });

  test("keeps the pages it fetches instead of spending them", async ({
    browser,
  }) => {
    test.setTimeout(300_000);

    seedChannelHistory(CHANNEL, SEEDED);

    const alice = await newSignedInUser(browser, "scrp");

    try {
      await alice.chat.sendMessage(`/join ${CHANNEL}`);
      await alice.chat.expectTabVisible(CHANNEL);
      await alice.chat.switchToTab(CHANNEL);
      await alice.chat.expectMessageVisible("msg-1000", 30_000);
      await settle(alice.chat);

      // Watch what the patch actually does to the list, not what it leaves
      // behind. A page that is inserted and removed inside the same patch is
      // invisible to any assertion made afterwards — and it is still gone from
      // the server's cursor, so the reader can never ask for it again.
      await alice.chat.messageList.evaluate((el) => {
        const record = { added: [] as number[], removed: [] as number[] };
        (
          window as unknown as { __scrollbackAudit: typeof record }
        ).__scrollbackAudit = record;

        const numberOf = (node: Node): number | null => {
          if (node.nodeType !== Node.ELEMENT_NODE) return null;
          const match = (node as Element).textContent?.match(/msg-(\d{4})/);
          return match ? Number(match[1]) : null;
        };

        new MutationObserver((mutations) => {
          for (const mutation of mutations) {
            mutation.addedNodes.forEach((node) => {
              const n = numberOf(node);
              if (n !== null) record.added.push(n);
            });
            mutation.removedNodes.forEach((node) => {
              const n = numberOf(node);
              if (n !== null) record.removed.push(n);
            });
          }
        }).observe(el, { childList: true });
      });

      for (let round = 0; round < 8; round += 1) {
        await alice.chat.scrollMessagesToTop();
        await alice.page.waitForTimeout(1_200);
      }

      const record = await alice.page.evaluate(
        () =>
          (
            window as unknown as {
              __scrollbackAudit: { added: number[]; removed: number[] };
            }
          ).__scrollbackAudit,
      );

      const onScreen = (await snapshot(alice.chat)).oldest ?? 0;
      const spent = record.added
        .filter((n) => record.removed.includes(n))
        .filter((n) => n < onScreen)
        .sort((a, b) => a - b);

      const summary =
        `oldest on screen: msg-${onScreen}\n` +
        `rows inserted:    ${record.added.length}\n` +
        `rows removed:     ${record.removed.length}\n` +
        `fetched then dropped, and older than anything on screen: ${spent.length}` +
        (spent.length
          ? ` (msg-${spent[0]} … msg-${spent[spent.length - 1]})`
          : "");

      // eslint-disable-next-line no-console
      console.log(`\n${summary}\n`);
      await test
        .info()
        .attach("spent-pages", { body: summary, contentType: "text/plain" });

      expect(
        spent,
        "a page fetched from the database must reach the reader, not be dropped in the same patch that inserted it",
      ).toEqual([]);
    } finally {
      await closeUsers([alice] satisfies TestUser[]);
    }
  });

  // A DM is the same viewport over a different query. Worth its own walk
  // because the conversation is a pair of nicks in either order, so a cursor
  // that works for a channel is not evidence that this one does.
  test("walks a private conversation back to its first message", async ({
    browser,
  }) => {
    test.setTimeout(300_000);

    const alice = await newSignedInUser(browser, "scrd");
    const bob = await newSignedInUser(browser, "scre");

    try {
      seedPrivateHistory(alice.nick, bob.nick, PM_SEEDED);

      await alice.chat.sendMessage(`/query ${bob.nick}`);
      await alice.chat.expectTabVisible(bob.nick);
      await alice.chat.switchToTab(bob.nick);
      await alice.chat.expectMessageVisible("msg-0300", 30_000);
      await settle(alice.chat);

      let last = await snapshot(alice.chat);

      for (
        let round = 1;
        round <= MAX_ROUNDS && last.oldest !== 1;
        round += 1
      ) {
        await alice.chat.scrollMessagesToTop();
        await alice.page.waitForTimeout(800);

        const next = await snapshot(alice.chat);
        expect(
          next.gaps,
          `round ${round} left holes in the conversation`,
        ).toEqual([]);
        expect(next.duplicates, `round ${round} repeated a message`).toEqual(
          [],
        );
        expect(
          next.outOfOrder,
          `round ${round} put the conversation out of order`,
        ).toBe(false);

        if (next.oldest === last.oldest) break;
        last = next;
      }

      await shot(alice.page, "dm-scrollback-beginning");

      expect(
        last.oldest,
        `the DM scrollback stopped at msg-${last.oldest} instead of reaching msg-0001`,
      ).toBe(1);
    } finally {
      await closeUsers([alice, bob] satisfies TestUser[]);
    }
  });
});
