/**
 * Director — EP04, "Band practice: a group call on RetroHexChat".
 *
 * Films the episode's scenes for the YouTube channel. Not a test: nothing here
 * guards a behaviour, and it never runs with the suite. The script, narration
 * and timing live in `retro_hex_chat_videos/episodes/04-band-practice/script.md`;
 * every beat is a flow a spec in `e2e/tests/` already proves — its ID is in
 * the script.
 *
 * The band of #basement holds a conference. Everyone in it is a browser of
 * their own with a camera on it, showing their PixelLab portrait
 * (`portraits/`). lumen runs the call and is the main camera; bytebard,
 * kestrel, honk and m0dem are filmed in the scene that is on their side.
 * Whoever is on the call and not filmed is still a voice: their lines make
 * their own portrait talk on everyone else's screen.
 *
 * One conference carries the whole episode when it is filmed in order. Each
 * scene still sets up, off camera, the call it needs — who is in it, nobody
 * muted by the moderator, the door unlocked — so any one of them can be
 * retaken alone.
 *
 *   make e2e.director SHOTS=/abs/shots.json OUT=/abs/takes FRESH=1
 */
import { Browser, expect, Page, test } from "@playwright/test";
import { TestUser } from "../helpers/chatUsers";
import {
  conferenceAddress,
  openConference,
  openModerationMenu,
} from "../helpers/groupCallUsers";
import { enterViaCard } from "../helpers/surfaceEntry";
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

const PASSWORD = "retro1998";
const CHANNEL = "#basement";

const LUMEN = "lumen";
const NOVA = "nova";
const BYTEBARD = "bytebard";
const KESTREL = "kestrel";
const PIXEL = "Pixel";
const M0DEM = "m0dem";
const HONK = "honk";
const BAND = [NOVA, BYTEBARD, KESTREL, PIXEL, M0DEM];

// Where each person says they are: the room reads as people, not one machine.
const ZONES: Record<string, string> = {
  [LUMEN]: "America/Los_Angeles",
  [NOVA]: "Europe/London",
  [BYTEBARD]: "America/Chicago",
  [KESTREL]: "Europe/Berlin",
  [PIXEL]: "Europe/Lisbon",
  [M0DEM]: "America/New_York",
  [HONK]: "Australia/Sydney",
};

// In #basement, never on the call.
const FANS = ["wren", "sol"];

const EARLIER: Line[] = [
  { by: "wren", says: "is the friday gig still on?? 🎸" },
  { by: KESTREL, says: "yes. 9pm at the Cellar" },
  { by: "sol", says: "bringing the whole office" },
  { by: M0DEM, says: "posters are up all over town" },
];

const SETLIST_PANIC: Line[] = [
  { by: NOVA, says: "friday is in 3 days and we have NO setlist" },
  { by: BYTEBARD, says: "call?" },
  { by: PIXEL, says: "call." },
  { by: "wren", says: "can we listen in 👀", then: 400 },
];

const FANS_WAITING: Line[] = [
  { by: "wren", says: "are they still arguing 😂" },
  { by: "sol", says: "I hear the opener is NEW" },
];

test.describe.configure({ mode: "serial" });

test.describe("EP04 band practice", () => {
  let fans: Cast;
  const people = new Map<string, TestUser>();
  // Who is in the conference right now, and the tab they are in it from.
  const calls = new Map<string, Page>();
  let address: string | null = null;

  test.beforeAll(async ({ browser }) => {
    test.setTimeout(8 * 60_000);
    // lumen joins #basement first, so lumen founds it and runs it.
    for (const nick of [LUMEN, ...BAND, HONK]) {
      const member = await person(browser, nick);
      await member.chat.sendMessage(`/join ${CHANNEL}`);
      await member.chat.expectTabVisible(CHANNEL);
      await member.chat.switchToTab(CHANNEL);
      people.set(nick, member);
    }
    await chat(LUMEN).sendMessage(
      "/topic the band · gig friday 9pm @ the Cellar · rehearsals here",
    );
    fans = await Cast.assemble(browser, FANS, PASSWORD);
    for (const fan of FANS) {
      await fans.command(fan, `/join ${CHANNEL}`);
      await fans.member(fan).chat.expectTabVisible(CHANNEL);
      await fans.member(fan).chat.switchToTab(CHANNEL);
    }
    for (const member of people.values()) fans.adopt(member);
    await fans.play(EARLIER);
  });

  test.afterAll(async () => {
    await fans?.dismiss();
    for (const member of people.values()) await member.ctx.close();
  });

  /** One person, signed in off camera, their camera their portrait. */
  async function person(browser: Browser, nick: string): Promise<TestUser> {
    const ctx = await cameraContext(browser, nick, {
      face: "character",
      timezoneId: ZONES[nick],
    });
    const page = await ctx.newPage();
    const connect = new ConnectPage(page);
    const chatPage = new ChatPage(page);
    await connect.open();
    await connect.signIn(nick, PASSWORD);
    await chatPage.waitUntilConnected();
    await turnTipsOff(page, nick);
    await chatPage.waitUntilConnected();
    return { chat: chatPage, connect, ctx, page, nick, password: PASSWORD };
  }

  const member = (nick: string) => people.get(nick)!;
  const chat = (nick: string) => member(nick).chat;
  const call = (nick: string) => calls.get(nick)!;

  /** Everyone in the call who is not filmed, so their lines still talk. */
  function voices(...filmed: string[]): Record<string, Page> {
    return Object.fromEntries(
      [...calls].filter(([nick]) => !filmed.includes(nick)),
    );
  }

  async function intoCall(page: Page) {
    await page.getByTestId("group-call-prejoin-join").click();
    await expect(page.getByTestId("group-call-webrtc")).toBeVisible({
      timeout: 20_000,
    });
    await restCursor(page);
  }

  /** Off camera: lumen is in a running conference, and only lumen. */
  async function lumenInCall() {
    const lumenCall = calls.get(LUMEN);
    if (
      lumenCall &&
      !lumenCall.isClosed() &&
      (await lumenCall.getByTestId("group-call-webrtc").isVisible())
    ) {
      return lumenCall;
    }
    await endCall();
    await chat(LUMEN).switchToTab(CHANNEL);
    const page = await openConference(member(LUMEN));
    await intoCall(page);
    calls.set(LUMEN, page);
    address = conferenceAddress(page);
    return page;
  }

  /** A band member's own tab at the call's address, at the device check. */
  async function atTheDoor(nick: string): Promise<Page> {
    const page = await member(nick).ctx.newPage();
    await page.goto(address!);
    await expect(page.getByTestId("group-call-prejoin")).toBeVisible({
      timeout: 20_000,
    });
    return page;
  }

  async function leave(nick: string) {
    const page = calls.get(nick);
    calls.delete(nick);
    if (!page || page.isClosed()) return;
    if (await page.getByTestId("group-call-leave").isVisible()) {
      await page.getByTestId("group-call-leave").click();
    }
    await page.close();
  }

  /** Off camera: whatever conference is running ends, and every call tab closes. */
  async function endCall() {
    const lumenCall = calls.get(LUMEN);
    if (lumenCall && !lumenCall.isClosed()) {
      if (await lumenCall.getByTestId("group-call-webrtc").isVisible()) {
        await openModerationMenu(lumenCall);
        await lumenCall.getByTestId("group-call-close-room").click();
        await lumenCall
          .getByTestId("group-call-confirm-dialog-confirm")
          .click();
      }
    }
    for (const page of calls.values()) if (!page.isClosed()) await page.close();
    calls.clear();
    address = null;
    await member(LUMEN).page.bringToFront();
  }

  /**
   * Off camera: the conference holds lumen and exactly `nicks`, with nobody
   * muted by the moderator and the door open.
   */
  async function bandInCall(nicks: string[], { locked = false } = {}) {
    const lumenCall = await lumenInCall();
    for (const nick of [...calls.keys()]) {
      if (nick !== LUMEN && !nicks.includes(nick)) await leave(nick);
    }
    for (const nick of nicks) {
      if (calls.has(nick)) continue;
      if (nick === HONK) await letHonkBackIn();
      const page = await atTheDoor(nick);
      await intoCall(page);
      calls.set(nick, page);
    }
    await expect
      .poll(() => liveRemoteVideos(lumenCall), { timeout: 60_000 })
      .toBe(nicks.length);
    await releaseModeration(lumenCall);
    await setLock(lumenCall, locked);
    await section(lumenCall, "call");
    // Every scene opens on the whole band: the grid, nobody in focus.
    const rail = lumenCall.getByTestId("group-call-view-rail");
    const clearFocus = rail.getByTestId("group-call-clear-focus");
    if (await clearFocus.isVisible()) await clearFocus.click();
    await rail.getByTestId("group-call-layout-grid").click();
    await lumenCall.bringToFront();
    for (const page of calls.values()) await restCursor(page);
    return lumenCall;
  }

  /** honk was banned in an earlier take: lumen lifts it, honk comes back. */
  async function letHonkBackIn() {
    if (await chat(HONK).conversationRow(CHANNEL).isVisible()) return;
    await chat(LUMEN).sendMessage(`/unban ${HONK}`);
    await chat(HONK).sendMessage(`/join ${CHANNEL}`);
    await chat(HONK).expectTabVisible(CHANNEL);
    await chat(HONK).switchToTab(CHANNEL);
    await chat(LUMEN).switchToTab(CHANNEL);
  }

  async function liveRemoteVideos(page: Page) {
    return page.evaluate(
      () =>
        Array.from(
          document.querySelectorAll<HTMLVideoElement>(
            '[data-group-call-video-tile][data-local="false"] video',
          ),
        ).filter((video) => {
          const track = (
            video.srcObject as MediaStream | null
          )?.getVideoTracks()[0];
          return !!track && track.readyState === "live";
        }).length,
    );
  }

  async function section(
    page: Page,
    name: "call" | "people" | "stats" | "settings",
  ) {
    await page.getByTestId(`group-call-section-${name}`).click();
  }

  function row(page: Page, nick: string) {
    return page.locator("[data-group-call-participant]", { hasText: nick });
  }

  async function participantMenu(page: Page, nick: string) {
    await section(page, "people");
    const menu = row(page, nick).locator("details").first();
    if ((await menu.getAttribute("open")) === null) {
      await row(page, nick)
        .locator('[data-testid^="group-call-participant-actions-"]')
        .click();
    }
  }

  function menuItem(page: Page, nick: string, name: RegExp) {
    return row(page, nick).getByRole("menuitem", { name });
  }

  /** Every moderator block lifted, so a scene starts with everyone free. */
  async function releaseModeration(lumenCall: Page) {
    for (const nick of calls.keys()) {
      if (nick === LUMEN) continue;
      for (const [kind, name] of [
        ["audio", /Allow participant microphone/],
        ["video", /Allow participant camera/],
        ["screen", /Allow participant screen sharing/],
      ] as const) {
        await section(lumenCall, "people");
        const blocked = row(lumenCall, nick).locator(
          `[data-group-call-participant-${kind}][data-media-moderated="true"]`,
        );
        if ((await blocked.count()) === 0) continue;
        await participantMenu(lumenCall, nick);
        await menuItem(lumenCall, nick, name).click();
        await expect(blocked).toHaveCount(0, { timeout: 10_000 });
      }
    }
  }

  async function setLock(lumenCall: Page, locked: boolean) {
    await openModerationMenu(lumenCall);
    const toggle = lumenCall.getByTestId("group-call-lock-toggle");
    const now = (await toggle.getAttribute("aria-checked")) === "true";
    if (now !== locked) await toggle.click();
    else await lumenCall.keyboard.press("Escape");
  }

  async function react(page: Page, reaction: string) {
    const button = page.getByTestId(`group-call-reaction-${reaction}`);
    if (!(await button.isVisible())) {
      await page.getByTestId("group-call-reactions-toggle").click();
    }
    await button.click();
  }

  /** Off camera: lumen's chat is on #basement, with no call running. */
  async function quietChannel() {
    await endCall();
    await chat(LUMEN).switchToTab(CHANNEL);
    await restCursor(member(LUMEN).page);
  }

  test("01 rehearsal tonight", async () => {
    const shot = shotFor(1);
    await quietChannel();
    const lumen = member(LUMEN).page;
    await filmCrew(
      { [LUMEN]: lumen },
      shot,
      async ({ cue, focus, pace }) => {
        await pace(1200);
        await cue("The gig is on Friday");
        await fans.play(SETLIST_PANIC);

        await cue("lumen starts a group call");
        const open = lumen.getByTestId("group-call-open");
        await pointAt(lumen, open);
        await pace(300);
        await open.click();
        const card = lumen.getByTestId("share-message-card").last();
        await expect(card).toBeVisible({ timeout: 10_000 });
        await restCursor(lumen);

        await cue("An invitation card lands");
        await focus(card);
        await pace(1500);
        await focus(null);
        await pointAt(lumen, open);
        await restCursor(lumen);
      },
      { kind: "full", cameras: [LUMEN] },
    );
  });

  test("02 before you walk in", async () => {
    const shot = shotFor(2);
    // The room is open and its card is in the channel; lumen has not gone in.
    if (calls.has(LUMEN)) await endCall();
    await chat(LUMEN).switchToTab(CHANNEL);
    const lumen = member(LUMEN).page;
    const cards = lumen.getByTestId("share-message-enter");
    if ((await cards.count()) === 0 || !(await cards.last().isVisible())) {
      await lumen.getByTestId("group-call-open").click();
      await expect(cards.last()).toBeVisible({ timeout: 10_000 });
    }
    await restCursor(lumen);
    await filmCrew(
      { [LUMEN]: lumen },
      shot,
      async ({ cue, follow, focus, pace }) => {
        await cue("The call opens in a tab");
        const join = cards.last();
        await pointAt(lumen, join);
        const page = await enterViaCard(lumen, member(LUMEN).ctx);
        await follow(page);
        await expect(page.getByTestId("group-call-prejoin")).toBeVisible({
          timeout: 20_000,
        });
        calls.set(LUMEN, page);
        await restCursor(page);

        await cue("Check your camera");
        await pointAt(page, page.getByTestId("group-call-prejoin-preview"));
        await focus(page.getByTestId("group-call-prejoin-preview"));
        await cue("pick your microphone");
        const devices = page.getByTestId("group-call-prejoin-devices");
        await focus(devices);
        for (const picker of [
          "group-call-prejoin-audio-input",
          "group-call-prejoin-video-input",
          "group-call-prejoin-audio-output",
        ]) {
          await pointAt(page, page.getByTestId(picker));
          await pace(450);
        }

        await cue("Choose how the call should look");
        await focus(null);
        const advanced = page.getByTestId("group-call-prejoin-advanced");
        await pointAt(page, advanced);
        await advanced.locator("summary").click();
        await focus(page.getByTestId("group-call-prejoin-layout"));
        await pointAt(page, page.getByTestId("group-call-prejoin-layout"));

        await cue("Mute yourself before");
        await focus(null);
        await pointAt(page, page.getByTestId("group-call-prejoin-audio"));
        await page.getByTestId("group-call-prejoin-audio").setChecked(false);
        await restCursor(page);

        await cue("Then join");
        const go = page.getByTestId("group-call-prejoin-join");
        await pointAt(page, go);
        await intoCall(page);
        address = conferenceAddress(page);
      },
      { kind: "full", cameras: [LUMEN] },
    );
  });

  test("03 the band arrives", async () => {
    const shot = shotFor(3);
    const lumenCall = await bandInCall([]);
    // Each of them is already at the door; on camera they only walk in.
    const doors = new Map<string, Page>();
    for (const nick of BAND) doors.set(nick, await atTheDoor(nick));
    await lumenCall.bringToFront();
    const lumenChat = member(LUMEN).page;
    await filmCrew(
      { [LUMEN]: lumenCall },
      shot,
      async ({ cue, follow, focus, pace, talk }) => {
        // Each walks in on the line before their own, so the join is done
        // by the time they speak.
        const walkIn = async (nick: string) => {
          const page = doors.get(nick)!;
          await intoCall(page);
          calls.set(nick, page);
          await page.evaluate(() =>
            // eslint-disable-next-line @typescript-eslint/no-explicit-any
            (window as any).__directorCamera.wave(2),
          );
        };
        await cue("One by one");
        await walkIn(NOVA);
        let next = walkIn(PIXEL);
        await talk("hiii");
        await next;
        next = walkIn(KESTREL);
        await talk("who's on drums");
        await next;
        next = walkIn(M0DEM);
        await talk("sorry, was tuning");
        await next;
        next = walkIn(BYTEBARD);
        await talk("number 12 bus");
        await next;
        await talk("hey hey");

        await cue("Each new face");
        await focus(lumenCall.getByTestId("group-call-video-grid"));
        await pace(800);
        await focus(null);

        await cue("Back in the channel");
        await lumenChat.bringToFront();
        await follow(lumenChat);
        const card = lumenChat.getByTestId("share-message-card").last();
        await focus(card);
        await pace(1600);
        await focus(lumenChat.getByTestId(`nicklist-in-call-${NOVA}`));
        await pace(1200);
        const who = lumenChat.getByTestId("group-call-channel-popover-toggle");
        await pointAt(lumenChat, who);
        await who.click();
        await focus(lumenChat.getByTestId("group-call-channel-popover"));
        await pace(1600);
        await lumenChat.keyboard.press("Escape");
        await focus(null);
        await restCursor(lumenChat);

        await cue("whoever is speaking lights up");
        await lumenCall.bringToFront();
        await follow(lumenCall);
        await talk("can everyone hear me");
        await talk("loud and clear");
        await talk("I can hear your cat");

        await cue("Your camera and microphone");
        const camera = lumenCall.getByTestId("group-call-video-toggle");
        await pointAt(lumenCall, camera);
        await camera.click();
        await pace(900);
        await camera.click();
        await pace(400);
        const mic = lumenCall.getByTestId("group-call-audio-toggle");
        await pointAt(lumenCall, mic);
        await mic.click();
        await restCursor(lumenCall);
      },
      { kind: "full", cameras: [LUMEN] },
      Object.fromEntries(BAND.map((nick) => [nick, doors.get(nick)!])),
    );
  });

  test("04 find your view", async () => {
    const shot = shotFor(4);
    const lumenCall = await bandInCall(BAND);
    const rail = lumenCall.getByTestId("group-call-view-rail");
    await rail.getByTestId("group-call-layout-grid").click();
    await restCursor(lumenCall);
    await filmCrew(
      { [LUMEN]: lumenCall },
      shot,
      async ({ cue, focus, pace, talk }) => {
        await cue("Six faces in a grid");
        await focus(lumenCall.getByTestId("group-call-video-grid"));
        await pace(1500);
        await focus(null);

        await cue("When nova sings");
        await participantMenu(lumenCall, NOVA);
        const spotlight = row(lumenCall, NOVA).getByRole("menuitemcheckbox", {
          name: /Focus participant/,
        });
        await pointAt(lumenCall, spotlight);
        await spotlight.click();
        await section(lumenCall, "call");
        await restCursor(lumenCall);
        await talk("la la LAAA");
        await talk("chills");

        await cue("Or let the call follow");
        const speaker = rail.getByTestId("group-call-layout-speaker");
        await pointAt(lumenCall, speaker);
        await speaker.click();
        await restCursor(lumenCall);
        await talk("ba dum tss");
        await talk("every single time");

        await cue("Tuck your own camera");
        const selfView = rail.getByTestId("group-call-self-view-toggle");
        await pointAt(lumenCall, selfView);
        await selfView.click();
        await pace(1200);
        await selfView.click();
        await restCursor(lumenCall);

        await cue("Your view is yours alone");
        await pace(300);

        await cue("let the call arrange itself");
        await section(lumenCall, "settings");
        const settings = lumenCall.getByTestId("group-call-settings-panel");
        await focus(settings);
        const auto = settings.getByTestId("group-call-layout-auto");
        await pointAt(lumenCall, auto);
        await auto.click();
        await pace(900);
        await selfView.click();
        await section(lumenCall, "call");
        await focus(null);
        await restCursor(lumenCall);
      },
      { kind: "full", cameras: [LUMEN] },
      voices(LUMEN),
    );
  });

  test("05 play the demo", async () => {
    const shot = shotFor(5);
    const lumenCall = await bandInCall(BAND);
    const bytebard = call(BYTEBARD);
    await bytebard.bringToFront();
    await filmCrew(
      { [LUMEN]: lumenCall, [BYTEBARD]: bytebard },
      shot,
      async ({ cue, focus, layout, pace, talk }) => {
        await talk("ok, new opener");
        await cue("Bytebard shares their screen");
        const share = bytebard.getByTestId("group-call-screen-share-toggle");
        await pointAt(bytebard, share);
        await share.click();
        await restCursor(bytebard);
        const shared = lumenCall.locator(
          '[data-group-call-video-tile][data-local="false"][data-track-source="screen"]',
        );
        await expect(shared).toBeVisible({ timeout: 15_000 });
        await focus(shared);
        await cue("Every note is right there");
        await pace(300);
        await talk("that's a BANGER");
        await talk("play the chorus again");

        await cue("One click to start");
        await focus(null);
        await pointAt(bytebard, share);
        await share.click();
        await restCursor(bytebard);
        await talk("opener or not");

        await cue("Time to vote");
        layout("full", LUMEN);
        // Back to the grid, so every vote lands on a tile big enough to see.
        const grid = lumenCall
          .getByTestId("group-call-view-rail")
          .getByTestId("group-call-layout-grid");
        await pointAt(lumenCall, grid);
        await grid.click();
        await pace(400);
        await cue("Send a heart");
        const votes: [string, string][] = [
          [NOVA, "heart"],
          [PIXEL, "clap"],
          [KESTREL, "laugh"],
          [M0DEM, "thumbs_up"],
          [BYTEBARD, "wow"],
        ];
        await pointAt(
          lumenCall,
          lumenCall.getByTestId("group-call-reactions-toggle"),
        );
        await react(lumenCall, "heart");
        for (const [nick, reaction] of votes) {
          await react(call(nick), reaction);
          await pace(350);
        }
        await restCursor(lumenCall);
        await talk("bus driver approves");
      },
      { kind: "pip", cameras: [LUMEN, BYTEBARD] },
      voices(LUMEN, BYTEBARD),
    );
  });

  test("06 one at a time", async () => {
    const shot = shotFor(6);
    const lumenCall = await bandInCall(BAND);
    const kestrel = call(KESTREL);
    await filmCrew(
      { [LUMEN]: lumenCall, [KESTREL]: kestrel },
      shot,
      async ({ cue, focus, layout, pace, talk }) => {
        await talk("the opener has to be loud");
        await talk("it has to be catchy");
        await talk("why not both");
        await talk("GUYS");

        await cue("Then the opinions start");
        await pace(300);
        await cue("lumen can mute everyone");
        await openModerationMenu(lumenCall);
        const muteAll = lumenCall.getByTestId("group-call-mute-all");
        await pointAt(lumenCall, muteAll);
        await muteAll.click();
        await lumenCall
          .getByTestId("group-call-confirm-dialog-confirm")
          .click();
        await restCursor(lumenCall);

        await cue("Muted by the moderator");
        await focus(lumenCall.getByTestId("group-call-video-grid"));
        await pace(600);
        await focus(null);

        await cue("raise your hand");
        layout("split", LUMEN, KESTREL);
        const hand = kestrel.getByTestId("group-call-hand-toggle");
        await pointAt(kestrel, hand);

        await cue("Kestrel's hand goes up");
        await hand.click();
        await restCursor(kestrel);
        await section(lumenCall, "people");
        const queue = lumenCall.getByTestId("group-call-raised-hand-queue");
        await expect(queue).toBeVisible({ timeout: 10_000 });
        await focus(queue);
        const allow = lumenCall.getByRole("button", {
          name: new RegExp(`Allow ${KESTREL} to speak`),
        });
        await pointAt(lumenCall, allow);
        await allow.click();
        await focus(null);
        await section(lumenCall, "call");
        await restCursor(lumenCall);
        await talk("what if we open with the old one");

        await cue("Nobody needs a microphone");
        layout("full", LUMEN);
        for (const nick of [NOVA, PIXEL, BYTEBARD, M0DEM]) {
          await react(call(nick), "thumbs_up");
          await pace(300);
        }
      },
      { kind: "full", cameras: [LUMEN] },
      voices(LUMEN, KESTREL),
    );
  });

  test("07 uninvited", async () => {
    const shot = shotFor(7);
    const lumenCall = await bandInCall(BAND);
    if (calls.has(HONK)) await leave(HONK);
    await letHonkBackIn();
    const honkDoor = await atTheDoor(HONK);
    await lumenCall.bringToFront();
    await filmCrew(
      { [LUMEN]: lumenCall, [HONK]: honkDoor },
      shot,
      async ({ cue, focus, layout, pace, talk }) => {
        await cue("not everyone is in the band");
        await intoCall(honkDoor);
        calls.set(HONK, honkDoor);
        await honkDoor.evaluate(() =>
          // eslint-disable-next-line @typescript-eslint/no-explicit-any
          (window as any).__directorCamera.flash(9),
        );
        await talk("HONK HONK");

        await cue("Honk joins");
        await pace(600);
        await talk("who invited the goose");

        await cue("Lumen opens honk's menu");
        await participantMenu(lumenCall, HONK);
        const mute = menuItem(lumenCall, HONK, /Mute participant/);
        await pointAt(lumenCall, mute);
        await mute.click();
        await participantMenu(lumenCall, HONK);
        const cameraOff = menuItem(
          lumenCall,
          HONK,
          /Turn participant camera off/,
        );
        await pointAt(lumenCall, cameraOff);
        await cameraOff.click();
        await restCursor(lumenCall);
        await talk("HONK?");

        await cue("They try sharing their screen");
        layout("split", LUMEN, HONK);
        const share = honkDoor.getByTestId("group-call-screen-share-toggle");
        await pointAt(honkDoor, share);
        await share.click();
        await restCursor(honkDoor);
        await participantMenu(lumenCall, HONK);
        const stop = menuItem(
          lumenCall,
          HONK,
          /Stop participant screen sharing/,
        );
        await pointAt(lumenCall, stop);
        await stop.click();
        await restCursor(lumenCall);

        await cue("Everything happens from honk's own row");
        await focus(row(lumenCall, HONK));
        await pace(600);
        await focus(null);

        await cue("Still honking?");
        await participantMenu(lumenCall, HONK);
        const out = menuItem(
          lumenCall,
          HONK,
          /Remove from conference and ban from channel/,
        );
        await pointAt(lumenCall, out);
        await out.click();
        await cue("Out of the call");
        await lumenCall
          .getByTestId("group-call-confirm-dialog-confirm")
          .click();
        calls.delete(HONK);
        await expect(honkDoor.getByTestId("call-left")).toBeVisible({
          timeout: 15_000,
        });
        await focus(honkDoor.getByTestId("call-left"));
        await restCursor(lumenCall);

        await cue("lumen locks the call");
        layout("full", LUMEN);
        await focus(null);
        await openModerationMenu(lumenCall);
        const lock = lumenCall.getByTestId("group-call-lock-toggle");
        await pointAt(lumenCall, lock);
        await lock.click();
        await section(lumenCall, "call");
        await restCursor(lumenCall);
        await talk("rip honk");
        await talk("not really");
      },
      { kind: "full", cameras: [LUMEN] },
      voices(LUMEN),
    );
    await honkDoor.close();
  });

  test("08 on the bus", async () => {
    const shot = shotFor(8);
    const lumenCall = await bandInCall(BAND, { locked: true });
    const m0dem = call(M0DEM);
    await m0dem.bringToFront();
    await filmCrew(
      { [LUMEN]: lumenCall, [M0DEM]: m0dem },
      shot,
      async ({ cue, follow, focus, layout, pace, talk }) => {
        await cue("the manager is on a bus");
        layout("pip", M0DEM, LUMEN);
        await pace(500);

        await cue("keeps the call small");
        const compact = m0dem.getByTestId("group-call-mini-toggle");
        await pointAt(m0dem, compact);
        await compact.click();
        await restCursor(m0dem);

        await cue("the way out stay right there");
        await focus(m0dem.getByTestId("group-call-mini-audio-toggle"));
        await pace(500);
        await focus(null);

        await cue("hold to talk");
        const mic = m0dem.getByTestId("group-call-mini-audio-toggle");
        await pointAt(m0dem, mic);
        await mic.click();
        await restCursor(m0dem);
        await pace(500);
        await m0dem.keyboard.down("Control");
        await m0dem.keyboard.down("Shift");
        await m0dem.keyboard.down("KeyZ");
        await talk("booked the sound check");
        await m0dem.keyboard.up("KeyZ");
        await m0dem.keyboard.up("Shift");
        await m0dem.keyboard.up("Control");
        await talk("legend");

        await cue("the bus brakes");
        const back = member(M0DEM).page;
        await back.bringToFront();
        await follow(back);
        await m0dem.close();
        calls.delete(M0DEM);
        await pace(900);

        await cue("Open it again");
        const again = await member(M0DEM).ctx.newPage();
        await again.goto(address!);
        await follow(again);
        await expect(again.getByTestId("group-call-webrtc")).toBeVisible({
          timeout: 20_000,
        });
        calls.set(M0DEM, again);
        await restCursor(again);
        await talk("did I miss anything");
        await talk("just honk");

        await cue("the Stats tab");
        layout("full", LUMEN);
        const stats = lumenCall.getByTestId("group-call-section-stats");
        await pointAt(lumenCall, stats);
        await stats.click();
        await focus(lumenCall.getByTestId("group-call-inline-stats"));
        await restCursor(lumenCall);
      },
      { kind: "full", cameras: [LUMEN] },
      voices(LUMEN, M0DEM),
    );
    await section(lumenCall, "call");
  });

  test("09 meanwhile, in the channel", async () => {
    const shot = shotFor(9);
    const lumenCall = await bandInCall(BAND, { locked: true });
    const lumenChat = member(LUMEN).page;
    await lumenChat.bringToFront();
    await restCursor(lumenChat);
    await filmCrew(
      { [LUMEN]: lumenChat },
      shot,
      async ({ cue, follow, focus, pace }) => {
        await cue("the channel keeps going");
        await focus(lumenChat.getByTestId("status-bar-group-call"));
        await fans.play(FANS_WAITING);

        await cue("The fans can see");
        await focus(lumenChat.getByTestId("group-call-open"));
        await pace(1200);
        await focus(null);

        await cue("The status bar says where your call is");
        await focus(lumenChat.getByTestId("status-bar-group-call"));
        await pace(600);
        await focus(null);

        await cue("One click on the status bar");
        const bar = lumenChat.getByTestId("status-bar-group-call");
        await pointAt(lumenChat, bar);
        await bar.click();
        await lumenCall.bringToFront();
        await follow(lumenCall);
        await restCursor(lumenCall);
      },
      { kind: "full", cameras: [LUMEN] },
    );
  });

  test("10 setlist done", async () => {
    const shot = shotFor(10);
    const lumenCall = await bandInCall(BAND, { locked: true });
    const lumenChat = member(LUMEN).page;
    await filmCrew(
      { [LUMEN]: lumenCall },
      shot,
      async ({ cue, follow, focus, pace, talk }) => {
        await talk("setlist. done");
        for (const nick of [NOVA, PIXEL, KESTREL]) {
          await react(call(nick), "heart");
          await pace(250);
        }
        await talk("FRIDAY");
        await talk("see you all at the Cellar");

        await cue("Leave whenever you're done");
        for (const nick of [PIXEL, KESTREL]) {
          await leave(nick);
          await pace(500);
        }
        await openModerationMenu(lumenCall);
        const end = lumenCall.getByTestId("group-call-close-room");
        await pointAt(lumenCall, end);
        await end.click();
        await lumenCall
          .getByTestId("group-call-confirm-dialog-confirm")
          .click();

        await cue("becomes the record of the call");
        await lumenChat.bringToFront();
        await follow(lumenChat);
        const record = lumenChat.getByTestId("share-message-card").last();
        await expect(record).toContainText(/ended|ran|lasted/i, {
          timeout: 15_000,
        });
        // It was written when the call opened; lumen scrolls back up to it.
        await record.scrollIntoViewIfNeeded();
        await focus(record);
        await restCursor(lumenChat);

        await cue("Nothing to install");
        await focus(null);
        await fans.say(LUMEN, "setlist's done. see you friday 🎸");
        await cue("Just your people");
        await fans.say("wren", "FRIDAY!! 🎉");
        await fans.say("sol", "front row, as always");
      },
      { kind: "full", cameras: [LUMEN] },
      voices(LUMEN),
    );
    for (const page of calls.values()) if (!page.isClosed()) await page.close();
    calls.clear();
  });

  // Filmed last: a call opened first would put its card at the top of the
  // channel that scene 1 shows quiet.
  test("00 cold open", async () => {
    const shot = shotFor(0);
    const lumenCall = await bandInCall(BAND);
    const voice = (nick: string, seconds: number) =>
      call(nick).evaluate(
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        ([k, s]) => (window as any).__directorCamera[k as string](s),
        ["talk", seconds] as const,
      );
    const wave = (nick: string) =>
      call(nick).evaluate(() =>
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        (window as any).__directorCamera.wave(2.4),
      );
    await filmCrew(
      { [LUMEN]: lumenCall },
      shot,
      async ({ cue, focus, pace }) => {
        for (const nick of BAND) {
          await wave(nick);
          await pace(180);
        }
        await focus(lumenCall.getByTestId("group-call-video-grid"));

        await cue("Everyone talking at once");
        for (const nick of [PIXEL, NOVA, BYTEBARD, M0DEM]) {
          await voice(nick, 1.4);
          await pace(350);
        }

        await cue("This is band practice");
        for (const [nick, reaction] of [
          [NOVA, "heart"],
          [PIXEL, "clap"],
          [KESTREL, "wow"],
          [BYTEBARD, "laugh"],
          [M0DEM, "thumbs_up"],
        ] as const) {
          await react(call(nick), reaction);
          await pace(200);
        }
      },
      { kind: "full", cameras: [LUMEN] },
      voices(LUMEN),
    );
  });
});
