/**
 * Director — EP01, "RetroHexChat: a real IRC client, in your browser".
 *
 * Films the episode's scenes for the YouTube channel. Not a test: nothing here
 * guards a behaviour, and it never runs with the suite. The script, narration
 * and timing live in `retro_hex_chat_videos/episodes/01-overview/script.md`;
 * each `film` call below plays one scene's SCREEN directions.
 *
 *   make e2e.director SHOTS=/abs/shots.json OUT=/abs/capture
 */
import { expect, test } from "@playwright/test";
import { ChatPage } from "../pages/ChatPage";
import { Cast, Line } from "./cast";
import {
  cameraContext,
  film,
  restCursor,
  shotFor,
  typeOnCamera,
} from "./shots";

const CONNECT_WINDOW = '[data-testid="landing-connect-window"]';

// The viewer's nickname for the whole episode. A registered nick takes the
// sign-in path instead, so a retake needs a fresh database or another nick.
const NICK = process.env.DIRECTOR_NICK || "Pixel";
const PASSWORD = "retro1998";

// Already in #lobby when the viewer arrives. The first founds the channel and
// owns it; the order is casting.
const CAST = ["nova", "kestrel", "lumen", "bytebard", "dialup_dan", "m0dem"];
const TOPIC = "Welcome to #lobby — be excellent to each other";

// The conversation the viewer scrolls into: it happened before they joined.
const EARLIER: Line[] = [
  {
    by: "bytebard",
    says: "anyone else still have a 56k modem in a drawer somewhere?",
  },
  { by: "dialup_dan", says: "mine is on the shelf next to the zip drive 😄" },
  { by: "kestrel", says: "just beat E1M3 in the arcade without saving" },
  { by: "lumen", says: "no way, the secret exit too?" },
  { by: "kestrel", says: "of course. took me an hour to find it in 1994" },
  { by: "m0dem", says: "half the channel is hanging out in the Space tonight" },
  { by: "nova", says: "trivia starts at 9, bring your best 90s facts" },
];

test.describe.configure({ mode: "serial" });

test.describe("EP01 overview", () => {
  let cast: Cast;

  test.beforeAll(async ({ browser }) => {
    test.setTimeout(3 * 60_000);
    cast = await Cast.assemble(browser, CAST, PASSWORD);
    await cast.command("nova", `/topic ${TOPIC}`);
    await cast.command("nova", "/op kestrel");
    await cast.command("nova", "/voice lumen");
    await cast.command("nova", "/voice bytebard");
    await expect(
      cast.member("nova").page.getByText(TOPIC).first(),
    ).toBeVisible();
    await cast.play(EARLIER);
  });

  test.afterAll(async () => {
    await cast?.dismiss();
  });

  test("01 connect in five seconds", async ({ browser }) => {
    const shot = shotFor(1);
    const ctx = await cameraContext(browser);
    const page = await ctx.newPage();

    // Off camera: the landing has painted and its fonts are in.
    await page.goto("/");
    await expect(page.locator(CONNECT_WINDOW)).toBeVisible();
    await page.evaluate(() => document.fonts.ready);

    await film(page, shot, async (pace) => {
      await pace(1500);
      await page.locator(`${CONNECT_WINDOW} #nickname`).click();
      await typeOnCamera(page, `${CONNECT_WINDOW} #nickname`, NICK);
      await pace(500);
      await page
        .locator(`${CONNECT_WINDOW} [data-testid="connect-btn"]`)
        .click();

      const password = page.locator(`${CONNECT_WINDOW} #reg-password`);
      await expect(
        password,
        `"${NICK}" is already registered — run \`make e2e.prepare\` or set DIRECTOR_NICK`,
      ).toBeVisible({ timeout: 15_000 });
      await pace(600);
      await typeOnCamera(page, `${CONNECT_WINDOW} #reg-password`, PASSWORD);
      await typeOnCamera(
        page,
        `${CONNECT_WINDOW} #reg-password-confirm`,
        PASSWORD,
      );
      await pace(400);
      await page
        .locator(`${CONNECT_WINDOW} [data-testid="register-btn"]`)
        .click();

      const chat = new ChatPage(page);
      await chat.waitUntilConnected();
      await restCursor(page);
      await chat.expectMessageVisible(EARLIER.at(-1)!.says);
      await pace(900);
      await cast.say("nova", `hey ${NICK}, welcome to #lobby 👋`);
      await pace(700);
      await cast.say("dialup_dan", "welcome! grab a seat");
      await pace(1500);
    });

    await ctx.close();
  });
});
