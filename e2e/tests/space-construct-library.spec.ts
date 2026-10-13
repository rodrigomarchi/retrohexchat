/**
 * @section SP - Virtual Spaces
 * @flow SP27 [done] A long table covers two tiles and turns with its footprint; chairs set around it are sat in, and a room of each theme (home, office, garden, gamer) is built from the palette's tabs
 * @flow SP28 [done] The End of Time's own pieces — Morpheus, Neo, the old TV, the DeLorean, the Balrog — are placed in a Construct, animated and lit as on the island
 * @flow SP29 [done] A sofa seats two people at once, one on each of its tiles
 * @flow SP36 [done] A fair and a fantasy corner are built from their own tabs — tents, stalls, Leene's Bell, the Telepod, Nu, braziers and arches, some of them moving; the End of Time's lamppost and the Victorian lamp switch off, and the wingback chair is sat in
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect, Page } from "@playwright/test";
import {
  newSignedInUser,
  closeUsers,
  uniqueChannel,
  TestUser,
} from "../helpers/chatUsers";
import { shot } from "../helpers/screenshots";
import {
  openConstruct,
  RoomWatch,
  tilePoint,
  chooseInMenu,
  closeBuildMenu,
  drawerSettled,
  openBuildMenu,
} from "../helpers/construct";
import { Walker } from "../director/space";

type Spot = { x: number; y: number };

async function inChannel(users: TestUser[], prefix: string) {
  const channel = uniqueChannel(prefix);
  for (const user of users) await user.chat.sendMessage(`/join ${channel}`);
  return channel;
}

/** Place one piece from its tab with its corner on `tile`, turned `turns` times. */
async function place(
  space: Page,
  walker: Walker,
  room: RoomWatch,
  tab: string,
  kind: string,
  tile: Spot,
  turns = 0,
) {
  const before = room.items.length;
  const self = await walker.here();
  await chooseInMenu(space, tab, { kind });
  for (let i = 0; i < turns; i += 1) await space.keyboard.press("r");
  const at = await tilePoint(space, self, tile);
  await space.mouse.click(at.x, at.y);
  await space.keyboard.press("Escape");
  await expect.poll(() => room.items.length).toBe(before + 1);
  // Edits are paced per person; the next one waits its turn.
  await space.waitForTimeout(150);
}

/** Lay out a themed corner of the room, every piece offset from `o`. */
async function furnish(
  space: Page,
  walker: Walker,
  room: RoomWatch,
  tab: string,
  o: Spot,
  pieces: [string, number, number, number?][],
) {
  for (const [kind, dx, dy, turns] of pieces) {
    await place(
      space,
      walker,
      room,
      tab,
      kind,
      { x: o.x + dx, y: o.y + dy },
      turns ?? 0,
    );
  }
}

test.describe("The Construct's library", () => {
  test("a long table, chairs around it, and a room of every theme (SP27)", async ({
    browser,
  }) => {
    // Three dozen pieces, each taken from the Build menu: a long walk.
    test.setTimeout(120_000);
    const host = await newSignedInUser(browser, "lt");
    try {
      await inChannel([host], "lt");
      const { space, walker, room } = await openConstruct(host, "cleric");
      const self = await walker.here();

      // The long table runs down the y axis; turned, it runs down x.
      const corner = { x: self.x + 3, y: self.y + 2 };
      await place(space, walker, room, "furniture", "long_table", corner);
      const table = room.items.find((i) => i.kind === "long_table")!;
      expect(table.dir).toBe("down");
      await place(space, walker, room, "furniture", "chair", {
        x: corner.x - 1,
        y: corner.y,
      });
      await place(space, walker, room, "furniture", "chair", {
        x: corner.x - 1,
        y: corner.y + 1,
      });
      await place(
        space,
        walker,
        room,
        "furniture",
        "chair",
        { x: corner.x + 1, y: corner.y },
        1,
      );
      await place(
        space,
        walker,
        room,
        "furniture",
        "chair",
        { x: corner.x + 1, y: corner.y + 1 },
        1,
      );
      await shot(space, "construct-long-table-and-chairs");

      // Sit at the table, on the chair beside its far end.
      await walker.goTo({ x: corner.x - 2, y: corner.y + 1 });
      await space.keyboard.press("f");
      await expect.poll(async () => (await walker.here()).pose).toBe("sitting");
      await space.keyboard.press("f");

      await furnish(
        space,
        walker,
        room,
        "furniture",
        { x: self.x + 7, y: self.y + 2 },
        [
          ["sofa", 0, 0],
          ["coffee_table", 2, 0],
          ["tv_stand", 4, 0],
          ["fireplace", 0, 3],
          ["bookshelf", 2, 3],
          ["table_lamp", 3, 3],
          ["bed", 5, 3],
        ],
      );
      await shot(space, "construct-room-home");

      await furnish(
        space,
        walker,
        room,
        "office",
        { x: self.x + 2, y: self.y + 7 },
        [
          ["office_desk", 0, 0],
          ["office_chair", 1, 0, 1],
          ["office_desk", 3, 0],
          ["office_chair", 4, 0, 1],
          ["water_cooler", 6, 0],
          ["file_cabinet", 0, 3],
          ["printer", 1, 3],
          ["whiteboard", 3, 3],
          ["vending_machine", 5, 3],
        ],
      );
      await shot(space, "construct-room-office");

      await furnish(
        space,
        walker,
        room,
        "garden",
        { x: self.x + 2, y: self.y + 13 },
        [
          ["fountain", 2, 0],
          ["park_bench", 0, 0],
          ["street_lamp", 5, 0],
          ["palm_tree", 7, 0],
          ["flower_bed", 0, 3],
          ["bush", 1, 3],
          ["pond", 3, 3],
          ["pine_tree", 6, 3],
        ],
      );
      await shot(space, "construct-room-garden");

      await furnish(
        space,
        walker,
        room,
        "gamer",
        { x: self.x + 12, y: self.y + 8 },
        [
          ["pool_table", 0, 0],
          ["ping_pong_table", 3, 0],
          ["racing_arcade", 6, 0],
          ["jukebox", 7, 0],
          ["beanbag", 0, 3],
          ["gaming_chair", 1, 3],
          ["retro_console", 2, 3],
          ["neon_sign", 4, 3],
          ["cryo_pod", 6, 3],
        ],
      );
      await shot(space, "construct-room-gamer");
    } finally {
      await closeUsers([host]);
    }
  });

  test("the End of Time's pieces, in a Construct (SP28)", async ({
    browser,
  }) => {
    const host = await newSignedInUser(browser, "le");
    try {
      await inChannel([host], "le");
      const { space, walker, room } = await openConstruct(host, "knight");
      const self = await walker.here();

      await furnish(
        space,
        walker,
        room,
        "eot",
        { x: self.x + 3, y: self.y + 2 },
        [
          ["eot_morpheus", 0, 0],
          ["eot_tv", 3, -1],
          ["eot_neo", 6, 0],
          ["eot_fire", 0, 4],
          ["eot_gandalf", 2, 4],
          ["eot_goku", 4, 4],
          ["eot_delorean", 0, 7],
          ["eot_balrog", 6, 6],
        ],
      );
      expect(room.items.map((i) => i.kind)).toContain("eot_delorean");
      await shot(space, "construct-end-of-time");
    } finally {
      await closeUsers([host]);
    }
  });

  test("a sofa seats two people at once (SP29)", async ({ browser }) => {
    const host = await newSignedInUser(browser, "ls");
    const guest = await newSignedInUser(browser, "lg");
    try {
      await inChannel([host, guest], "ls");
      const a = await openConstruct(host, "monk");
      const b = await openConstruct(guest, "archer");
      const self = await a.walker.here();

      // The sofa covers (x, y) and (x, y+1); each sits from a tile next to
      // one seat only, so neither can pick the other's.
      const sofa = { x: self.x + 4, y: self.y + 3 };
      await place(a.space, a.walker, a.room, "furniture", "sofa", sofa);

      await a.walker.goTo({ x: sofa.x - 1, y: sofa.y - 1 });
      await a.space.keyboard.press("f");
      await b.walker.goTo({ x: sofa.x - 1, y: sofa.y + 2 });
      await b.space.keyboard.press("f");

      await expect
        .poll(async () => (await a.walker.here()).pose)
        .toBe("sitting");
      await expect
        .poll(async () => (await b.walker.here()).pose)
        .toBe("sitting");
      const [ah, bh] = [await a.walker.here(), await b.walker.here()];
      expect(new Set([`${ah.x},${ah.y}`, `${bh.x},${bh.y}`])).toEqual(
        new Set([`${sofa.x},${sofa.y}`, `${sofa.x},${sofa.y + 1}`]),
      );
      await shot(a.space, "construct-sofa-two");
    } finally {
      await closeUsers([host, guest]);
    }
  });

  test("a fair, a fantasy corner and the island's lamppost (SP36)", async ({
    browser,
  }) => {
    test.setTimeout(120_000);
    const host = await newSignedInUser(browser, "lf");
    try {
      await inChannel([host], "lf");
      const { space, walker, room } = await openConstruct(host, "sorceress");
      const self = await walker.here();

      await openBuildMenu(space);
      await space.getByTestId("construct-tab-fantasy").click();
      await drawerSettled(space);
      await shot(space, "construct-fantasy-tab");
      await closeBuildMenu(space);

      await furnish(
        space,
        walker,
        room,
        "fair",
        { x: self.x + 3, y: self.y + 2 },
        [
          ["big_top", 0, 0],
          ["fortune_tent", 3, 0],
          ["striped_tent", 6, 0],
          ["pennant_tent", 7, 0],
          ["weapon_stall", 0, 4],
          ["snack_stall", 2, 4],
          ["bunting", 4, 4],
          ["paper_lantern", 5, 4],
          ["splash_fountain", 7, 4],
          ["fair_bench", 0, 7],
          ["crates", 1, 7],
          ["flag_pole", 3, 7],
          ["hedge", 4, 7],
          ["potted_tree", 5, 7],
        ],
      );
      await shot(space, "construct-room-fair");

      // The fantasy corner is built off to the right, where the camera follows.
      const there = { x: self.x + 12, y: self.y };
      await walker.goTo(there);
      const lamp = { x: there.x + 6, y: there.y - 1 };
      await furnish(
        space,
        walker,
        room,
        "fantasy",
        { x: there.x + 2, y: there.y + 2 },
        [
          ["bell_tower", 0, 0],
          ["telepod", 3, 0],
          ["nu", 5, 0],
          ["brazier", 0, 3],
          ["stone_arch", 2, 3],
          ["glowing_arch", 4, 3],
          ["brazier", 6, 3],
          ["ancient_gate", 0, 6],
          ["magic_portal", 4, 6],
          ["stone_column", 6, 6],
        ],
      );
      await place(space, walker, room, "fantasy", "eot_lamp", lamp);
      await shot(space, "construct-room-fantasy");

      // The island's lamppost is a lamp like any other here.
      await walker.goTo({ x: lamp.x - 1, y: lamp.y });
      await space.keyboard.press("e");
      await expect
        .poll(
          () =>
            room.items.find((i) => i.x === lamp.x && i.y === lamp.y)?.state?.on,
        )
        .toBe(false);
      await shot(space, "construct-lamppost-off");

      // So does the Victorian one in the garden tab, and the wingback chair
      // in the furniture tab is sat in.
      const iron = { x: there.x + 2, y: there.y - 1 };
      await place(space, walker, room, "garden", "victorian_lamp", iron);
      await walker.goTo({ x: iron.x, y: iron.y + 1 });
      await space.keyboard.press("e");
      await expect
        .poll(
          () =>
            room.items.find((i) => i.x === iron.x && i.y === iron.y)?.state?.on,
        )
        .toBe(false);
      const chair = { x: there.x - 2, y: there.y - 1 };
      await place(space, walker, room, "furniture", "wingback_chair", chair);
      await walker.goTo({ x: chair.x - 1, y: chair.y });
      await space.keyboard.press("f");
      await expect.poll(async () => (await walker.here()).pose).toBe("sitting");
      await shot(space, "construct-wingback-and-victorian-lamp");
    } finally {
      await closeUsers([host]);
    }
  });
});
