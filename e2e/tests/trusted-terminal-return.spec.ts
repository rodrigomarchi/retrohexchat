/**
 * @section PW - Public Pages, Landing, And Showcase
 * @flow PW32 [done] A trusted terminal set to Auto-login is signed in by the first page it opens after the browser restarts, with no sign-in window or form in between; Log out keeps it out until the browser closes; Log in beside a remembered nickname works before the chat's socket has joined — on a desktop and on a phone
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import {
  test,
  expect,
  devices,
  Browser,
  BrowserContext,
  Page,
} from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { shot } from "../helpers/screenshots";
import { CHAT_URL } from "../helpers/urls";

const PASSWORD = "pw12345";
const SESSION_COOKIE = "_retro_hex_chat_web_key";

const PROFILES = {
  desktop: devices["Desktop Chrome"],
  phone: devices["Pixel 5"],
};

type Profile = keyof typeof PROFILES;

async function openBrowser(browser: Browser, profile: Profile) {
  const context = await browser.newContext(PROFILES[profile]);
  return { context, page: await context.newPage() };
}

// Closing the browser ends its session cookie and keeps every other one —
// the trusted terminal's among them.
async function restartBrowser(context: BrowserContext) {
  const kept = (await context.cookies()).filter(
    (c) => c.name !== SESSION_COOKIE,
  );
  await context.clearCookies();
  await context.addCookies(kept);
}

async function expectMember(page: Page, member: boolean) {
  await expect(page.locator("html")).toHaveAttribute(
    "data-member",
    String(member),
  );
}

function sessionPosts(page: Page) {
  const posts: string[] = [];
  page.on("request", (request) => {
    if (
      request.method() === "POST" &&
      new URL(request.url()).pathname === "/chat/session"
    )
      posts.push(request.url());
  });
  return posts;
}

async function registerRemembering(page: Page) {
  const nickname = uniqueNickname("Ret");
  const connect = new ConnectPage(page);
  await connect.open();
  await connect.enterNickname(nickname);
  await page.locator("#reg-password").fill(PASSWORD);
  await page.locator("#reg-password-confirm").fill(PASSWORD);
  await page.getByTestId("remember-device").check();
  await page.getByTestId("register-btn").click();
  await expect(page).toHaveURL(CHAT_URL, { timeout: 15000 });
  await expectMember(page, true);
  return nickname;
}

async function logOut(page: Page) {
  await page.goto("/chat/session/clear?reason=logout");
  await expect(page).toHaveURL(/\/connect$/);
  await expectMember(page, false);
}

for (const profile of Object.keys(PROFILES) as Profile[]) {
  test.describe(`A trusted terminal coming back on a ${profile}`, () => {
    test(`${profile}: Auto-login signs in on the first page, and Log out stays out (PW32)`, async ({
      browser,
    }) => {
      const { context, page } = await openBrowser(browser, profile);

      try {
        const nickname = await registerRemembering(page);
        await logOut(page);

        const toggle = page.getByTestId(`trusted-auto-login-${nickname}`);
        await toggle.click();
        await expect(toggle).toHaveAttribute("aria-checked", "true");

        // Logging out paused it: neither this window nor the next page signs in.
        await page.waitForTimeout(1000);
        await expect(page).toHaveURL(/\/connect$/);
        await page.goto("/");
        await expectMember(page, false);

        // A new browser session: the very first page answers as the member.
        await restartBrowser(context);
        const posts = sessionPosts(page);
        await page.goto("/");
        await expectMember(page, true);
        await expect(page.getByTestId("chat-input-field")).toBeEditable();
        expect(posts).toEqual([]);
        await shot(page, "auto-login-first-page");

        // An address that would ask for an account goes straight where it pointed.
        await restartBrowser(context);
        await page.goto("/connect?signup=chat&return_to=/c/lobby");
        await expect(page).toHaveURL(/\/c\/lobby$/);
        await expectMember(page, true);
        expect(posts).toEqual([]);

        await logOut(page);
        await expect(
          page.getByTestId(`remembered-nick-${nickname}`),
        ).toBeVisible();
        await page.waitForTimeout(1000);
        await expectMember(page, false);
        await shot(page, "after-log-out");
      } finally {
        await context.close();
      }
    });

    test(`${profile}: Log in beside a remembered nickname works before the socket joins (PW32)`, async ({
      browser,
    }) => {
      const { context, page } = await openBrowser(browser, profile);

      try {
        const nickname = await registerRemembering(page);
        await logOut(page);

        // No LiveView socket at all: whatever works now works from first paint.
        await page.routeWebSocket(/\/live\/websocket/, () => {});
        await page.goto("/connect");
        await expect(
          page.getByTestId(`trusted-auto-login-${nickname}`),
        ).toBeDisabled();
        await shot(page, "remembered-before-join");

        await page.getByTestId(`remembered-nick-login-${nickname}`).click();
        await expect(page).toHaveURL(CHAT_URL, { timeout: 15000 });
        await expectMember(page, true);
      } finally {
        await context.close();
      }
    });
  });
}
