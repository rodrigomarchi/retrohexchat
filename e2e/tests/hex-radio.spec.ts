/**
 * @section AC - Accessories: Hex Paint, ASCII Art And Hex Radio
 * @flow AC7 [done] Hex Radio opens from Start > Accessories on the most played stations; Play and Next walk the list; a genre from the footer menu and a search list theirs
 * @flow AC8 [done] A station that shares its sound plays with the live spectrum; one that does not still plays, with the SIM lamp lit and the equalizer saying it cannot change it; the equalizer switches off and on
 * @flow AC9 [done] A starred station is kept in the browser and listed under Favorites after the window is opened again; closing the window stops the music
 * @flow AC10 [done] Hex Radio fits a phone, the transport and the stations in view
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { expect, Page, test } from "@playwright/test";
import { closeUsers, newSignedInUser, TestUser } from "../helpers/chatUsers";
import { shot } from "../helpers/screenshots";

// Radio.Fixture's streams live on radio.e2e.test: answered here with a
// second of tone, repeated by the player, with or without the header that lets
// the page read the sound.
function tone(): Buffer {
  const rate = 8000;
  const samples = rate * 4;
  const data = Buffer.alloc(44 + samples * 2);
  data.write("RIFF", 0);
  data.writeUInt32LE(36 + samples * 2, 4);
  data.write("WAVEfmt ", 8);
  data.writeUInt32LE(16, 16);
  data.writeUInt16LE(1, 20);
  data.writeUInt16LE(1, 22);
  data.writeUInt32LE(rate, 24);
  data.writeUInt32LE(rate * 2, 28);
  data.writeUInt16LE(2, 32);
  data.writeUInt16LE(16, 34);
  data.write("data", 36);
  data.writeUInt32LE(samples * 2, 40);
  for (let i = 0; i < samples; i++) {
    const value = Math.sin((2 * Math.PI * 440 * i) / rate) * 0.5;
    data.writeInt16LE(Math.round(value * 32767), 44 + i * 2);
  }
  return data;
}

async function answerStreams(page: Page) {
  const body = tone();
  await page.route("https://radio.e2e.test/**", (route) => {
    // Neon Highway keeps its sound to itself: a request that asks to read it
    // (the shared element's, sent with an Origin) is refused, as the browser
    // refuses a stream without the header; the plain one is answered.
    const asksToRead = !!route.request().headers()["origin"];
    if (route.request().url().includes("e2e-neon") && asksToRead) {
      return route.abort("accessdenied");
    }
    return route.fulfill({
      status: 200,
      headers: {
        "content-type": "audio/wav",
        "access-control-allow-origin": "*",
      },
      body,
    });
  });
}

async function openRadio(user: TestUser) {
  const trigger = user.page.getByTestId("start-menu-accessories-submenu");
  const entry = user.page.getByTestId("start-menu-item-open_radio");
  await user.chat.openStartGroup(trigger, entry);
  await entry.click();
  const radio = user.page.getByTestId("radio-window");
  await expect(radio).toBeVisible();
  await expect(
    user.page.getByTestId("hex-radio-station").first(),
  ).toBeVisible();
  return radio;
}

test("Hex Radio lists stations, plays them and keeps the favorites (AC7, AC8, AC9)", async ({
  browser,
}) => {
  const user = await newSignedInUser(browser, "radio");
  const page = user.page;
  try {
    await answerStreams(page);
    const radio = await openRadio(user);
    await expect(page.getByTestId("hex-radio-station")).toHaveCount(6);
    await shot(page, "hex radio on the most played");

    // Play with nothing chosen plays the first; Next moves down the list.
    await page.getByTestId("hex-radio-play").click();
    await expect(page.getByTestId("hex-radio-station-name")).toHaveText(
      "Pixel Wave FM",
    );
    await page.getByTestId("hex-radio-next").click();
    await expect(page.getByTestId("hex-radio-station-name")).toHaveText(
      "Neon Highway",
    );
    await page.getByTestId("hex-radio-stop").click();

    // A genre from the footer's menu, and a search.
    await page.getByTestId("hex-radio-genre-menu").click();
    await expect(page.getByTestId("hex-radio-genres")).toBeVisible();
    await shot(page, "hex radio genre menu");
    await page.getByTestId("hex-radio-section-chiptune").click();
    await expect(page.getByTestId("hex-radio-genres")).toBeHidden();
    await expect(page.getByTestId("hex-radio-station")).toHaveCount(1);
    await expect(page.getByTestId("hex-radio-station")).toContainText(
      "Pixel Wave FM",
    );
    await page.getByTestId("hex-radio-find").click();
    await page.getByTestId("hex-radio-search-input").fill("neon");
    await page.getByTestId("hex-radio-search-input").press("Enter");
    await expect(page.getByTestId("hex-radio-station")).toHaveCount(1);
    await expect(page.getByTestId("hex-radio-station")).toContainText(
      "Neon Highway",
    );

    // A station that keeps its sound to itself still plays.
    await page.getByTestId("hex-radio-station-e2e-neon").click();
    await expect(page.getByTestId("hex-radio-status-state")).toHaveText(
      "Playing",
    );
    await expect(page.getByTestId("hex-radio-station-name")).toHaveText(
      "Neon Highway",
    );
    await expect(page.getByTestId("hex-radio")).toHaveAttribute(
      "data-radio-mode",
      "plain",
    );
    await page.getByTestId("hex-radio-equalizer-toggle").click();
    await expect(page.getByTestId("hex-radio-equalizer")).toBeVisible();
    await expect(page.getByTestId("hex-radio-equalizer")).toContainText(
      "cannot change it",
    );
    await expect(page.getByTestId("hex-radio-band-0")).toBeDisabled();
    await shot(page, "hex radio playing a closed station");

    // One that shares it plays through the spectrum and the equalizer.
    await page.getByTestId("hex-radio-genre-menu").click();
    await page.getByTestId("hex-radio-section-chiptune").click();
    await page.getByTestId("hex-radio-station-e2e-pixel").click();
    await expect(page.getByTestId("hex-radio-status-state")).toHaveText(
      "Playing",
    );
    await expect(page.getByTestId("hex-radio")).toHaveAttribute(
      "data-radio-mode",
      "shared",
    );
    await expect(page.getByTestId("hex-radio-band-0")).toBeEnabled();
    await page.getByTestId("hex-radio-eq-power").click();
    await expect(page.getByTestId("hex-radio-eq-power")).toHaveAttribute(
      "aria-pressed",
      "false",
    );
    await page.getByTestId("hex-radio-eq-power").click();
    await expect(
      page
        .getByTestId("hex-radio-station")
        .filter({ hasText: "Pixel Wave FM" }),
    ).toHaveAttribute("aria-current", "true");
    await shot(page, "hex radio playing with the equalizer");

    // Stop, then Space plays again with the window focused.
    await page.getByTestId("hex-radio-stop").click();
    await expect(page.getByTestId("hex-radio-status-state")).toHaveText(
      "Stopped",
    );
    await page.getByTestId("hex-radio").focus();
    await page.keyboard.press("Space");
    await expect(page.getByTestId("hex-radio-status-state")).toHaveText(
      "Playing",
    );

    // Starred, kept, listed when the window opens again; closing stops it.
    await page.getByTestId("hex-radio-star").click();
    await expect(page.getByTestId("hex-radio-star")).toHaveAttribute(
      "aria-pressed",
      "true",
    );
    // The server redraws the island for the star; the player's lamps and
    // glyph stay as the browser set them.
    await expect(page.getByTestId("hex-radio")).toHaveAttribute(
      "data-radio-state",
      "playing",
    );
    await expect
      .poll(() =>
        page.evaluate(() =>
          window.localStorage.getItem("retrohex.radio.favorites"),
        ),
      )
      .toContain("e2e-pixel");
    await radio.locator("[data-window-control='close']").click();
    await expect(radio).toBeHidden();
    await expect
      .poll(() =>
        page.evaluate(() =>
          [...document.querySelectorAll("audio")].some(
            (audio) => !audio.paused,
          ),
        ),
      )
      .toBe(false);

    await openRadio(user);
    await page.getByTestId("hex-radio-section-favorites").click();
    await expect(page.getByTestId("hex-radio-station")).toHaveCount(1);
    await expect(page.getByTestId("hex-radio-station")).toContainText(
      "Pixel Wave FM",
    );
    await shot(page, "hex radio favorites");
  } finally {
    await closeUsers([user]);
  }
});

test("Hex Radio fits a phone (AC10)", async ({ browser }) => {
  const user = await newSignedInUser(browser, "rdph");
  const phone = await user.ctx.newPage();
  await phone.setViewportSize({ width: 390, height: 844 });

  try {
    await answerStreams(phone);
    await phone.goto("/");
    await phone.waitForFunction(
      () =>
        !!document
          .querySelector("[data-phx-main]")
          ?.classList.contains("phx-connected"),
    );
    const input = phone.getByTestId("chat-input-field");
    await input.fill("/radio");
    await input.press("Enter");
    const radio = phone.getByTestId("radio-window");
    await expect(radio).toBeVisible();
    await expect(radio).toBeInViewport({ ratio: 0.95 });
    await phone.getByTestId("hex-radio-station-e2e-pixel").click();
    await expect(phone.getByTestId("hex-radio-status-state")).toHaveText(
      "Playing",
    );
    await expect(phone.getByTestId("hex-radio-play")).toBeInViewport();
    await expect(
      phone.getByTestId("hex-radio-station-e2e-pixel"),
    ).toBeInViewport();
    await shot(phone, "hex radio on a phone");
  } finally {
    await closeUsers([user]);
  }
});
