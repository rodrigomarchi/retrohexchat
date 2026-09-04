import { BrowserContext, Page, expect } from "@playwright/test";

/**
 * Walking into a surface the way a person does: through the card.
 *
 * Every entry beside the conversation's tabs used to be an anchor, so a spec
 * clicked it and got a tab. None of them are any more — pressing one writes the
 * room's card into the conversation and goes nowhere — so the card is where a
 * spec has to go too, which is the point of the change: there is one door, and
 * everybody reading the conversation can see it.
 */

/** Every address the cards on screen are currently offering. */
async function cardAddresses(page: Page): Promise<string[]> {
  return (
    await page
      .getByTestId("share-message-enter")
      .evaluateAll((nodes) =>
        nodes.map((node) => node.getAttribute("href") || ""),
      )
  ).filter(Boolean);
}

/**
 * Press an entry beside the tabs and follow the card it writes.
 *
 * The card is picked by the address that was not there a moment ago, never by
 * position: a conversation can already be carrying cards from another room, and
 * following the last one on screen is how a spec ends up on somebody else's
 * expired link and blames the code under test.
 */
export async function enterThroughNewCard(
  page: Page,
  ctx: BrowserContext,
  testid: string,
  options: { timeout?: number } = {},
): Promise<Page> {
  const timeout = options.timeout ?? 20_000;
  const entry = page.getByTestId(testid);

  await expect(entry).toBeVisible({ timeout });
  await expect(entry).toBeEnabled();

  const before = new Set(await cardAddresses(page));
  await entry.click();

  // A press into a room that is already open answers with a sentence rather
  // than a second card — one room, one door — so the card to follow is either
  // the one that just appeared or the one that was already there.
  let address: string | undefined;

  await expect
    .poll(
      async () => {
        const addresses = await cardAddresses(page);
        address =
          addresses.find((href) => !before.has(href)) ?? addresses.at(-1);
        return address ?? null;
      },
      { timeout },
    )
    .not.toBeNull();

  return followCard(page, ctx, address as string, timeout);
}

/** Follow a card already on screen, named by the address it carries. */
export async function followCard(
  page: Page,
  ctx: BrowserContext,
  address: string,
  timeout = 20_000,
): Promise<Page> {
  const card = page.locator(
    `[data-testid="share-message-enter"][href="${address}"]`,
  );

  await expect(card).toBeVisible({ timeout });

  const [opened] = await Promise.all([ctx.waitForEvent("page"), card.click()]);

  await opened.waitForLoadState("domcontentloaded");

  // The card points at the public address, and that page is the one that knows
  // whether this reader may go in. Somebody who is already signed in sees a
  // Join that goes straight through; a stranger is sent to connect first, which
  // is a flow of its own and not this helper's business.
  if (new URL(opened.url()).pathname.startsWith("/join/")) {
    const enter = opened.getByTestId("join-enter");
    await expect(enter).toBeVisible({ timeout });
    await enter.click();
    await opened.waitForLoadState("domcontentloaded");
  }

  return opened;
}

/**
 * Follow the newest card already on screen, for a reader who did not press
 * anything — the other half of a session, arriving at an invite.
 */
export async function enterViaCard(
  page: Page,
  ctx: BrowserContext,
  options: { timeout?: number } = {},
): Promise<Page> {
  const timeout = options.timeout ?? 20_000;
  const join = page.getByTestId("share-message-enter").last();

  await expect(join).toBeVisible({ timeout });
  const address = (await join.getAttribute("href")) as string;

  return followCard(page, ctx, address, timeout);
}
