/**
 * Captures the pictures of the public Spaces page (`/spaces`): the End of
 * Time's island with people talking on it, the character creator, the
 * Construct with its Build menu, the Game Room and the Office.
 *
 *   make spaces.shots
 *
 * Not a test: it runs only under `make spaces.shots` (the `capture` project of
 * `playwright.config.ts`), against the local e2e server, with throwaway
 * nicknames in a channel of its own. Every picture is the real space as a
 * member sees it, at the desktop's 1280x720, so the page never shows art the
 * product does not draw.
 *
 * Each picture is written at full size and halved to the pixel (`-half`), the
 * copy a grid of thumbnails loads — pixel art scaled by anything but a whole
 * number smears. The island is also the share card, `og/spaces.jpg`, cut from
 * its centre at 1200x630 rather than scaled, for the same reason.
 * `manifest.json` records each size, and the page reads it at compile time.
 *
 * Writes `apps/retro_hex_chat_web/priv/static/images/spaces/`.
 */
import { mkdirSync, writeFileSync } from "node:fs";
import path from "node:path";
import { BrowserContext, expect, Page, test } from "@playwright/test";
import {
  closeUsers,
  newSignedInUser,
  uniqueChannel,
} from "../helpers/chatUsers";
import { buildCharacter } from "../helpers/characters";
import {
  BEFORE_GAME_ROOM,
  BEFORE_OFFICE,
  RoomWatch,
  enterConstruct,
  enterRoom,
  mapDrawn,
  openBuildMenu,
  walkIn,
} from "../helpers/construct";
import { Walker } from "../director/space";
import { sortKeys, toCard, toWebp } from "../scripts/lib/images.mjs";

const OUT_DIR = path.resolve(
  __dirname,
  "../../apps/retro_hex_chat_web/priv/static/images/spaces",
);
const WEBP_QUALITY = 0.85;
const CARD = { width: 1200, height: 630, quality: 0.85 };

type Picture = { width: number; height: number };
const manifest: Record<string, Picture> = {};

test("captures the pictures of the Spaces page", async ({ browser }) => {
  test.setTimeout(5 * 60_000);
  mkdirSync(path.join(OUT_DIR, "og"), { recursive: true });

  const ana = await newSignedInUser(browser, "spa");
  const beto = await newSignedInUser(browser, "spb");
  const cid = await newSignedInUser(browser, "spc");

  try {
    const channel = uniqueChannel("sp");
    for (const user of [ana, beto, cid]) {
      await user.chat.sendMessage(`/join ${channel}`);
    }

    // Each page is followed from before it walks in: the walker learns where
    // it stands from the frames of its arrival, and the room watch what is in
    // the room.
    const anaSpace = await ana.chat.openSpace();
    const anaWalker = Walker.follow(anaSpace);
    RoomWatch.follow(anaSpace);

    // The creator, a character half made, before anybody walks in.
    await buildCharacter(anaSpace, "mage");
    await save(anaSpace, "creator");
    await anaSpace.getByTestId("space-creator-enter").click();
    await mapDrawn(anaSpace);

    // The island, three people on it and one of them talking.
    const [betoSpace, betoWalker, betoRoom] = await follow(beto.ctx);
    await betoSpace.goto(anaSpace.url());
    await walkIn(betoSpace, "ranger");
    const [cidSpace, cidWalker, cidRoom] = await follow(cid.ctx);
    await cidSpace.goto(anaSpace.url());
    await walkIn(cidSpace, "bard");

    // Apart, so every face and name shows and the bubble covers nobody. On
    // the isometric map a step in x and one back in y is a step sideways.
    const arrival = await betoWalker.here();
    await betoWalker.goTo({ x: arrival.x + 1, y: arrival.y + 2 });
    await anaWalker.goTo({ x: arrival.x - 3, y: arrival.y + 3 });
    await cidWalker.goTo({ x: arrival.x + 3, y: arrival.y });
    await betoWalker.say("Anyone for the Game Room?");
    await expect(cidSpace.getByTestId("space-said")).toContainText(
      "Anyone for the Game Room?",
    );
    const island = await save(cidSpace, "island");
    writeFileSync(
      path.join(OUT_DIR, "og", "spaces.jpg"),
      await toCard(cidSpace, island, { ...CARD, fit: "crop" }),
    );
    manifest["og/spaces"] = { width: CARD.width, height: CARD.height };

    // Through the gate: the Construct and its Build menu.
    await enterConstruct(anaWalker);
    await openBuildMenu(anaSpace);
    await save(anaSpace, "construct");

    // Through the neon door and the wooden one, each room once its furniture
    // has arrived over the socket.
    await enterRoom(betoWalker, BEFORE_GAME_ROOM);
    await furnished(betoRoom);
    await save(betoSpace, "game_room");

    await enterRoom(cidWalker, BEFORE_OFFICE);
    await furnished(cidRoom);
    await save(cidSpace, "office");

    writeFileSync(
      path.join(OUT_DIR, "manifest.json"),
      JSON.stringify(sortKeys(manifest), null, 2) + "\n",
    );
  } finally {
    await closeUsers([ana, beto, cid]);
  }
});

async function follow(ctx: BrowserContext): Promise<[Page, Walker, RoomWatch]> {
  const space = await ctx.newPage();
  return [space, Walker.follow(space), RoomWatch.follow(space)];
}

// A furnished room comes with dozens of pieces it cannot lose.
async function furnished(room: RoomWatch) {
  await expect
    .poll(() => room.items.filter((item) => item.fixed).length, {
      timeout: 15_000,
    })
    .toBeGreaterThan(30);
}

// The page as a member sees it, at full size and halved, recorded in the
// manifest; the full one is returned for the share card.
async function save(space: Page, name: string): Promise<Buffer> {
  await space.mouse.move(0, 0);
  const png = await space.screenshot();
  const full = await toWebp(space, png, { quality: WEBP_QUALITY });
  const half = await toWebp(space, png, {
    quality: WEBP_QUALITY,
    maxWidth: full.width / 2,
    smooth: false,
  });

  writeFileSync(path.join(OUT_DIR, `${name}.webp`), full.webp);
  writeFileSync(path.join(OUT_DIR, `${name}-half.webp`), half.webp);
  manifest[name] = { width: full.width, height: full.height };
  console.log(
    `${name}: ${full.width}x${full.height}, ${Math.round(full.webp.length / 1024)} KB, ` +
      `half ${Math.round(half.webp.length / 1024)} KB`,
  );
  return full.webp;
}
