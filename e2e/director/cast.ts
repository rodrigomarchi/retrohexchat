import { Browser } from "@playwright/test";
import { closeUsers, TestUser } from "../helpers/chatUsers";
import { ChatPage } from "../pages/ChatPage";
import { ConnectPage } from "../pages/ConnectPage";
import { installTestCard } from "./media";

/**
 * The people already in the room when the camera arrives.
 *
 * Each member is signed in through a browser context of its own — a separate
 * person to the server — and is never filmed. A scene on camera then shows a
 * populated channel: a full user list, a conversation to scroll back through,
 * and people who answer.
 */

/**
 * Where each member says they are. A user's profile card shows the time zone
 * their browser reports; a context left on defaults would report the machine
 * filming — so every member gets one of their own, and the room reads as
 * people from around the world.
 */
const TIME_ZONES = [
  "Europe/Lisbon",
  "America/New_York",
  "Europe/Berlin",
  "Asia/Tokyo",
  "America/Chicago",
  "Australia/Sydney",
  "America/Vancouver",
  "Europe/Stockholm",
];

/** One line of dialogue: who says it and how long they wait afterwards (ms). */
export type Line = { by: string; says: string; then?: number };

/** A pause between two lines, so the conversation does not read as a burst. */
const DEFAULT_GAP = 700;

export class Cast {
  private constructor(
    private readonly browser: Browser,
    private readonly password: string,
    private readonly members: Map<string, TestUser>,
  ) {}

  /**
   * Signs the members in, in order. On a fresh database the first one to join
   * a channel founds it and becomes its owner, so the order is casting.
   */
  static async assemble(
    browser: Browser,
    nicks: string[],
    password: string,
  ): Promise<Cast> {
    const cast = new Cast(browser, password, new Map());
    for (const nick of nicks) await cast.enter(nick);
    return cast;
  }

  /**
   * Signs one more person in — someone who walks in mid-scene. A new member
   * lands in #lobby, as every newly connected user does.
   */
  async enter(nick: string): Promise<TestUser> {
    return this.enterAs(nick, this.password);
  }

  /** Signs in someone with a password of their own — the server operator. */
  async enterAs(nick: string, password: string): Promise<TestUser> {
    const ctx = await this.browser.newContext({
      locale: "en-US",
      timezoneId: TIME_ZONES[this.members.size % TIME_ZONES.length],
    });
    // Anyone may be pulled into a call on camera.
    await installTestCard(ctx, nick);
    const page = await ctx.newPage();
    const connect = new ConnectPage(page);
    const chat = new ChatPage(page);
    await connect.open();
    await connect.signIn(nick, password);
    await chat.waitUntilConnected();
    const member = { chat, connect, ctx, page, nick, password };
    this.members.set(nick, member);
    return member;
  }

  /**
   * Counts someone signed in elsewhere — a person on film, in a browser of
   * their own — as one of the cast, so `say` and `play` can speak for them.
   */
  adopt(member: TestUser): void {
    this.members.set(member.nick, member);
  }

  get nicks(): string[] {
    return [...this.members.keys()];
  }

  member(nick: string): TestUser {
    const member = this.members.get(nick);
    if (!member) throw new Error(`${nick} is not in the cast (${this.nicks})`);
    return member;
  }

  /**
   * Says a line, and waits until the speaker's own screen shows it: a line the
   * server refused (flood control, a missing privilege) fails here instead of
   * leaving a hole in the scene.
   */
  async say(nick: string, text: string): Promise<void> {
    const { chat } = this.member(nick);
    await chat.sendMessage(text);
    if (!text.startsWith("/")) await chat.expectMessageVisible(text);
  }

  /** Runs a command — `/topic`, `/op` — whose result is not a line of chat. */
  async command(nick: string, command: string): Promise<void> {
    await this.member(nick).chat.sendMessage(command);
  }

  async play(lines: Line[]): Promise<void> {
    for (const line of lines) {
      await this.say(line.by, line.says);
      await this.member(line.by).page.waitForTimeout(line.then ?? DEFAULT_GAP);
    }
  }

  /** Sends a member off — `/quit`, so they leave every channel at once. */
  async leave(nick: string, command = "/quit"): Promise<void> {
    const member = this.member(nick);
    await member.chat.sendMessage(command);
    await member.ctx.close();
    this.members.delete(nick);
  }

  async dismiss(): Promise<void> {
    await closeUsers([...this.members.values()]);
  }
}
