/**
 * @section PW - Public Pages, Landing, And Showcase
 * @flow PW22 [done] The public games catalogue leads from a game's page, through the page's own Connect window, into the game
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { expect, test } from "@playwright/test";
import { uniqueNickname } from "../pages/ConnectPage";
import { shot } from "../helpers/screenshots";

const CONNECT_WINDOW = '[data-testid="landing-connect-window"]';

test("a game's public page signs a reader in and lands them on the game (PW22)", async ({
  page,
}) => {
  await page.goto("/games");
  await expect(page.locator("#games-heading")).toBeVisible();
  await shot(page, "games-catalogue");

  // The catalogue's windows open cascaded like every landing page's; the
  // taskbar brings the multiplayer one to the front.
  await page.locator('[data-window-taskbar="multiplayer"]').click();
  await page.getByTestId("game-card-hex-tennis").click();
  await expect(page).toHaveURL(/\/games\/hex-tennis$/);
  await expect(page.locator("#game-heading")).toHaveText("Hex Tennis");
  await expect(page.getByTestId("game-modes")).toContainText("Quick Match");
  await shot(page, "game-page");

  // Playing needs a nickname: the button brings the page's own Connect
  // window forward rather than sending the reader to /connect.
  await page.getByTestId("game-play").click();
  const connect = page.locator(CONNECT_WINDOW);
  await expect(connect).toBeVisible();
  expect(new URL(page.url()).pathname).toBe("/games/hex-tennis");

  await connect.locator("#nickname").fill(uniqueNickname("PWGame"));
  await connect.locator('[data-testid="connect-btn"]').click();
  await connect.locator("#reg-password").fill("pw12345");
  await connect.locator("#reg-password-confirm").fill("pw12345");
  await connect.locator('[data-testid="register-btn"]').click();

  // Signing in lands on the game the page was about, not on the chat.
  await expect(page).toHaveURL(/\/play\/hex_tennis$/, { timeout: 15000 });
  await expect(page.getByRole("button", { name: "Play vs AI" })).toBeVisible();
});
