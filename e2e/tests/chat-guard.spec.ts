/**
 * @section Auth And Lifecycle
 * @flow H [done] Direct `/chat` access without session bounces to `/connect`
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect } from "@playwright/test";

test.describe("Chat route guard", () => {
  test("direct /chat access without session bounces to /connect (H)", async ({
    page,
  }) => {
    await page.goto("/chat");
    await expect(page).toHaveURL(/\/connect(\?.*)?$/);
  });
});
