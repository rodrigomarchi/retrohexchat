/**
 * @section SP - Virtual Spaces
 * @flow SP42 [done] The Game Room's neon door stands beside the Office's wooden door: it lights up in reach, asks before going, and opens a furnished room whose arcade cabinets list the games, whose furniture cannot be picked up, where a piece can still be added, and whose own neon door leads back
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect } from "@playwright/test";
import {
  newSignedInUser,
  closeUsers,
  uniqueChannel,
} from "../helpers/chatUsers";
import { shot } from "../helpers/screenshots";
import { Walker } from "../director/space";
import {
  BEFORE_GAME_ROOM,
  RoomWatch,
  chooseInMenu,
  mapDrawn,
  openBuildMenu,
  closeBuildMenu,
  tilePoint,
  walkIn,
} from "../helpers/construct";
import { recipeOf } from "../helpers/characters";

// Game Room tiles, from `virtual.space/tools/author_game_room.py`: the first
// arcade cabinet of the row and the tile in front of it, the pool table, a
// clear spot in the middle, and the tile inside its door.
const CABINET = { x: 11, y: 8 };
const BEFORE_CABINET = { x: 11, y: 9 };
const POOL_TABLE = { x: 13, y: 17 };
const CLEAR = { x: 21, y: 20 };
const INSIDE_DOOR = { x: 9, y: 12 };

test.describe("The Game Room", () => {
  test("its neon door leads to a room of arcade cabinets that takes new pieces (SP42)", async ({
    browser,
  }) => {
    const host = await newSignedInUser(browser, "gr");
    try {
      const channel = uniqueChannel("gr");
      await host.chat.sendMessage(`/join ${channel}`);
      const space = await host.chat.openSpace();
      const walker = Walker.follow(space);
      const room = RoomWatch.follow(space);
      await walkIn(space, "ranger");

      // Beside the door the hand button lights up, and E asks first.
      const use = space.getByTestId("space-pad-use");
      await walker.goTo(BEFORE_GAME_ROOM);
      await expect(use).toHaveAttribute("data-ready", "");
      await shot(space, "game-room-door-in-reach");
      await space.keyboard.press("e");
      const modal = space.getByTestId("space-modal");
      await expect(modal).toContainText("game room");
      await space.getByTestId("space-modal-yes").click();
      await expect(space).toHaveURL(/\?avatar=/, { timeout: 15_000 });
      await mapDrawn(space);

      const shell = space.getByTestId("channel-space-shell");
      await expect(shell).toHaveAttribute("data-space-mode", "construct");
      await expect(shell).toHaveAttribute("data-avatar", recipeOf("ranger"));
      await expect
        .poll(() => room.items.filter((i) => i.fixed).length)
        .toBeGreaterThan(30);
      expect(
        room.items.find((i) => i.x === CABINET.x && i.y === CABINET.y)?.kind,
      ).toBe("arcade");
      await shot(space, "game-room-furnished");

      // The Build menu opens on the gamer pieces.
      await openBuildMenu(space);
      await expect(space.getByTestId("construct-tab-gamer")).toHaveAttribute(
        "data-selected",
        "true",
      );
      await expect(
        space.getByTestId("construct-kind-pool_table"),
      ).toBeVisible();
      await shot(space, "game-room-build-menu");
      await closeBuildMenu(space);

      // The furniture the room comes with is never picked up.
      const self = await walker.here();
      const table = await tilePoint(space, self, POOL_TABLE, "game_room");
      await space.mouse.click(table.x, table.y);
      await expect(space.getByTestId("construct-holding")).toBeHidden();

      // A piece of anybody's is placed among it.
      await chooseInMenu(space, "gamer", { kind: "beanbag" });
      const clear = await tilePoint(space, self, CLEAR, "game_room");
      await space.mouse.click(clear.x, clear.y);
      await expect
        .poll(() =>
          room.items.some(
            (i) =>
              i.kind === "beanbag" &&
              !i.fixed &&
              i.x === CLEAR.x &&
              i.y === CLEAR.y,
          ),
        )
        .toBe(true);
      await space.keyboard.press("Escape");
      await shot(space, "game-room-piece-added");

      // An arcade cabinet lists the games.
      await walker.goTo(BEFORE_CABINET);
      await space.keyboard.press("e");
      const doom = space.getByTestId("space-panel-game-doom_shareware");
      await expect(doom).toHaveAttribute("href", "/play/arcade/doom_shareware");
      await shot(space, "game-room-arcade");
      await space.keyboard.press("Escape");

      // The neon door leads back to the End of Time.
      await walker.goTo(INSIDE_DOOR);
      await space.keyboard.press("e");
      await expect(modal).toContainText("End of Time");
      await space.getByTestId("space-modal-yes").click();
      await expect(space.getByTestId("construct-palette")).toBeHidden({
        timeout: 15_000,
      });
      await mapDrawn(space);
      await expect(shell).toHaveAttribute("data-space-mode", "channel");
    } finally {
      await closeUsers([host]);
    }
  });
});
