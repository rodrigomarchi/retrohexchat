/**
 * @section SP - Virtual Spaces
 * @flow SP41 [done] The Office's wooden door stands south of where people arrive: it lights up in reach, asks before going, and opens a furnished room whose furniture cannot be picked up, where a piece can still be added, and whose own door leads back
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
  BEFORE_OFFICE,
  RoomWatch,
  chooseInMenu,
  mapDrawn,
  openBuildMenu,
  closeBuildMenu,
  tilePoint,
  walkIn,
} from "../helpers/construct";
import { recipeOf } from "../helpers/characters";

// Office tiles, from `virtual.space/tools/author_office.py`: the reception
// desk the room comes with, a clear spot in the middle, and the tile inside
// its door.
const RECEPTION_DESK = { x: 11, y: 17 };
const CLEAR = { x: 18, y: 16 };
const INSIDE_DOOR = { x: 9, y: 12 };

test.describe("The Office", () => {
  test("its door leads to a furnished room that takes new pieces and keeps its own (SP41)", async ({
    browser,
  }) => {
    const host = await newSignedInUser(browser, "of");
    try {
      const channel = uniqueChannel("of");
      await host.chat.sendMessage(`/join ${channel}`);
      const space = await host.chat.openSpace();
      const walker = Walker.follow(space);
      const room = RoomWatch.follow(space);
      await walkIn(space, "ranger");

      // Beside the door the hand button lights up, and E asks first.
      const use = space.getByTestId("space-pad-use");
      await walker.goTo(BEFORE_OFFICE);
      await expect(use).toHaveAttribute("data-ready", "");
      await shot(space, "office-door-in-reach");
      await space.keyboard.press("e");
      const modal = space.getByTestId("space-modal");
      await expect(modal).toContainText("office");
      await space.getByTestId("space-modal-yes").click();
      await expect(space).toHaveURL(/\?avatar=/, { timeout: 15_000 });
      await mapDrawn(space);

      const shell = space.getByTestId("channel-space-shell");
      await expect(shell).toHaveAttribute("data-space-mode", "construct");
      await expect(shell).toHaveAttribute("data-avatar", recipeOf("ranger"));
      await expect
        .poll(() => room.items.filter((i) => i.fixed).length)
        .toBeGreaterThan(40);
      await shot(space, "office-furnished");

      // The Build menu opens on the Office's own pieces.
      await openBuildMenu(space);
      await expect(space.getByTestId("construct-tab-office")).toHaveAttribute(
        "data-selected",
        "true",
      );
      await expect(
        space.getByTestId("construct-kind-reception_desk"),
      ).toBeVisible();
      await shot(space, "office-build-menu");
      await closeBuildMenu(space);

      // The furniture the room comes with is never picked up.
      const self = await walker.here();
      const desk = await tilePoint(space, self, RECEPTION_DESK, "office");
      await space.mouse.click(desk.x, desk.y);
      await expect(space.getByTestId("construct-holding")).toBeHidden();

      // A piece of anybody's is placed among it.
      await chooseInMenu(space, "office", { kind: "tall_plant" });
      const clear = await tilePoint(space, self, CLEAR, "office");
      await space.mouse.click(clear.x, clear.y);
      await expect
        .poll(() =>
          room.items.some(
            (i) =>
              i.kind === "tall_plant" &&
              !i.fixed &&
              i.x === CLEAR.x &&
              i.y === CLEAR.y,
          ),
        )
        .toBe(true);
      await space.keyboard.press("Escape");
      await shot(space, "office-piece-added");

      // The door in the back wall leads back to the End of Time.
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
