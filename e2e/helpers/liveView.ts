import type { Page } from "@playwright/test";

/**
 * Waits until the page's LiveView has joined. Before that the page is the
 * server's first HTML: it reads, but a click on a control whose work is done
 * by LiveView (a tab, a `phx-click`) goes nowhere. `liveSocket.isConnected()`
 * is about the transport, not the view; LiveView marks the main element
 * `phx-connected` once the view itself has joined.
 */
export async function waitForView(page: Page): Promise<void> {
  await page.waitForFunction(
    () =>
      !!document
        .querySelector("[data-phx-main]")
        ?.classList.contains("phx-connected"),
    { timeout: 10_000 },
  );
}
