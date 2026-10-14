/**
 * @section SP - Virtual Spaces
 * @flow SP38 [done] Q waves and Z starts and stops a dance, and the other person in the space sees both; a step ends the dance
 * @flow SP39 [done] On the on-screen pad, the hand button waves and the note button dances
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect, Page, CDPSession } from "@playwright/test";
import {
  newSignedInUser,
  closeUsers,
  uniqueChannel,
  TestUser,
} from "../helpers/chatUsers";
import { enterAs, Look } from "../helpers/characters";
import { shot } from "../helpers/screenshots";

async function walkIn(space: Page, avatar: Look | string) {
  await enterAs(space, avatar);
  await expect(space.getByTestId("channel-space-shell")).toBeVisible({
    timeout: 15_000,
  });
  await expect(space.getByTestId("space-loading")).toBeHidden({
    timeout: 15_000,
  });
}

// Every frame a page's own socket receives, as text: what the server told
// that person.
async function framesOf(space: Page): Promise<string[]> {
  const frames: string[] = [];
  const cdp: CDPSession = await space.context().newCDPSession(space);
  await cdp.send("Network.enable");
  cdp.on("Network.webSocketFrameReceived", ({ response }) => {
    frames.push(response?.payloadData ?? "");
  });
  return frames;
}

const heard = (frames: string[], ...parts: string[]) =>
  frames.some((f) => parts.every((p) => f.includes(p)));

// The server takes one action per person every 250 ms; a dance asked for
// sooner after a wave is a repeat it drops.
const ACTION_GAP_MS = 300;

test.describe("Waving and dancing in a space", () => {
  test("Q waves and Z dances, and the other person sees both (SP38)", async ({
    browser,
  }) => {
    test.setTimeout(90_000);
    const alice = await newSignedInUser(browser, "ema");
    const bob = await newSignedInUser(browser, "emb");
    try {
      await alice.chat.sendMessage(`/msg ${bob.nick} party?`);
      await alice.page.getByTestId(`pm-${bob.nick}`).click();
      const aliceSpace = await alice.chat.openSpace();
      await walkIn(aliceSpace, "bard");
      const bobSpace = await bob.ctx.newPage();
      const bobHears = await framesOf(bobSpace);
      await bobSpace.goto(aliceSpace.url());
      await walkIn(bobSpace, "sailor");

      // The wave plays at once and lasts under a second: caught mid-way.
      await aliceSpace.keyboard.press("q");
      await aliceSpace.waitForTimeout(150);
      await shot(aliceSpace, "alice waving");
      await expect
        .poll(() => heard(bobHears, "space_action", '"kind":"wave"'))
        .toBe(true);

      await aliceSpace.waitForTimeout(ACTION_GAP_MS);
      await aliceSpace.keyboard.press("z");
      await expect
        .poll(() => heard(bobHears, "space_delta", '"pose":"dancing"'))
        .toBe(true);
      await aliceSpace.waitForTimeout(500);
      await shot(aliceSpace, "alice dancing");
      await shot(bobSpace, "bob sees alice dancing");

      // Z again stops; and a step would too.
      const before = bobHears.length;
      await aliceSpace.waitForTimeout(ACTION_GAP_MS);
      await aliceSpace.keyboard.press("z");
      await expect
        .poll(() =>
          heard(bobHears.slice(before), "space_delta", '"pose":"standing"'),
        )
        .toBe(true);

      await aliceSpace.waitForTimeout(ACTION_GAP_MS);
      await aliceSpace.keyboard.press("z");
      await expect
        .poll(
          () =>
            bobHears.filter(
              (f) =>
                f.includes("space_delta") && f.includes('"pose":"dancing"'),
            ).length,
        )
        .toBe(2);
      const beforeStep = bobHears.length;
      await aliceSpace.keyboard.press("ArrowDown");
      await expect
        .poll(() =>
          heard(bobHears.slice(beforeStep), "space_delta", '"pose":"standing"'),
        )
        .toBe(true);
    } finally {
      await closeUsers([alice, bob]);
    }
  });

  test("the pad's hand button waves and its note button dances (SP39)", async ({
    browser,
  }) => {
    const user: TestUser = await newSignedInUser(browser, "emp");
    try {
      await user.chat.sendMessage(`/join ${uniqueChannel("emp")}`);
      const space = await user.chat.openSpace();
      const hears = await framesOf(space);
      await walkIn(space, "mage");

      const pad = space.getByTestId("space-virtual-pad");
      await pad.getByTestId("space-pad-wave").click();
      await expect
        .poll(() => heard(hears, "space_action", '"kind":"wave"'))
        .toBe(true);

      await space.waitForTimeout(ACTION_GAP_MS);
      await pad.getByTestId("space-pad-dance").click();
      await expect
        .poll(() => heard(hears, "space_delta", '"pose":"dancing"'))
        .toBe(true);
      await shot(pad, "the pad with its wave and dance buttons");
    } finally {
      await closeUsers([user]);
    }
  });
});
