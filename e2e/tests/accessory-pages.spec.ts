/**
 * @section PW - Public Pages, Landing, And Showcase
 * @flow PW40 [done] /paint, /ascii-art and /radio show the program in real pictures, with its own title and share card
 * @flow PW41 [done] A visitor's Open Hex Paint asks for an account; a member's opens Hex Paint on the desktop
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { expect, Page, test } from "@playwright/test";
import { closeUsers, newSignedInUser } from "../helpers/chatUsers";
import { shot } from "../helpers/screenshots";

async function connected(page: Page) {
  await page.waitForFunction(
    () =>
      !!document
        .querySelector("[data-phx-main]")
        ?.classList.contains("phx-connected"),
  );
}

for (const page of [
  { path: "/paint", heading: "paint-heading", card: "/images/tools/og/paint" },
  {
    path: "/ascii-art",
    heading: "ascii-art-heading",
    card: "/images/tools/og/ascii_art",
  },
  { path: "/radio", heading: "radio-heading", card: "/images/tools/og/radio" },
]) {
  test(`${page.path} shows the program in real pictures, with its own card (PW40)`, async ({
    page: tab,
  }) => {
    await tab.goto(page.path);
    await expect(tab.locator(`#${page.heading}`)).toBeVisible();
    const pictures = tab.locator("img[src*='/images/tools/']");
    await expect(pictures.first()).toBeVisible();
    expect(
      await pictures
        .first()
        .evaluate((img: HTMLImageElement) => img.naturalWidth),
    ).toBeGreaterThan(0);
    await expect(tab.locator("meta[property='og:image']")).toHaveAttribute(
      "content",
      new RegExp(page.card),
    );
    await shot(tab, `${page.path} page`);
  });
}

test("a visitor's Open asks for an account, a member's opens Hex Paint (PW41)", async ({
  browser,
}) => {
  const visitorCtx = await browser.newContext();
  const visitor = await visitorCtx.newPage();
  const member = await newSignedInUser(browser, "pgpt");

  try {
    await visitor.goto("/paint");
    await connected(visitor);
    await visitor.getByTestId("paint-open").click();
    await expect(visitor.getByTestId("document-window-connect")).toContainText(
      "Hex Paint",
    );
    await shot(visitor, "visitor asked to register");

    await member.page.goto("/paint");
    await connected(member.page);
    await member.page.getByTestId("paint-open").click();
    await expect(member.page.getByTestId("paint-window")).toBeVisible();
    await expect(member.page.getByTestId("hex-paint-canvas")).toBeVisible();
    await shot(member.page, "member in hex paint");
  } finally {
    await visitorCtx.close();
    await closeUsers([member]);
  }
});
