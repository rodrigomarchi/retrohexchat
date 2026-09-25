/**
 * @section H - Channels, Server Messages, Local Window State
 * @flow H13 [done] An operator schedules a channel event; the room gets a card in its own time zone, a second person says they are going, and the window lists it (features P1)
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";
import { shot } from "../helpers/screenshots";

test.describe("Channel events", () => {
  test("a scheduled event is a card in the room, an answer, and a window (H13)", async ({
    browser,
  }) => {
    const ctxHost = await browser.newContext();
    const ctxGuest = await browser.newContext();
    const pageHost = await ctxHost.newPage();
    const pageGuest = await ctxGuest.newPage();

    const channel = `#evt${Math.random().toString(36).slice(2, 8)}`;
    const hostNick = uniqueNickname("hos");
    const guestNick = uniqueNickname("gue");

    try {
      const hostConnect = new ConnectPage(pageHost);
      const host = new ChatPage(pageHost);
      await hostConnect.open();
      await hostConnect.enterNickname(hostNick);
      await hostConnect.registerWithPassword("pass12345");
      await host.waitUntilConnected();
      await host.sendMessage(`/join ${channel}`);
      await host.expectTabVisible(channel);

      const guestConnect = new ConnectPage(pageGuest);
      const guest = new ChatPage(pageGuest);
      await guestConnect.open();
      await guestConnect.enterNickname(guestNick);
      await guestConnect.registerWithPassword("pass12345");
      await guest.waitUntilConnected();
      await guest.sendMessage(`/join ${channel}`);
      await guest.expectTabVisible(channel);

      // Nothing on the calendar yet: the window has to open with nothing in it.
      await host.sendMessage("/event");
      const eventsWindow = pageHost.locator('[data-testid="events-window"]');
      await expect(eventsWindow).toBeVisible();
      await expect(eventsWindow.getByTestId("list-empty-state")).toBeVisible();
      await shot(pageHost, "events-window-empty");
      await eventsWindow.locator('[data-window-control="close"]').click();
      await expect(eventsWindow).toBeHidden();

      // The operator schedules it, and the room gets the card.
      await host.sendMessage("/event 2h Tuesday tournament");

      const hostCard = pageHost.locator('[data-testid^="event-card-"]');
      await expect(hostCard).toHaveCount(1);
      await expect(hostCard).toContainText("Tuesday tournament");
      await expect(hostCard).toHaveAttribute("data-event-attendees", "0");

      const guestCard = pageGuest.locator('[data-testid^="event-card-"]');
      await expect(guestCard).toHaveCount(1);
      await expect(guestCard).toContainText("Tuesday tournament");

      await shot(pageHost, "event-card-in-room");

      // A regular member cannot schedule: the channel refuses, not the button.
      await guest.sendMessage("/event 1h Their own tournament");
      await expect(
        pageGuest.locator('[data-testid^="event-card-"]'),
      ).toHaveCount(1);

      // But anybody can say they are going, and every copy of the card counts it.
      await guestCard.getByTestId(/^event-attend-/).click();
      await expect(guestCard).toHaveAttribute("data-event-attendees", "1");
      await expect(hostCard).toHaveAttribute("data-event-attendees", "1");

      await shot(pageGuest, "event-card-going");

      // And the window lists what the channel has coming up.
      await guest.sendMessage("/event");
      const guestWindow = pageGuest.locator('[data-testid="events-window"]');
      await expect(guestWindow).toBeVisible();
      await expect(
        guestWindow.locator('[data-testid^="events-row-"]'),
      ).toHaveCount(1);
      await expect(guestWindow).toContainText("Tuesday tournament");

      await shot(pageGuest, "events-window-filled");
    } finally {
      await ctxHost.close();
      await ctxGuest.close();
    }
  });
});
