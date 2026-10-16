/**
 * @section Auth And Lifecycle
 * @flow H [done] The chat's old address `/chat` (and `?join=`) redirects permanently to the desktop: without a session that is the visitor's read-only chat, never a bounce to `/connect`
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect } from "@playwright/test";

test.describe("The chat's old address", () => {
  test("/chat and ?join= lead to the desktop, read-only without a session (H)", async ({
    page,
    request,
  }) => {
    const legacy = await request.get("/chat?join=%23lobby", {
      maxRedirects: 0,
    });
    expect(legacy.status()).toBe(301);
    expect(legacy.headers()["location"]).toBe("/c/lobby");

    await page.goto("/chat");
    await expect(page).toHaveURL(/\/$/);
    await expect(page.getByTestId("chat-window")).toBeVisible();
    await expect(page).not.toHaveURL(/\/connect/);
  });
});
