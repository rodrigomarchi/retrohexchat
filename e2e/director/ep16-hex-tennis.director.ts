/**
 * Director — EP16, "Hex Tennis: the lightning tournament".
 *
 * Films the episode's scenes for the YouTube channel. Not a test: nothing here
 * guards a behaviour, and it never runs with the suite. The script, narration
 * and timing live in `retro_hex_chat_videos/episodes/16-hex-tennis/script.md`;
 * every beat is a flow a spec in `e2e/tests/` already proves — its ID is in
 * the script (game-hex-tennis.spec.ts: N114, N115).
 *
 * A knockout tournament in #hex-tennis, in Sudden Death: Pixel against
 * kestrel and nova against lumen, each semifinal made with Find a partner on
 * the home's Sudden Death row, and the two winners in a final made the same
 * way. bytebard runs the draw in the channel and is never filmed.
 *
 * Every match is really played: each seat's keys are pressed by the game's own
 * computer player (`autopilot`), all at hard. Who wins a semifinal decides who
 * plays the final, so the final's scenes film whichever two players won. A
 * scene during a match fails, to be retaken, if the match ends before it does.
 *
 * Filmed in the order 1, 2, 3, 4, 5, 6, 7, 0, 8: the draw and the home before
 * any match, each semifinal while it is played, the cards once both are over,
 * the final made, the cold open while it is on, and its end.
 *
 * Each scene puts, off camera, what it needs in place — the matches before it
 * played out — so any one of them can be retaken alone.
 *
 *   make e2e.director SHOTS=/abs/shots.json OUT=/abs/takes FRESH=1
 */
import { Browser, expect, Page, test } from "@playwright/test";
import { TestUser } from "../helpers/chatUsers";
import { waitForView } from "../helpers/liveView";
import { ChatPage } from "../pages/ChatPage";
import { ConnectPage } from "../pages/ConnectPage";
import { Cast, Line } from "./cast";
import {
  cameraContext,
  filmCrew,
  pointAt,
  restCursor,
  shotFor,
  turnTipsOff,
} from "./shots";
import {
  autopilot,
  bothReady,
  enterRoom,
  matchCanvas,
  offerSeat,
  provisionGameChannel,
  startMatch,
  way,
} from "./retro_games";

const PASSWORD = "retro1998";
const GAME = "hex_tennis";
const WAY = "hex_tennis_sudden";
const CHANNEL = "#hex-tennis";
const HOME = "/games/hex-tennis";

const PIXEL = "Pixel";
const KESTREL = "kestrel";
const NOVA = "nova";
const LUMEN = "lumen";
const BYTEBARD = "bytebard";

const EARLIER: Line[] = [
  { by: BYTEBARD, says: "lightning tournament tonight, sudden death!" },
  { by: NOVA, says: "count me in" },
  { by: LUMEN, says: "me too, first to six?" },
];

/** How long a Sudden Death match between two hard players may take, and some to spare. */
const MATCH_TIMEOUT = 4 * 60_000;

type Person = TestUser;
type Rooms = { host: Page; guest: Page };
type Match = {
  host: Person;
  guest: Person;
  rooms: Rooms | null;
  winner: Person | null;
  loser: Person | null;
};

test.describe.configure({ mode: "serial" });

test.describe("EP16 Hex Tennis", () => {
  let cast: Cast;
  const people: Record<string, Person> = {};
  const semis: Match[] = [];
  let final: Match | null = null;

  test.beforeAll(async ({ browser }) => {
    test.setTimeout(10 * 60_000);
    cast = await Cast.assemble(browser, [BYTEBARD], PASSWORD);
    // bytebard founds the game's channel, by a match in the ledger.
    await provisionGameChannel(
      cast.member(BYTEBARD).page.request,
      GAME,
      BYTEBARD,
      { p1: 6, p2: 4 },
    );
    const zones: Record<string, string> = {
      [PIXEL]: "Europe/Lisbon",
      [KESTREL]: "America/Chicago",
      [NOVA]: "Europe/Berlin",
      [LUMEN]: "America/Sao_Paulo",
    };
    for (const [nick, zone] of Object.entries(zones)) {
      people[nick] = await person(browser, nick, zone);
      await autopilot(people[nick].ctx, "hard");
      cast.adopt(people[nick]);
    }
    semis.push(newMatch(people[PIXEL], people[KESTREL]));
    semis.push(newMatch(people[NOVA], people[LUMEN]));
    for (const who of [cast.member(BYTEBARD), ...Object.values(people)]) {
      await inTheChannel(who);
    }
    await cast.play(EARLIER);
  });

  test.afterAll(async () => {
    await cast?.dismiss();
  });

  const newMatch = (host: Person, guest: Person): Match => ({
    host,
    guest,
    rooms: null,
    winner: null,
    loser: null,
  });

  /** Off camera: in the channel at its own address, the restore run. */
  async function inTheChannel(who: TestUser) {
    await who.page.goto(`/c/${CHANNEL.slice(1)}`);
    await who.chat.waitUntilConnected();
    await who.page.waitForTimeout(1500);
    await expect(who.chat.chatInput).toHaveAttribute(
      "placeholder",
      new RegExp(CHANNEL),
    );
  }

  /** Someone on film: a camera browser, signed in, tips off. */
  async function person(
    browser: Browser,
    nick: string,
    timezoneId: string,
  ): Promise<Person> {
    const ctx = await cameraContext(browser, nick, { timezoneId });
    const page = await ctx.newPage();
    const connect = new ConnectPage(page);
    const chat = new ChatPage(page);
    await connect.open();
    await connect.signIn(nick, PASSWORD);
    await chat.waitUntilConnected();
    await turnTipsOff(page, nick);
    await chat.waitUntilConnected();
    return { nick, chat, connect, page, ctx, password: PASSWORD };
  }

  /** Off camera: every tab but the chat closed, the chat in front, in the channel. */
  async function onlyTheChat(who: Person) {
    for (const tab of who.ctx.pages()) {
      if (tab !== who.page) await tab.close();
    }
    await who.page.bringToFront();
    await inTheChannel(who);
    await restCursor(who.page);
  }

  /** Off camera: `who`'s chat with the game's home open over it. */
  async function homeOpen(who: Person) {
    await onlyTheChat(who);
    await who.page.goto(HOME);
    await expect(who.page.getByTestId("game-home")).toBeVisible();
    await waitForView(who.page);
    await who.page.waitForTimeout(1000);
    await restCursor(who.page);
  }

  const findAPartner = (who: Person) =>
    way(who.page, WAY).getByTestId("game-lfg");

  /** The seat's card on `who`'s screen. */
  const seatCard = (who: Person, address: string) =>
    who.page
      .locator(`[data-testid="share-message-enter"][href="${address}"]`)
      .last();

  /** Scoreboard's card of `match`, on `who`'s chat. */
  const resultCard = (who: Person, match: Match) =>
    who.page
      .locator('[data-testid^="game-result-card-"]')
      .filter({ hasText: match.host.nick })
      .filter({ hasText: match.guest.nick })
      .last();

  /** Whether `match` is being played in rooms that are open. */
  async function on(match: Match): Promise<boolean> {
    const rooms = match.rooms;
    if (!rooms || rooms.host.isClosed() || rooms.guest.isClosed()) return false;
    return !(await rooms.host.getByTestId("lobby-game-result").isVisible());
  }

  /** Off camera: `match` made with Find a partner, entered, started, past its countdown. */
  async function make(match: Match): Promise<Rooms> {
    await onlyTheChat(match.guest);
    await homeOpen(match.host);
    const { address } = await offerSeat(
      match.host.page,
      findAPartner(match.host),
      match.host.nick,
    );
    const host = await enterRoom(match.host.page, match.host.ctx, address);
    await expect(seatCard(match.guest, address)).toBeVisible({
      timeout: 15_000,
    });
    const guest = await enterRoom(match.guest.page, match.guest.ctx, address);
    await bothReady(host, guest);
    await startMatch(host, guest, WAY);
    match.rooms = { host, guest };
    await host.waitForTimeout(5_000);
    return match.rooms;
  }

  /** Off camera: `match` played to its end, however long it takes; who won. */
  async function result(match: Match): Promise<void> {
    if (match.winner) return;
    if (!(await on(match)) && !match.rooms) await make(match);
    const { host, guest } = match.rooms!;
    for (const room of [host, guest]) {
      await expect(room.getByTestId("lobby-game-result")).toBeVisible({
        timeout: MATCH_TIMEOUT,
      });
    }
    const outcome = await host.getByTestId("lobby-game-outcome").textContent();
    const hostWon = outcome?.trim() === "You win!";
    match.winner = hostWon ? match.host : match.guest;
    match.loser = hostWon ? match.guest : match.host;
  }

  /** Off camera: the session the match was played in ended, its rooms closed. */
  async function close(match: Match) {
    const rooms = match.rooms;
    if (!rooms) return;
    if (!rooms.host.isClosed()) {
      await rooms.host.getByTestId("p2p-console-end-session").click();
      await rooms.host.getByTestId("p2p-confirm-dialog-confirm").click();
      await rooms.host.waitForTimeout(1_000);
      await rooms.host.close();
    }
    if (!rooms.guest.isClosed()) await rooms.guest.close();
    match.rooms = null;
  }

  /** Off camera: `match` over and closed, every match before it too. */
  async function done(match: Match) {
    for (const earlier of [...semis, final]) {
      if (!earlier) continue;
      await result(earlier);
      await close(earlier);
      if (earlier === match) return;
    }
  }

  /** Off camera: every semifinal over, and the final's pairing set. */
  async function finalists(): Promise<Match> {
    for (const semi of semis) await done(semi);
    final ??= newMatch(semis[0].winner!, semis[1].winner!);
    return final;
  }

  /** Off camera: `match` being played, every match before it over. */
  async function playing(match: Match): Promise<Rooms> {
    if (await on(match)) return match.rooms!;
    const before =
      match === final ? semis : semis.slice(0, semis.indexOf(match));
    for (const earlier of before) await done(earlier);
    await close(match);
    match.winner = null;
    return make(match);
  }

  /** A scene during `match` must end with it still on. */
  async function stillOn(match: Match, scene: string) {
    if (!(await on(match))) {
      throw new Error(`the match ended during scene ${scene}: retake it`);
    }
  }

  /** A scene of `match` on both screens, while it is played. */
  async function onCourt(scene: number, match: Match, cues: string[]) {
    const shot = shotFor(scene);
    test.setTimeout(3 * MATCH_TIMEOUT + 4 * 60_000);
    const { host, guest } = await playing(match);
    await host.bringToFront();
    await restCursor(host);
    await restCursor(guest);
    await filmCrew(
      { [match.host.nick]: host, [match.guest.nick]: guest },
      shot,
      async ({ cue, focus }) => {
        await focus(matchCanvas(host, WAY));
        await cue(cues[0]);
        await focus(matchCanvas(guest, WAY));
        await cue(cues[1]);
        await focus(matchCanvas(host, WAY));
        await stillOn(match, String(scene));
      },
      { kind: "split", cameras: [match.host.nick, match.guest.nick] },
    );
  }

  /**
   * Scenes 3 and 7: `match` made on camera — the host's Find a partner, the
   * guest's Join from the channel, both ready, Start.
   */
  async function madeOnCamera(scene: number, match: Match, cues: string[]) {
    const shot = shotFor(scene);
    const { host: hostPerson, guest: guestPerson } = match;
    await close(match);
    match.winner = null;
    await onlyTheChat(guestPerson);
    await homeOpen(hostPerson);
    await findAPartner(hostPerson).scrollIntoViewIfNeeded();
    let host: Page | null = null;
    let guest: Page | null = null;
    await filmCrew(
      {
        [hostPerson.nick]: hostPerson.page,
        [guestPerson.nick]: guestPerson.page,
      },
      shot,
      async ({ cue, focus, follow, layout, pace }) => {
        await pace(300);
        await focus(way(hostPerson.page, WAY));
        await cue(cues[0]);
        await pointAt(hostPerson.page, findAPartner(hostPerson));
        const { card, address } = await offerSeat(
          hostPerson.page,
          findAPartner(hostPerson),
          hostPerson.nick,
        );
        await restCursor(hostPerson.page);
        await focus(card);
        await pointAt(hostPerson.page, card.getByTestId("share-message-enter"));
        host = await enterRoom(hostPerson.page, hostPerson.ctx, address);
        await follow(host);
        await cue(cues[1]);
        layout("full", guestPerson.nick);
        await expect(seatCard(guestPerson, address)).toBeVisible({
          timeout: 10_000,
        });
        await focus(seatCard(guestPerson, address));
        await pointAt(guestPerson.page, seatCard(guestPerson, address));
        guest = await enterRoom(guestPerson.page, guestPerson.ctx, address);
        await follow(guest);
        layout("split", hostPerson.nick, guestPerson.nick);
        await cue(cues[2]);
        await bothReady(host, guest);
        await restCursor(guest);
        await pointAt(host, host.getByTestId("p2p-room-start"));
        await startMatch(host, guest, WAY);
        await restCursor(host);
      },
      { kind: "full", cameras: [hostPerson.nick] },
    );
    match.rooms = { host: host!, guest: guest! };
  }

  test("01 the draw", async () => {
    const shot = shotFor(1);
    const pixel = people[PIXEL];
    await onlyTheChat(pixel);
    await filmCrew(
      { [PIXEL]: pixel.page },
      shot,
      async ({ cue, focus }) => {
        await focus(pixel.chat.chatInput);
        await cue("bytebard made the draw");
        await cast.say(BYTEBARD, "semi one: Pixel vs kestrel");
        await cue("Pixel against kestrel");
        await cast.say(BYTEBARD, "semi two: nova vs lumen");
        await cue("The two winners");
        await cast.say(BYTEBARD, "winners meet in the final");
        await cast.say(KESTREL, "let's go");
        await focus(null);
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });

  test("02 three formats", async () => {
    const shot = shotFor(2);
    const page = people[PIXEL].page;
    await homeOpen(people[PIXEL]);
    await filmCrew(
      { [PIXEL]: page },
      shot,
      async ({ cue, focus, pace }) => {
        await pace(400);
        await focus(page.getByTestId("game-ways"));
        await cue("A full set");
        await focus(way(page, GAME));
        await cue("Quick Match, first to three");
        await focus(way(page, "hex_tennis_quick"));
        await cue("And Sudden Death");
        await focus(way(page, WAY));
        await cue("A tournament in one evening");
        await focus(way(page, WAY));
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });

  test("03 semifinal one", async () => {
    await madeOnCamera(3, semis[0], [
      "Pixel presses Find a partner",
      "kestrel takes it",
      "Both ready",
    ]);
  });

  test("04 on court", async () => {
    await onCourt(4, semis[0], [
      "Where the ball meets the racket",
      "Let one get past you",
    ]);
  });

  test("05 semifinal two", async () => {
    await onCourt(5, semis[1], ["nova offered the seat", "Same court"]);
  });

  test("06 two cards", async () => {
    const shot = shotFor(6);
    test.setTimeout(3 * MATCH_TIMEOUT + 4 * 60_000);
    await finalists();
    const pixel = people[PIXEL];
    await onlyTheChat(pixel);
    for (const semi of semis) {
      await expect(resultCard(pixel, semi)).toBeVisible({ timeout: 30_000 });
    }
    await resultCard(pixel, semis[1]).scrollIntoViewIfNeeded();
    await filmCrew(
      { [PIXEL]: pixel.page },
      shot,
      async ({ cue, focus }) => {
        await focus(resultCard(pixel, semis[0]));
        await cue("Scoreboard posts each one");
        await focus(resultCard(pixel, semis[1]));
        await cue("Two winners, one final");
        await focus(null);
      },
      { kind: "full", cameras: [PIXEL] },
    );
  });

  test("07 the final", async () => {
    test.setTimeout(3 * MATCH_TIMEOUT + 4 * 60_000);
    const match = await finalists();
    await madeOnCamera(7, match, [
      "The winner of semifinal one",
      "The winner of semifinal two",
      "Both ready",
    ]);
  });

  test("00 cold open", async () => {
    test.setTimeout(4 * MATCH_TIMEOUT + 4 * 60_000);
    const match = await finalists();
    await onCourt(0, match, ["Four players came in", "Every point is a game"]);
  });

  test("08 champion", async () => {
    const shot = shotFor(8);
    test.setTimeout(4 * MATCH_TIMEOUT + 4 * 60_000);
    const match = await finalists();
    if (!(await on(match)) && !match.rooms) await playing(match);
    await result(match);
    const champion = match.winner!;
    const runnerUp = match.loser!;
    const { host, guest } = match.rooms!;
    // Off camera: both chats on their own conversation, the final's card in it.
    for (const [who, other] of [
      [champion, runnerUp],
      [runnerUp, champion],
    ]) {
      await who.chat.sendMessage(`/query ${other.nick}`);
      await expect(who.chat.chatInput).toHaveAttribute(
        "placeholder",
        new RegExp(other.nick),
      );
    }
    const card = champion.page
      .locator('[data-testid^="game-result-card-"]')
      .filter({ hasText: runnerUp.nick })
      .last();
    await expect(card).toBeVisible({ timeout: 30_000 });
    await host.bringToFront();
    await guest.bringToFront();
    await restCursor(host);
    await restCursor(guest);
    await filmCrew(
      { [match.host.nick]: host, [match.guest.nick]: guest },
      shot,
      async ({ cue, focus, follow, layout }) => {
        await focus(host.getByTestId("lobby-game-result"));
        await cue("Its result lands");
        layout("full", champion.nick);
        await follow(champion.page);
        await champion.page.bringToFront();
        await card.scrollIntoViewIfNeeded();
        await restCursor(champion.page);
        await focus(card);
        await cast.say(runnerUp.nick, "gg, champ");
        await cue("Hex Tennis is free to play");
        await focus(card);
      },
      { kind: "split", cameras: [match.host.nick, match.guest.nick] },
    );
    await close(match);
  });
});
