/**
 * Director — EP03, "Just the two of you: a private session on RetroHexChat".
 *
 * Films the episode's scenes for the YouTube channel. Not a test: nothing here
 * guards a behaviour, and it never runs with the suite. The script, narration
 * and timing live in `retro_hex_chat_videos/episodes/03-just-the-two-of-you/script.md`;
 * every beat is a flow a spec in `e2e/tests/` already proves — its ID is in
 * the script.
 *
 * Two people are on film, each in a browser of their own with a camera on it:
 * Pixel and lumen. Their webcams show animated pixel-art characters, which
 * talk on the lines the script gives them (`talk`) and wave on cue. Each scene
 * says which of the two screens the edit shows (`layout`), and sets up off
 * camera everything it needs — any one of them can be retaken alone.
 *
 *   make e2e.director SHOTS=/abs/shots.json OUT=/abs/takes FRESH=1
 */
import { BrowserContext, expect, Page, test } from "@playwright/test";
import { TestUser } from "../helpers/chatUsers";
import {
  enterP2PSession,
  remoteVideoLive,
  statusBarP2P,
} from "../helpers/p2pFlows";
import { enterViaCard } from "../helpers/surfaceEntry";
import { ChatPage } from "../pages/ChatPage";
import { ConnectPage } from "../pages/ConnectPage";
import { consoleSection, propFile } from "./calls";
import { Cast, Line } from "./cast";
import {
  cameraContext,
  film,
  filmCrew,
  pointAt,
  restCursor,
  shotFor,
  turnTipsOff,
  typeOnCamera,
} from "./shots";

const PASSWORD = "retro1998";

// The two friends on film, each with a time zone of their own.
const PIXEL = "Pixel";
const LUMEN = "lumen";
const ZONES: Record<string, string> = {
  [PIXEL]: "Europe/London",
  [LUMEN]: "America/Los_Angeles",
};

// Already in #lobby. nova joins first and owns it.
const CAST = ["nova", "kestrel", "bytebard", "dialup_dan", "m0dem"];
const LOBBY_EARLIER: Line[] = [
  { by: "kestrel", says: "friday night, finally. who's around?" },
  { by: "bytebard", says: "me, with a pizza and zero plans" },
  { by: "m0dem", says: "trivia at nine, don't forget" },
  { by: "dialup_dan", says: "is it 90s music trivia again? 🎵" },
];

// Scene 1: lumen's news, in front of everyone.
const NEWS: Line[] = [
  { by: LUMEN, says: "it's DONE. the synth track is finally done 🎶" },
  { by: "nova", says: "link pls" },
  { by: LUMEN, says: "not yet 😄 Pixel gets to hear it first" },
];

// Scene 6: the song, its cover, and how big the song is — big enough to still
// be travelling when the cover is picked.
const SONG = "night-drive.wav";
const SONG_MB = 420;
const COVER = "night-drive-cover.png";

// The e2e server allows two new sessions every ten seconds.
const SESSION_GAP_MS = 6_000;

type Session = { pixel: Page; lumen: Page };

test.describe.configure({ mode: "serial" });

test.describe("EP03 just the two of you", () => {
  let cast: Cast;
  let pixel: TestUser;
  let lumen: TestUser;
  // The session tabs open right now, if any: the next scene ends them first.
  let open: Partial<Session> = {};
  let lastSessionAt = 0;

  test.beforeAll(async ({ browser }) => {
    test.setTimeout(4 * 60_000);
    cast = await Cast.assemble(browser, CAST, PASSWORD);
    await cast.command("nova", "/topic Welcome to #lobby — be excellent");
    await cast.play(LOBBY_EARLIER);
    pixel = await friend(browser, PIXEL);
    lumen = await friend(browser, LUMEN);
    cast.adopt(lumen);
  });

  test.afterAll(async () => {
    await endSession();
    await cast?.dismiss();
    await pixel?.ctx.close();
  });

  /** One of the two friends, signed in off camera, their camera a character. */
  async function friend(
    browser: Parameters<typeof cameraContext>[0],
    nick: string,
  ): Promise<TestUser> {
    const ctx: BrowserContext = await cameraContext(browser, nick, {
      face: "character",
      timezoneId: ZONES[nick],
    });
    const page = await ctx.newPage();
    const connect = new ConnectPage(page);
    const chat = new ChatPage(page);
    await connect.open();
    await connect.signIn(nick, PASSWORD);
    await chat.waitUntilConnected();
    await turnTipsOff(page, nick);
    await chat.waitUntilConnected();
    return { chat, connect, ctx, page, nick, password: PASSWORD };
  }

  /** Off camera: whatever session is open ends, and both are back in the chat. */
  async function endSession() {
    const { pixel: host, lumen: guest } = open;
    open = {};
    if (host && !host.isClosed()) {
      if (await host.getByTestId("p2p-session-console").isVisible()) {
        await host.getByTestId("p2p-console-end-session").click();
        await host.getByTestId("p2p-confirm-dialog-confirm").click();
      } else if (await host.getByTestId("p2p-room-cancel").isVisible()) {
        await host.getByTestId("p2p-room-cancel").click();
      }
    }
    for (const tab of [host, guest])
      if (tab && !tab.isClosed()) await tab.close();
    if (pixel) {
      await expect(statusBarP2P(pixel.page)).toBeHidden({ timeout: 20_000 });
      await pixel.page.bringToFront();
    }
    await lumen?.page.bringToFront();
  }

  /** Off camera: both friends in the chat, Pixel in lumen's private chat. */
  async function inPrivateChat() {
    await endSession();
    if (!(await pixel.chat.conversationRow(LUMEN).isVisible())) {
      await pixel.chat.sendMessage(`/query ${LUMEN}`);
      await pixel.chat.expectTabVisible(LUMEN);
    }
    await pixel.chat.switchToTab(LUMEN);
    await lumen.chat.switchToTab("#lobby");
  }

  /** Waits out the server's limit on new sessions. */
  async function sessionAllowed() {
    const wait = lastSessionAt + SESSION_GAP_MS - Date.now();
    if (wait > 0) await pixel.page.waitForTimeout(wait);
    lastSessionAt = Date.now();
  }

  /** Off camera: Pixel has invited lumen, and both are in the waiting room. */
  async function inWaitingRoom(): Promise<Session> {
    await inPrivateChat();
    await sessionAllowed();
    await pixel.chat.sendMessage(`/p2p ${LUMEN}`);
    open.pixel = await enterP2PSession(pixel);
    await lumen.chat.expectTabVisible(PIXEL);
    await lumen.chat.switchToTab(PIXEL);
    open.lumen = await enterP2PSession(lumen);
    for (const tab of [open.pixel, open.lumen]) {
      await expect(tab.getByTestId("p2p-starting-room")).toBeVisible();
      await expect(tab.getByTestId("p2p-setup-preview")).toBeVisible();
    }
    return open as Session;
  }

  /** Both press Ready, and the host starts. */
  async function start(session: Session) {
    await session.pixel.getByTestId("p2p-room-ready").click();
    await session.lumen.getByTestId("p2p-room-ready").click();
    await expect(session.pixel.getByTestId("p2p-room-start")).toBeEnabled({
      timeout: 20_000,
    });
    await session.pixel.getByTestId("p2p-room-start").click();
  }

  async function callUp(session: Session) {
    for (const tab of [session.pixel, session.lumen]) {
      await expect(tab.getByTestId("p2p-session-console")).toBeVisible({
        timeout: 20_000,
      });
      await expect
        .poll(() => remoteVideoLive(tab), { timeout: 30_000 })
        .toBe(true);
    }
  }

  /** Off camera: a session live both ways, both looking at `section`. */
  async function liveSession(
    section: "call" | "files" | "games" = "call",
  ): Promise<Session> {
    const session = await inWaitingRoom();
    await start(session);
    await callUp(session);
    for (const tab of [session.pixel, session.lumen]) {
      await consoleSection(tab, section);
      await restCursor(tab);
    }
    return session;
  }

  /** Proposes Hex Pong from Pixel's side; lumen accepts. */
  async function hexPong(session: Session) {
    await session.pixel
      .getByTestId("lobby-game-panel")
      .getByRole("button", { name: "Hex Pong" })
      .click();
    const consent = session.lumen.getByTestId("lobby-game-consent");
    await expect(consent).toBeVisible({ timeout: 15_000 });
    await pointAt(session.lumen, consent);
    await consent.getByRole("button", { name: "Accept" }).click();
    for (const tab of [session.pixel, session.lumen]) {
      await expect(tab.locator("#lobby-game-canvas canvas")).toBeVisible({
        timeout: 20_000,
      });
      await restCursor(tab);
    }
  }

  /** Both players move their paddles until `done` says stop. */
  async function rally(session: Session, done: () => boolean) {
    const players: [Page, number][] = [
      [session.pixel, 0],
      [session.lumen, 1],
    ];
    await Promise.all(
      players.map(async ([page, offset]) => {
        let i = offset;
        while (!done() && !page.isClosed()) {
          const key = i % 2 === 0 ? "ArrowUp" : "ArrowDown";
          await page.keyboard.down(key);
          await page.waitForTimeout(260 + ((i * 97) % 240));
          await page.keyboard.up(key);
          i++;
        }
      }),
    );
  }

  /** lumen's song goes out; Pixel takes it. */
  async function sendSong(session: Session, file: string) {
    await session.lumen.locator("#lobby-file-input").setInputFiles(file);
    const offer = session.pixel
      .getByTestId("lobby-file-panel")
      .getByTestId("file-transfer");
    await expect(offer).toContainText(SONG, { timeout: 15_000 });
    const accept = session.pixel
      .getByTestId("lobby-file-panel")
      .getByTestId("file-transfer-accept");
    await pointAt(session.pixel, accept);
    await accept.click();
    await restCursor(session.pixel);
  }

  async function reactionsOpen(page: Page) {
    await page
      .getByTestId("p2p-call-dock")
      .locator('summary[aria-label="Reactions"]')
      .click();
  }

  test("01 a busy lobby", async () => {
    const shot = shotFor(1);
    await inPrivateChat();
    await pixel.chat.switchToTab("#lobby");
    await restCursor(pixel.page);
    await film(pixel.page, shot, async ({ cue, pace }) => {
      await pace(1500);
      await cue("Lumen has news");
      await cast.play(NEWS.slice(0, 2));
      await cue("They could share it");
      await cast.say(NEWS[2].by, NEWS[2].says);
      await cue("so you open a private chat");
      await pixel.chat.chatInput.click();
      await typeOnCamera(pixel.chat.chatInput, `/query ${LUMEN}`);
      await pixel.chat.chatInput.press("Enter");
      await pixel.chat.expectTabVisible(LUMEN);
      await restCursor(pixel.page);
    });
  });

  test("02 the invitation", async () => {
    const shot = shotFor(2);
    await inPrivateChat();
    await restCursor(pixel.page);
    await restCursor(lumen.page);
    try {
      await filmCrew(
        { [PIXEL]: pixel.page, [LUMEN]: lumen.page },
        shot,
        async ({ cue, follow, focus, layout, pace }) => {
          await cue("type the P2P command");
          await pixel.chat.chatInput.click();
          await sessionAllowed();
          await typeOnCamera(pixel.chat.chatInput, `/p2p ${LUMEN}`);
          await pixel.chat.chatInput.press("Enter");
          const card = pixel.page.getByTestId("share-message-card").last();
          await expect(card).toBeVisible({ timeout: 10_000 });
          await restCursor(pixel.page);

          await cue("An invitation card lands");
          await focus(card);

          await cue("lumen sees it arrive");
          layout("full", LUMEN);
          await lumen.chat.expectTabVisible(PIXEL);
          await lumen.chat.switchToTab(PIXEL);
          const theirs = lumen.page.getByTestId("share-message-card").last();
          await expect(theirs).toBeVisible();
          await focus(theirs);
          await pointAt(lumen.page, theirs);

          await cue("Joining opens a room");
          // Pixel goes in too, off screen: the room is waiting for both.
          const host = enterP2PSession(pixel);
          open.lumen = await enterViaCard(lumen.page, lumen.ctx);
          await follow(open.lumen);
          await expect(
            open.lumen.getByTestId("p2p-starting-room"),
          ).toBeVisible();
          await restCursor(open.lumen);
          open.pixel = await host;
          await pace(300);
        },
        { kind: "full", cameras: [PIXEL] },
      );
    } finally {
      await endSession();
    }
  });

  test("03 the waiting room", async () => {
    const shot = shotFor(3);
    const session = await inWaitingRoom();
    try {
      await filmCrew(
        { [PIXEL]: session.pixel, [LUMEN]: session.lumen },
        shot,
        async ({ cue, focus, talk, pace }) => {
          await cue("there's a waiting room");
          await focus(session.pixel.getByTestId("p2p-room-roster"));

          await cue("checks your camera");
          await pointAt(
            session.pixel,
            session.pixel.getByTestId("p2p-setup-preview"),
          );
          await pace(400);
          await pointAt(
            session.lumen,
            session.lumen.getByTestId("p2p-setup-preview"),
          );
          await focus(null);

          await talk("is my hair ok");
          await talk("it's pixels");
          for (const tab of [session.pixel, session.lumen]) {
            await pointAt(tab, tab.getByTestId("p2p-room-ready"));
            await tab.getByTestId("p2p-room-ready").click();
            await pace(400);
          }

          await cue("the host presses Start");
          const startButton = session.pixel.getByTestId("p2p-room-start");
          await expect(startButton).toBeEnabled({ timeout: 20_000 });
          await pointAt(session.pixel, startButton);
          await startButton.click();
          for (const tab of [session.pixel, session.lumen]) {
            await expect(tab.getByTestId("p2p-session-console")).toBeVisible({
              timeout: 20_000,
            });
            await restCursor(tab);
          }
        },
        { kind: "split", cameras: [PIXEL, LUMEN] },
      );
    } finally {
      await endSession();
    }
  });

  test("04 face to face", async () => {
    const shot = shotFor(4);
    const session = await liveSession("call");
    try {
      await filmCrew(
        { [PIXEL]: session.pixel, [LUMEN]: session.lumen },
        shot,
        async ({ cue, talk, wave, pace, focus, layout }) => {
          await cue("there you are");
          await wave(LUMEN, 2.2);
          await pace(300);
          await wave(PIXEL, 2.2);

          await talk("hiii");
          await talk("congrats on finishing it");

          await cue("turns your own camera");
          await pointAt(
            session.pixel,
            session.pixel.getByTestId("p2p-call-toggle-mute"),
          );
          await pace(500);
          await pointAt(
            session.pixel,
            session.pixel.getByTestId("p2p-call-toggle-camera"),
          );

          // Full on Pixel's screen, so the change of layout reads.
          await cue("Switch the layout");
          layout("full", PIXEL);
          const split = session.pixel.getByTestId("p2p-call-layout-split");
          await pointAt(session.pixel, split);
          await split.click();
          await expect(
            session.pixel.getByTestId("p2p-call-local-tile"),
          ).toHaveAttribute("data-self-view", "tile");
          await restCursor(session.pixel);

          await talk("wait till you hear it");

          await cue("Send a heart");
          layout("split", PIXEL, LUMEN);
          await reactionsOpen(session.lumen);
          await session.lumen.getByTestId("p2p-call-reaction-heart").click();
          await restCursor(session.lumen);
          const heart = session.pixel
            .getByTestId("p2p-peer-reactions")
            .locator('[data-reaction="heart"]');
          await expect(heart).toBeVisible({ timeout: 10_000 });
          await focus(session.pixel.getByTestId("p2p-call-remote-tile"));
        },
        { kind: "split", cameras: [PIXEL, LUMEN] },
      );
    } finally {
      await endSession();
    }
  });

  test("05 show, don't tell", async () => {
    const shot = shotFor(5);
    const session = await liveSession("call");
    try {
      await filmCrew(
        { [PIXEL]: session.pixel, [LUMEN]: session.lumen },
        shot,
        async ({ cue, talk, focus }) => {
          await cue("easier to show");
          await talk("ok look");

          await cue("Lumen shares their screen");
          const share = session.lumen.getByTestId("p2p-call-screen-share");
          await pointAt(session.lumen, share);
          await share.click();
          await restCursor(session.lumen);
          const remote = session.pixel.getByTestId("p2p-call-remote-tile");
          await expect(remote).toHaveAttribute(
            "data-peer-screen-share",
            "true",
            {
              timeout: 10_000,
            },
          );
          await focus(remote);

          await talk("you made all of that");

          await cue("One click to start");
          await pointAt(session.lumen, share);
          await share.click();
          await restCursor(session.lumen);
          await expect(remote).toHaveAttribute(
            "data-peer-screen-share",
            "false",
            {
              timeout: 10_000,
            },
          );
          await focus(null);
        },
        { kind: "pip", cameras: [PIXEL, LUMEN] },
      );
    } finally {
      await endSession();
    }
  });

  test("06 hand it over", async () => {
    const shot = shotFor(6);
    const song = propFile(SONG, SONG_MB);
    const cover = propFile(COVER, 1);
    const session = await liveSession("files");
    try {
      await filmCrew(
        { [PIXEL]: session.pixel, [LUMEN]: session.lumen },
        shot,
        async ({ cue, talk, focus }) => {
          await talk("can I keep it");

          await cue("the song itself");
          await pointAt(
            session.lumen,
            session.lumen.getByTestId("p2p-files-dropzone"),
          );

          await cue("Lumen drops the file");
          await sendSong(session, song);
          await restCursor(session.lumen);
          // The transfer cards are small in a wide, mostly empty panel: the
          // edit zooms each side onto its own.
          for (const tab of [session.pixel, session.lumen]) {
            await focus(
              tab
                .getByTestId("lobby-file-panel")
                .getByTestId("file-transfer")
                .first(),
            );
          }

          // lumen picks the cover as they say so: the song is still on its
          // way, and the queue notice is up while the narrator explains it.
          await talk("cover art too");
          await session.lumen.locator("#lobby-file-input").setInputFiles(cover);
          await expect(session.lumen.getByTestId("p2p-notice")).toContainText(
            `Queued for after the current transfer: ${COVER}`,
          );

          await cue("Send another one");
          const offer = session.pixel
            .getByTestId("lobby-file-panel")
            .getByTestId("file-transfer");
          await expect(offer).toContainText(COVER, { timeout: 30_000 });
          const accept = session.pixel
            .getByTestId("lobby-file-panel")
            .getByTestId("file-transfer-accept");
          await pointAt(session.pixel, accept);
          await accept.click();
          await restCursor(session.pixel);

          // Thanks are said face to face: both go back to the call.
          await focus(null);
          await Promise.all(
            [session.pixel, session.lumen].map((tab) =>
              consoleSection(tab, "call"),
            ),
          );
          await talk("enjoy");
          await talk("got both");
        },
        { kind: "split", cameras: [PIXEL, LUMEN] },
      );
    } finally {
      await endSession();
    }
  });

  test("07 rematch", async () => {
    const shot = shotFor(7);
    const session = await liveSession("games");
    let done = false;
    let play: Promise<void> | undefined;
    try {
      await filmCrew(
        { [PIXEL]: session.pixel, [LUMEN]: session.lumen },
        shot,
        async ({ cue, talk }) => {
          await talk("rematch?");
          await talk("you're on");

          await cue("Pick Hex Pong");
          await pointAt(
            session.pixel,
            session.pixel
              .getByTestId("lobby-game-panel")
              .getByRole("button", { name: "Hex Pong" }),
          );
          await hexPong(session);

          await cue("Every move goes straight");
          play = rally(session, () => done);

          await talk("no no no");
          await talk("GOAL");
          await cue("Some arguments");
        },
        { kind: "split", cameras: [PIXEL, LUMEN] },
      );
    } finally {
      done = true;
      await play;
      await endSession();
    }
  });

  test("08 back to the lobby", async () => {
    const shot = shotFor(8);
    const session = await liveSession("call");
    // Off camera, the chat Pixel comes back to is on #lobby. The private chat
    // stays shut: its history holds every session the other scenes opened.
    // The session's icon beside lumen in the conversation list says the
    // call is still on.
    await pixel.chat.switchToTab("#lobby");
    try {
      await filmCrew(
        { [PIXEL]: session.pixel, [LUMEN]: session.lumen },
        shot,
        async ({ cue, follow, pace }) => {
          await cue("lives in its own tab");
          const back = session.pixel.getByTestId("p2p-back-to-chat");
          await pointAt(session.pixel, back);
          await back.click();
          await follow(pixel.page);
          await pointAt(
            pixel.page,
            pixel.page.getByTestId(`pm-p2p-glyph-${LUMEN}`),
          );
          await pace(800);

          // The lobby is already open: the line typed into it has to fit the
          // last sentence.
          await cue("keeps going in the other tab");
          await pace(1200);
          await pixel.chat.chatInput.click();

          await cue("the lobby gets to hear");
          await typeOnCamera(pixel.chat.chatInput, "lumen's track is fire");
          await pixel.chat.chatInput.press("Enter");
          await restCursor(pixel.page);
          await cast.say("nova", "can't wait 🎶");
        },
        { kind: "full", cameras: [PIXEL] },
      );
    } finally {
      await endSession();
    }
  });

  test("09 good night", async () => {
    const shot = shotFor(9);
    const session = await liveSession("call");
    try {
      await filmCrew(
        { [PIXEL]: session.pixel, [LUMEN]: session.lumen },
        shot,
        async ({ cue, focus, talk, wave }) => {
          await wave(LUMEN, 2.4);
          await talk("gg");
          await wave(PIXEL, 2.4);
          await talk("night!");

          await cue("either of you ends the session");
          const end = session.lumen.getByTestId("p2p-console-end-session");
          await pointAt(session.lumen, end);
          await end.click();
          await session.lumen.getByTestId("p2p-confirm-dialog-confirm").click();
          for (const tab of [session.pixel, session.lumen]) {
            await expect(tab.getByTestId("p2p-left")).toBeVisible({
              timeout: 15_000,
            });
            await restCursor(tab);
            await focus(tab.getByTestId("p2p-left"));
          }

          // The episode closes on both rooms closed. Not on the private chat:
          // its history holds every session the other scenes opened.
        },
        { kind: "split", cameras: [PIXEL, LUMEN] },
      );
    } finally {
      await endSession();
    }
  });

  // Filmed last, from what the other scenes have shown: run first, its
  // session would already be history in scene 2's private chat.
  test("00 cold open", async () => {
    const shot = shotFor(0);
    const song = propFile(SONG, SONG_MB);
    const session = await liveSession("call");
    let done = false;
    let play: Promise<void> | undefined;
    try {
      await filmCrew(
        { [PIXEL]: session.pixel, [LUMEN]: session.lumen },
        shot,
        async ({ cue, layout, pace, wave }) => {
          await wave(PIXEL, 2.4);
          await pace(500);
          await wave(LUMEN, 2.4);

          await cue("Not the whole channel");
          layout("pip", PIXEL, LUMEN);
          await session.lumen.getByTestId("p2p-call-screen-share").click();
          await expect(
            session.pixel.getByTestId("p2p-call-remote-tile"),
          ).toHaveAttribute("data-peer-screen-share", "true", {
            timeout: 10_000,
          });

          await cue("Talk face to face");
          await pace(1800);
          layout("split", PIXEL, LUMEN);
          for (const tab of [session.pixel, session.lumen]) {
            await consoleSection(tab, "files");
          }
          await sendSong(session, song);

          await cue("All in one window");
          for (const tab of [session.pixel, session.lumen]) {
            await consoleSection(tab, "games");
          }
          await hexPong(session);
          play = rally(session, () => done);
        },
        { kind: "split", cameras: [PIXEL, LUMEN] },
      );
    } finally {
      done = true;
      await play;
      await endSession();
    }
  });
});
