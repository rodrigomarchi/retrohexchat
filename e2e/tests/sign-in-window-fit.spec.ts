/**
 * @section PW - Public Pages, Landing, And Showcase
 * @flow PW31 [done] Every step of the sign-in window — nickname, a wrong nickname, registration with Remember this terminal, password, remembered nicknames — fits a 1280x720 desktop and a phone without scrolling or spilling sideways, a visitor's reason included; How sessions work and each thing an account opens open their help topic in a new tab, leaving the window where it was
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect, devices, Browser, Page } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { shot } from "../helpers/screenshots";
import { CHAT_URL } from "../helpers/urls";

const SIGN_IN_WINDOW = '[data-testid="document-window-connect"]';
const PASSWORD = "pw12345";

const PROFILES = {
  desktop: devices["Desktop Chrome"],
  phone: devices["Pixel 5"],
};

type Profile = keyof typeof PROFILES;

async function openBrowser(browser: Browser, profile: Profile) {
  const context = await browser.newContext(PROFILES[profile]);
  return { context, page: await context.newPage() };
}

// Content taller than the window scrolls inside it; content wider than it
// spills past its right edge. Neither may happen. The window manager sizes a
// window to its content a frame after the content changes, so the check is
// polled until it settles.
async function expectFits(page: Page) {
  await expect
    .poll(() => page.evaluate(measureFit, SIGN_IN_WINDOW), { timeout: 5000 })
    .toEqual({ scrolling: [], spilled: [] });
}

function measureFit(selector: string) {
  const body = document.querySelector(
    '[data-testid="connect-window"]',
  ) as HTMLElement;
  const win = document.querySelector(selector) as HTMLElement;

  const scrolling: string[] = [];
  for (
    let el: HTMLElement | null = body;
    el && el !== win;
    el = el.parentElement
  ) {
    const overflow = getComputedStyle(el).overflowY;
    const canScroll = overflow === "auto" || overflow === "scroll";
    if (canScroll && el.scrollHeight > el.clientHeight + 1) {
      scrolling.push(
        `${el.className} (${el.scrollHeight} > ${el.clientHeight})`,
      );
    }
  }

  const right = win.getBoundingClientRect().right;
  const spilled = [...body.querySelectorAll<HTMLElement>("*")]
    .filter(
      (el) => el.offsetParent && el.getBoundingClientRect().right > right + 1,
    )
    .map((el) => el.dataset.testid || el.tagName);

  return { scrolling, spilled };
}

async function register(page: Page, nickname: string) {
  const connect = new ConnectPage(page);
  await connect.open();
  const manual = page.getByTestId("manual-login-btn");
  if (await manual.isVisible()) await manual.click();
  await connect.enterNickname(nickname);
  await page.locator("#reg-password").fill(PASSWORD);
  await page.locator("#reg-password-confirm").fill(PASSWORD);
  await page.getByTestId("remember-device").check();
  await page.getByTestId("register-btn").click();
  await expect(page).toHaveURL(CHAT_URL, { timeout: 15000 });
}

for (const profile of Object.keys(PROFILES) as Profile[]) {
  test.describe(`The sign-in window on a ${profile}`, () => {
    test(`${profile}: nickname, registration and password fit (PW31)`, async ({
      browser,
    }) => {
      const { context, page } = await openBrowser(browser, profile);
      const connect = new ConnectPage(page);

      try {
        await connect.open();
        await expectFits(page);
        await shot(page, "nickname");

        // What a visitor tried to use leads the window, with its icon.
        await page.goto("/connect?signup=chat");
        await expect(page.getByTestId("visitor-connect-reason")).toBeVisible();
        await expectFits(page);
        await shot(page, "visitor-reason");
        await connect.open();

        // The session rules live in their help topic, opened in a new tab so
        // the sign-in window stays where it was.
        const [help] = await Promise.all([
          context.waitForEvent("page"),
          page.getByTestId("connect-sessions-help").click(),
        ]);
        await expect(help.getByTestId("document-window-help")).toContainText(
          "Three chats at a time",
        );
        await help.close();
        await expect(page).toHaveURL(/\/connect$/);

        // So does each thing an account opens.
        const [feature] = await Promise.all([
          context.waitForEvent("page"),
          page
            .getByTestId("connect-account-features")
            .getByRole("link")
            .first()
            .click(),
        ]);
        await expect(feature).toHaveURL(/\/chat\/help\//);
        await feature.close();
        await expect(page).toHaveURL(/\/connect$/);

        await connect.typeNickname("1bad nick");
        await page.getByTestId("connect-btn").click();
        await expect(page.getByTestId("nickname-error")).toBeVisible();
        await expect(page.getByTestId("nickname-hint")).toHaveCount(0);
        await expectFits(page);
        await shot(page, "nickname-error");

        const nickname = uniqueNickname("Fit");
        await connect.enterNickname(nickname);
        await expect(page.locator("#reg-password")).toBeVisible();
        await page.getByTestId("remember-device").check();
        await expect(page.getByTestId("remember-device-panel")).toBeVisible();
        await expect(page.getByTestId("device-label")).not.toHaveValue("");
        await expectFits(page);
        await shot(page, "register-remembering");

        await page.locator("#reg-password").fill(PASSWORD);
        await page.locator("#reg-password-confirm").fill(PASSWORD);
        await page.getByTestId("register-btn").click();
        await expect(page).toHaveURL(CHAT_URL, { timeout: 15000 });

        // A browser that has never seen the nickname is asked for its password.
        const other = await openBrowser(browser, profile);
        try {
          const otherConnect = new ConnectPage(other.page);
          await otherConnect.open();
          await otherConnect.enterNickname(nickname);
          await expect(other.page.locator("#password")).toBeVisible();
          await expectFits(other.page);
          await shot(other.page, "password");
        } finally {
          await other.context.close();
        }
      } finally {
        await context.close();
      }
    });

    test(`${profile}: remembered nicknames fit and sign back in (PW31)`, async ({
      browser,
    }) => {
      const { context, page } = await openBrowser(browser, profile);
      const first = uniqueNickname("Mem");
      const second = uniqueNickname("Alt");

      try {
        for (const nickname of [first, second]) {
          await register(page, nickname);
          await page.goto("/chat/session/clear");
        }

        await new ConnectPage(page).open();
        await expect(
          page.getByTestId(`remembered-nick-${first}`),
        ).toBeVisible();
        await expect(
          page.getByTestId(`remembered-nick-${second}`),
        ).toBeVisible();
        await expectFits(page);
        await shot(page, "remembered-nicknames");

        await page.getByTestId("manual-login-btn").click();
        await expect(page.locator("#nickname")).toBeVisible();
        await expect(page.getByTestId("trusted-choices-btn")).toBeVisible();
        await expectFits(page);
        await shot(page, "another-nickname");

        await page.getByTestId("trusted-choices-btn").click();
        await page.getByTestId(`remembered-nick-login-${first}`).click();
        await expect(page).toHaveURL(CHAT_URL, { timeout: 15000 });
      } finally {
        await context.close();
      }
    });
  });
}
