/**
 * @section Auth And Lifecycle
 * @flow A6 [done] A recovery address is added from the Account window and confirmed by following the link
 * @flow A7 [done] A forgotten password is replaced from the emailed link and the new one signs in
 * @flow A8 [done] A reset link that was already used no longer sets a password
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect, Page, APIRequestContext } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";
import { shot } from "../helpers/screenshots";

const PASSWORD = "pass12345";
const NEW_PASSWORD = "brandnew12345";

type Sent = { to: string[]; subject: string; text: string };

/**
 * What this server has sent since it booted.
 *
 * The e2e environment posts to Swoosh's local adapter, which keeps messages in
 * memory; `/api/e2e/mailbox` is the window onto it. A person following a link
 * out of their mail client is the whole point of these two flows, and it is the
 * one half of them a browser cannot reach on its own.
 */
async function mailbox(request: APIRequestContext): Promise<Sent[]> {
  const response = await request.get("/api/e2e/mailbox");
  expect(response.ok()).toBeTruthy();
  const body = await response.json();

  return body.messages as Sent[];
}

async function linkSentTo(
  request: APIRequestContext,
  address: string,
  path: RegExp,
): Promise<string> {
  let found: string | null = null;

  await expect(async () => {
    const messages = await mailbox(request);
    const mine = messages.filter((message) => message.to.includes(address));
    const match = mine.map((message) => message.text.match(path)).find(Boolean);

    expect(match, `no message to ${address} carrying ${path}`).toBeTruthy();
    found = match![0];
  }).toPass({ timeout: 10_000 });

  return found!;
}

async function register(page: Page, prefix: string) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword(PASSWORD);
  await chat.waitUntilConnected();

  return { connect, chat, nick };
}

async function addRecoveryAddress(page: Page, address: string) {
  const chat = new ChatPage(page);
  await chat.openAccountRegisterFromMenu();

  await page.getByTestId("account-email-input").fill(address);
  await page.getByTestId("account-email-save").click();

  await expect(page.getByTestId("account-email-current")).toContainText(
    address,
  );
}

test.describe("Account recovery", () => {
  test("a recovery address is added and confirmed by following the link", async ({
    page,
    request,
  }) => {
    const { nick } = await register(page, "rec");
    const address = `${nick.toLowerCase()}@retrohexchat.test`;

    await addRecoveryAddress(page, address);

    // Added but not yet confirmed: the window says so rather than claiming a
    // recovery path that cannot be used.
    await expect(page.getByTestId("account-email-current")).toContainText(
      /waiting/i,
    );

    const link = await linkSentTo(
      request,
      address,
      /\/account\/verify\/[\w.-]+/,
    );
    await page.goto(link);

    await expect(page.getByTestId("account-verified")).toBeVisible();
    await shot(page, "address-confirmed");
  });

  test("a forgotten password is replaced from the emailed link", async ({
    page,
    request,
  }) => {
    const { nick } = await register(page, "rst");
    const address = `${nick.toLowerCase()}@retrohexchat.test`;

    await addRecoveryAddress(page, address);
    const verify = await linkSentTo(
      request,
      address,
      /\/account\/verify\/[\w.-]+/,
    );
    await page.goto(verify);

    const connect = new ConnectPage(page);
    await connect.open();
    await connect.enterNickname(nick);

    await page.getByTestId("forgot-password-btn").click();
    await expect(page.getByTestId("recovery-sent")).toBeVisible();

    const reset = await linkSentTo(
      request,
      address,
      /\/account\/reset\/[\w.-]+/,
    );
    await page.goto(reset);
    await shot(page, "choose-a-new-password");

    await page.getByTestId("account-reset-password").fill(NEW_PASSWORD);
    await page.getByTestId("account-reset-submit").click();

    await expect(page.getByTestId("account-reset-done")).toBeVisible();

    // The point of the whole flow: the new password is the one that works.
    const chat = new ChatPage(page);
    await connect.open();
    await connect.enterNickname(nick);
    await connect.authenticateWithPassword(NEW_PASSWORD);
    await chat.waitUntilConnected();
  });

  test("a reset link that was already used no longer sets a password", async ({
    page,
    request,
  }) => {
    const { nick } = await register(page, "onc");
    const address = `${nick.toLowerCase()}@retrohexchat.test`;

    await addRecoveryAddress(page, address);
    const verify = await linkSentTo(
      request,
      address,
      /\/account\/verify\/[\w.-]+/,
    );
    await page.goto(verify);

    const connect = new ConnectPage(page);
    await connect.open();
    await connect.enterNickname(nick);
    await page.getByTestId("forgot-password-btn").click();
    await expect(page.getByTestId("recovery-sent")).toBeVisible();

    const reset = await linkSentTo(
      request,
      address,
      /\/account\/reset\/[\w.-]+/,
    );
    await page.goto(reset);
    await page.getByTestId("account-reset-password").fill(NEW_PASSWORD);
    await page.getByTestId("account-reset-submit").click();
    await expect(page.getByTestId("account-reset-done")).toBeVisible();

    // Second visit to the same address: a link that still worked would leave
    // whoever forwarded the mail, or read it over a shoulder, holding a key.
    await page.goto(reset);
    await expect(page.getByTestId("account-reset-form")).toHaveCount(0);
    await expect(page.getByTestId("account-error")).toBeVisible();
  });
});
