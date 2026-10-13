/**
 * @section SP - Virtual Spaces
 * @flow SP15 [done] Four sword hits knock a character out for everyone in the space, and a few seconds later they get back up on their own
 * @flow SP16 [done] A space's card in the channel shows the gathering live, counts the people in it, and becomes its record once everybody has left
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect, Page } from "@playwright/test";
import {
  newSignedInUser,
  closeUsers,
  uniqueChannel,
  TestUser,
} from "../helpers/chatUsers";
import { enterAs, Look } from "../helpers/characters";

// The loading veil is only there once the map is: waiting for it to be hidden
// before the map exists passes at once, and the next step would close a tab
// that never joined.
async function walkIn(space: Page, avatar: Look | string) {
  await enterAs(space, avatar);
  await expect(space.getByTestId("channel-space-shell")).toBeVisible({
    timeout: 15_000,
  });
  await expect(space.getByTestId("space-loading")).toBeHidden({
    timeout: 15_000,
  });
}

// One tile per press: the first keydown of a key is one step, and the next
// press waits out the server's step cadence.
async function step(space: Page, key: string, times = 1) {
  for (let i = 0; i < times; i++) {
    await space.keyboard.press(key);
    await space.waitForTimeout(260);
  }
}

// A private space for two: the first in stands on the map's first spawn
// point, by the lamp, and the second on the one four tiles to its right.
async function privateSpaceForTwo(alice: TestUser, bob: TestUser) {
  await alice.chat.sendMessage(`/msg ${bob.nick} sparring?`);
  await alice.page.getByTestId(`pm-${bob.nick}`).click();
  const aliceSpace = await alice.chat.openSpace();
  await walkIn(aliceSpace, "ranger");

  const bobSpace = await bob.ctx.newPage();
  await bobSpace.goto(aliceSpace.url());
  await walkIn(bobSpace, "sailor");
  return { aliceSpace, bobSpace };
}

test.describe("A gathering in a space", () => {
  test("four hits knock somebody out, and they get back up (SP15)", async ({
    browser,
  }) => {
    test.setTimeout(90_000);
    const alice = await newSignedInUser(browser, "sda");
    const bob = await newSignedInUser(browser, "sdb");
    try {
      const { aliceSpace, bobSpace } = await privateSpaceForTwo(alice, bob);

      // Bob walks round the lamp to stand diagonally beside Alice.
      await step(bobSpace, "ArrowDown");
      await step(bobSpace, "ArrowLeft", 3);

      // Four swings, each waiting out the sword's cooldown.
      for (let i = 0; i < 4; i++) {
        await bobSpace.keyboard.press(" ");
        await bobSpace.waitForTimeout(400);
      }

      for (const space of [aliceSpace, bobSpace]) {
        await expect(space.getByTestId("space-said")).toHaveText(
          `${alice.nick} is knocked out!`,
          { timeout: 10_000 },
        );
      }

      // A knockout has no lasting effect: she is up again by herself.
      await expect(aliceSpace.getByTestId("space-said")).toHaveText(
        `${alice.nick} is back on their feet.`,
        { timeout: 15_000 },
      );
    } finally {
      await closeUsers([alice, bob]);
    }
  });

  test("the card shows the gathering live and keeps its record (SP16)", async ({
    browser,
  }) => {
    test.setTimeout(90_000);
    const host = await newSignedInUser(browser, "sgh");
    const guest = await newSignedInUser(browser, "sgg");
    try {
      const channel = uniqueChannel("sgc");
      await host.chat.sendMessage(`/join ${channel}`);
      await guest.chat.sendMessage(`/join ${channel}`);
      await guest.chat.expectTabVisible(channel);

      const hostSpace = await host.chat.openSpace();
      await walkIn(hostSpace, "monk");

      // Walking into the empty space wrote the card, and the guest, who never
      // opened the map, sees it live. A channel's space is standing room for
      // the whole channel, so both of them count as inside.
      const card = guest.page
        .locator('[data-testid="share-message-card"][data-share-kind="space"]')
        .last();
      await expect(card).toBeVisible({ timeout: 15_000 });
      await expect(card).toHaveAttribute("data-share-state", "live");
      await expect(card).toHaveAttribute("data-share-count", "2", {
        timeout: 15_000,
      });

      // The guest walks in too.
      const guestSpace = await guest.ctx.newPage();
      await guestSpace.goto(hostSpace.url());
      await walkIn(guestSpace, "rogue");

      // Everybody goes home; the card becomes the record of the evening, on a
      // screen nobody touched.
      await guestSpace.close();
      await hostSpace.close();

      await expect(card).toHaveAttribute("data-share-state", "ended", {
        timeout: 30_000,
      });
      await expect(card).toHaveAttribute("data-share-visitors", "2");
      await expect(card.getByTestId("share-message-enter")).toHaveCount(0);
    } finally {
      await closeUsers([host, guest]);
    }
  });
});
