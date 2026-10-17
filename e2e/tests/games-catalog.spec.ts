/**
 * @section PW - Public Pages, Landing, And Showcase
 * @flow PW22 [done] The public games catalogue leads from a game's page, through the sign-in window over the same desktop, into the game
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { expect, test } from "@playwright/test";
import { uniqueNickname } from "../pages/ConnectPage";
import { shot } from "../helpers/screenshots";
import { bringForward } from "../helpers/siteWindows";

const SIGN_IN_WINDOW = '[data-testid="document-window-connect"]';

test("a game's public page signs a reader in and lands them on the game (PW22)", async ({
  page,
}) => {
  await page.goto("/games");
  await expect(page.locator("#games-heading")).toBeVisible();
  await shot(page, "games-catalogue");

  // The catalogue is a window per list: the page's taskbar group brings the
  // multiplayer one forward, and a card opens the game's page in its place.
  await bringForward(page, "site-multiplayer");
  await page.getByTestId("game-card-hex-tennis").scrollIntoViewIfNeeded();
  await page.getByTestId("game-card-hex-tennis").click();
  await expect(page).toHaveURL(/\/games\/hex-tennis$/);
  await expect(page.locator("#game-heading")).toHaveText("Hex Tennis");
  await expect(page.getByTestId("game-modes")).toContainText("Quick Match");
  await shot(page, "game-page");

  // Playing needs a nickname: the sign-in window opens over the same
  // desktop, remembering the game it was asked for.
  await page.getByTestId("game-play").click();
  const connect = page.locator(SIGN_IN_WINDOW);
  await expect(connect).toBeVisible();
  await expect(page).toHaveURL(/\/connect\?.*return_to=%2Fplay%2Fhex_tennis/);

  await connect.locator("#nickname").fill(uniqueNickname("PWGame"));
  await connect.locator('[data-testid="connect-btn"]').click();
  await connect.locator("#reg-password").fill("pw12345");
  await connect.locator("#reg-password-confirm").fill("pw12345");
  await connect.locator('[data-testid="register-btn"]').click();

  // Signing in lands on the game the page was about, not on the chat.
  await expect(page).toHaveURL(/\/play\/hex_tennis$/, { timeout: 15000 });
  await expect(page.getByRole("button", { name: "Play vs AI" })).toBeVisible();
});
