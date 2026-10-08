import { Browser } from "@playwright/test";
import { closeUsers, TestUser } from "../helpers/chatUsers";
import { ChatPage } from "../pages/ChatPage";
import { ConnectPage } from "../pages/ConnectPage";

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
  private constructor(private readonly members: Map<string, TestUser>) {}

  /**
   * Signs the members in, in order. On a fresh database the first one to join
   * a channel founds it and becomes its owner, so the order is casting.
   */
  static async assemble(
    browser: Browser,
    nicks: string[],
    password: string,
  ): Promise<Cast> {
    const members = new Map<string, TestUser>();
    for (const [i, nick] of nicks.entries()) {
      const ctx = await browser.newContext({
        locale: "en-US",
        timezoneId: TIME_ZONES[i % TIME_ZONES.length],
      });
      const page = await ctx.newPage();
      const connect = new ConnectPage(page);
      const chat = new ChatPage(page);
      await connect.open();
      await connect.signIn(nick, password);
      await chat.waitUntilConnected();
      members.set(nick, { chat, connect, ctx, page, nick, password });
    }
    return new Cast(members);
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

  async dismiss(): Promise<void> {
    await closeUsers([...this.members.values()]);
  }
}
