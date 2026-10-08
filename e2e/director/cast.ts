import { Browser } from "@playwright/test";
import { closeUsers, knownSignedInUser, TestUser } from "../helpers/chatUsers";

/**
 * The people already in the room when the camera arrives.
 *
 * Each member is signed in through a browser context of its own — a separate
 * person to the server — and is never filmed. A scene on camera then shows a
 * populated channel: a full user list, a conversation to scroll back through,
 * and people who answer.
 */

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
    for (const nick of nicks) {
      members.set(nick, await knownSignedInUser(browser, nick, password));
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
