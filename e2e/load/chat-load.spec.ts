import { Browser, BrowserContext, Page, expect, test } from "@playwright/test";
import fs from "node:fs";
import { ChatPage } from "../pages/ChatPage";
import { ConnectPage } from "../pages/ConnectPage";
import { installSyntheticMedia } from "../helpers/syntheticMedia";

// Realistic mixed-flow load scenario, chat-focused. One browser process,
// LOAD_USERS isolated contexts, each running a persona loop until the
// steady-state deadline:
//
//   chatter   sends messages at a human cadence, switches tabs, scrolls
//   observer  idles on a channel and timestamps every tagged message it
//             sees (delivery-latency probe for the whole channel)
//   space     enters the virtual space and walks/attacks continuously
//   call      joins a group call (SFU — real server-side media) in pairs
//
// Message cadence stays under the server limits (5 msg/s + flood 10/15s per
// nick) on purpose: the goal is N realistic users, not a flood test.
//
// Every chat message carries a token like "(t3x12)". Observers record
// first-seen wall-clock time per token via a MutationObserver; the test
// records send time per token in Node. Both clocks are the generator
// machine's, so end-to-end delivery latency = seen - sent.

const USERS = Number(process.env.LOAD_USERS) || 20;
const DURATION_MS = Number(process.env.LOAD_DURATION_MS) || 180_000;
const BASE_URL = process.env.LOAD_BASE_URL || "https://retrohexchat.app";
// How many users connect simultaneously per ramp-up wave. Raise it
// (LOAD_RAMP_BATCH) to turn the ramp itself into a connection burst.
const RAMP_BATCH = Number(process.env.LOAD_RAMP_BATCH) || 4;

type Role = "chatter" | "observer" | "space" | "call";

type LoadUser = {
  role: Role;
  idx: number;
  nick: string;
  ctx: BrowserContext;
  page: Page;
  chat: ChatPage;
  channel: string;
  otherChannel: string | null;
  sent: number;
  errors: string[];
};

const CORPUS = [
  "anyone around?",
  "just shipped a fix, feeling good",
  "did you see the topic change",
  "brb coffee",
  "that last message cracked me up",
  "who is up for a call later",
  "the space map looks great today",
  "lag check, how is everyone",
  "reading the backlog now",
  "same time tomorrow?",
  "nice one",
  "agreed, let's do that",
  "hmm not sure about that",
  "can someone share the link again",
  "old school chat still rules",
];

const EMOTES = ["waves", "laughs", "nods", "looks around", "stretches"];

const ARROWS = ["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight"];

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));
const rand = (min: number, max: number) => min + Math.random() * (max - min);
const pick = <T>(arr: T[]): T => arr[Math.floor(Math.random() * arr.length)];

function trackError(user: LoadUser, err: unknown) {
  user.errors.push(String(err).slice(0, 300));
}

// Observers timestamp the first DOM appearance of each "(tNxM)" token.
async function installTokenRecorder(page: Page) {
  await page.addInitScript(() => {
    const seen: Record<string, number> = {};
    (window as unknown as { __ldSeen: Record<string, number> }).__ldSeen = seen;
    const rx = /\(t\d+x\d+\)/g;
    const record = (text: string | null) => {
      if (!text) return;
      const hits = text.match(rx);
      if (!hits) return;
      for (const hit of hits) if (!(hit in seen)) seen[hit] = Date.now();
    };
    const observer = new MutationObserver((mutations) => {
      for (const mutation of mutations) {
        if (mutation.type === "characterData") {
          record(mutation.target.textContent);
        }
        for (const node of Array.from(mutation.addedNodes)) {
          record(node.textContent);
        }
      }
    });
    observer.observe(document, {
      childList: true,
      subtree: true,
      characterData: true,
    });
  });
}

type ConnectFailure = {
  idx: number;
  role: Role;
  nick: string;
  step: string;
  url: string;
  visibleText: string;
  consoleErrors: string[];
  error: string;
};

async function connectUser(
  browser: Browser,
  role: Role,
  idx: number,
  channel: string,
  nick: string,
  onFail: (failure: ConnectFailure) => void,
): Promise<LoadUser | null> {
  const ctx = await browser.newContext(
    role === "call" ? { permissions: ["microphone", "camera"] } : {},
  );
  if (role === "call") await installSyntheticMedia(ctx);

  const page = await ctx.newPage();
  const consoleErrors: string[] = [];
  page.on("console", (msg) => {
    if (msg.type() === "error") consoleErrors.push(msg.text().slice(0, 200));
  });
  page.on("pageerror", (err) =>
    consoleErrors.push(`pageerror: ${err.message}`),
  );

  if (role === "observer") await installTokenRecorder(page);

  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);

  // Step labels attribute a failure to a phase: page load (generator/WAN),
  // nickname (rejected/taken → "nick zuado"), register (collision routed to
  // the auth step), handshake (LiveView mount / socket capacity), or composer
  // (server render latency after mount).
  let step = "open";
  try {
    await connect.open();
    step = "nickname";
    await connect.enterNickname(nick);
    step = "register";
    await connect.registerWithPassword("loadpass1");
    step = "handshake";
    await chat.waitUntilConnected();
    step = "join";
    await chat.sendMessage(`/join ${channel}`);
    await chat.expectTabVisible(channel);
    await chat.switchToTab(channel);
  } catch (err) {
    const visibleText = await page
      .locator("body")
      .innerText()
      .then((t) => t.replace(/\s+/g, " ").trim().slice(0, 300))
      .catch(() => "");
    onFail({
      idx,
      role,
      nick,
      step,
      url: page.url(),
      visibleText,
      consoleErrors: consoleErrors.slice(-5),
      error: String(err).split("\n")[0].slice(0, 200),
    });
    await ctx.close().catch(() => {});
    return null;
  }

  return {
    role,
    idx,
    nick,
    ctx,
    page,
    chat,
    channel,
    otherChannel: null,
    sent: 0,
    errors: [],
  };
}

// Fill first, timestamp, then submit — so the recorded send time excludes
// the typing overhead and measures submit → delivery.
async function sendTimed(
  user: LoadUser,
  text: string,
  sentAt: Map<string, number>,
) {
  const token = `(t${user.idx}x${user.sent})`;
  await expect(user.chat.chatInput).toBeEnabled();
  await user.chat.chatInput.fill(`${text} ${token}`);
  sentAt.set(token, Date.now());
  await user.chat.chatInput.press("Enter");
  user.sent += 1;
}

async function runChatter(
  user: LoadUser,
  deadline: number,
  sentAt: Map<string, number>,
) {
  while (Date.now() < deadline && user.errors.length < 8) {
    await sleep(rand(6_000, 15_000));
    if (Date.now() >= deadline) break;
    try {
      const roll = Math.random();
      if (roll < 0.78) {
        await sendTimed(user, pick(CORPUS), sentAt);
      } else if (roll < 0.86 && user.otherChannel) {
        await user.chat.switchToTab(user.otherChannel);
        [user.channel, user.otherChannel] = [user.otherChannel, user.channel];
      } else if (roll < 0.94) {
        await user.chat.scrollMessagesToTop();
        await sleep(rand(1_000, 3_000));
        await user.chat.scrollMessagesToBottom();
      } else {
        await sendTimed(user, `/me ${pick(EMOTES)}`, sentAt);
      }
    } catch (err) {
      trackError(user, err);
    }
  }
}

async function runSpace(user: LoadUser, deadline: number) {
  const page = user.page;
  try {
    await page
      .locator(
        '[data-testid="topic-bar"] [data-testid="channel-view-tabs"] button[phx-value-view="space"]',
      )
      .click();
    const picker = page.getByTestId("space-character-select");
    await expect(picker).toBeVisible();
    const avatars = picker.locator('[data-testid^="space-avatar-"]');
    const avatarCount = await avatars.count();
    await avatars.nth(Math.floor(Math.random() * avatarCount)).click();
    const canvas = page.locator('[data-testid="channel-space-shell"] canvas');
    await expect(canvas).toBeVisible();
    // Over a WAN the sprite atlases load slowly and a loading overlay can
    // cover the canvas for a while. The click only grants keyboard focus,
    // so fall back to a forced click instead of aborting the persona.
    try {
      await canvas.click({ timeout: 30_000 });
    } catch {
      await canvas.click({ force: true }).catch(() => {});
    }
  } catch (err) {
    trackError(user, err);
    return;
  }

  while (Date.now() < deadline && user.errors.length < 8) {
    try {
      const key = pick(ARROWS);
      await user.page.keyboard.down(key);
      await sleep(rand(250, 900));
      await user.page.keyboard.up(key);
      if (Math.random() < 0.2) await user.page.keyboard.press("Space");
      await sleep(rand(200, 1_200));
    } catch (err) {
      trackError(user, err);
    }
  }
}

async function runCall(user: LoadUser, deadline: number, video: boolean) {
  const page = user.page;
  try {
    await page.getByTestId("group-call-open").click();
    await expect(
      page.locator("#group-call-prejoin-dialog-surface"),
    ).toBeVisible();
    await page.getByTestId("group-call-prejoin-audio").setChecked(true);
    await page.getByTestId("group-call-prejoin-video-toggle").setChecked(video);
    await page.getByTestId("group-call-prejoin-join").click();
    await expect(page.getByTestId("group-call-panel")).toBeVisible({
      timeout: 20_000,
    });
  } catch (err) {
    trackError(user, err);
    return;
  }

  while (Date.now() < deadline && user.errors.length < 8) {
    await sleep(rand(30_000, 60_000));
    if (Date.now() >= deadline) break;
    try {
      await page.getByTestId("group-call-audio-toggle").click();
    } catch (err) {
      trackError(user, err);
    }
  }

  try {
    await page.getByTestId("group-call-leave").click();
    await page.getByTestId("group-call-confirm-dialog-confirm").click();
  } catch {
    // Context close tears the call down anyway.
  }
}

function percentile(sorted: number[], p: number): number {
  if (sorted.length === 0) return 0;
  const at = Math.min(sorted.length - 1, Math.floor((p / 100) * sorted.length));
  return sorted[at];
}

test("realistic mixed load, chat-focused", async ({ browser }) => {
  const runId = Math.random().toString(36).slice(2, 7);
  const channels =
    USERS >= 10 ? [`#ld${runId}a`, `#ld${runId}b`] : [`#ld${runId}a`];

  const spaceCount = USERS >= 10 ? 2 : USERS >= 5 ? 1 : 0;
  const callCount = USERS >= 10 ? 2 : 0;
  const observerCount = Math.min(channels.length, Math.max(1, USERS - 2));
  const chatterCount = USERS - spaceCount - callCount - observerCount;

  const roles: { role: Role; channel: string }[] = [];
  for (let i = 0; i < observerCount; i++) {
    roles.push({ role: "observer", channel: channels[i % channels.length] });
  }
  // Call pair shares channels[0]; space pair shares the last channel so the
  // walkers can actually meet (and fight) each other.
  for (let i = 0; i < callCount; i++) {
    roles.push({ role: "call", channel: channels[0] });
  }
  for (let i = 0; i < spaceCount; i++) {
    roles.push({ role: "space", channel: channels[channels.length - 1] });
  }
  for (let i = 0; i < chatterCount; i++) {
    roles.push({ role: "chatter", channel: channels[i % channels.length] });
  }

  console.log(
    `[load] target=${BASE_URL} users=${USERS} ` +
      `(chatters=${chatterCount} observers=${observerCount} ` +
      `space=${spaceCount} call=${callCount}) ` +
      `duration=${Math.round(DURATION_MS / 1000)}s channels=${channels.join(",")}`,
  );

  // Ramp up in batches. RAMP_BATCH users connect at once per wave — raise it
  // to burst the connection storm. Individual failures are dropped, not fatal.
  // Nicks are runId+idx: globally unique (prod keeps every registration) and
  // always valid, so a failure can never be a nickname collision.
  const users: LoadUser[] = [];
  const connectErrors: ConnectFailure[] = [];
  const rampStart = Date.now();
  for (let at = 0; at < roles.length; at += RAMP_BATCH) {
    const batch = roles.slice(at, at + RAMP_BATCH);
    const connected = await Promise.all(
      batch.map((r, j) => {
        const idx = at + j;
        const nick = `ldt${runId}${idx}`;
        return connectUser(browser, r.role, idx, r.channel, nick, (f) =>
          connectErrors.push(f),
        );
      }),
    );
    for (const user of connected) if (user) users.push(user);
    console.log(
      `[load] connected ${users.length}/${roles.length}` +
        (connectErrors.length ? ` (${connectErrors.length} failed)` : ""),
    );
    if (at + RAMP_BATCH < roles.length) await sleep(rand(500, 1_500));
  }
  const connectFailures = connectErrors.length;
  if (connectFailures > 0) {
    const byStep: Record<string, number> = {};
    for (const f of connectErrors) byStep[f.step] = (byStep[f.step] || 0) + 1;
    console.log(`[load] connect failures by step: ${JSON.stringify(byStep)}`);
  }

  // A third of the chatters live in both channels and hop between them.
  if (channels.length > 1) {
    const chatters = users.filter((u) => u.role === "chatter");
    for (const user of chatters.filter((_, i) => i % 3 === 0)) {
      const other = channels.find((c) => c !== user.channel);
      if (!other) continue;
      try {
        await user.chat.sendMessage(`/join ${other}`);
        await user.chat.expectTabVisible(other);
        await user.chat.switchToTab(user.channel);
        user.otherChannel = other;
      } catch (err) {
        trackError(user, err);
      }
    }
  }

  const rampMs = Date.now() - rampStart;
  console.log(
    `[load] ramp-up done in ${Math.round(rampMs / 1000)}s, steady state begins`,
  );

  const deadline = Date.now() + DURATION_MS;
  const sentAt = new Map<string, number>();
  let callVideo = true;

  await Promise.all(
    users.map((user) => {
      switch (user.role) {
        case "chatter":
          return runChatter(user, deadline, sentAt);
        case "space":
          return runSpace(user, deadline);
        case "call": {
          const video = callVideo;
          callVideo = false;
          return runCall(user, deadline, video);
        }
        case "observer":
          return sleep(Math.max(0, deadline - Date.now()));
      }
    }),
  );

  // Grace period so in-flight messages reach the observers before we read.
  await sleep(5_000);

  const observers = users.filter((u) => u.role === "observer");
  const seen = new Map<string, number>();
  for (const observer of observers) {
    const map = await observer.page
      .evaluate(
        () =>
          (window as unknown as { __ldSeen?: Record<string, number> })
            .__ldSeen || {},
      )
      .catch(() => ({}) as Record<string, number>);
    for (const [token, ts] of Object.entries(map)) {
      const prev = seen.get(token);
      if (prev === undefined || ts < prev) seen.set(token, ts);
    }
  }

  const latencies: number[] = [];
  let lost = 0;
  for (const [token, sent] of sentAt) {
    const arrival = seen.get(token);
    if (arrival === undefined) lost += 1;
    else latencies.push(Math.max(0, arrival - sent));
  }
  latencies.sort((a, b) => a - b);

  const totalSent = users.reduce((sum, u) => sum + u.sent, 0);
  const errors = users
    .filter((u) => u.errors.length > 0)
    .map((u) => ({ nick: u.nick, role: u.role, errors: u.errors }));

  const report = {
    target: BASE_URL,
    startedAt: new Date(rampStart).toISOString(),
    users: USERS,
    connected: users.length,
    connectFailures,
    roles: { chatterCount, observerCount, spaceCount, callCount },
    channels,
    rampMs,
    durationMs: DURATION_MS,
    messagesSent: totalSent,
    delivery: {
      measured: latencies.length,
      lost,
      p50Ms: percentile(latencies, 50),
      p95Ms: percentile(latencies, 95),
      p99Ms: percentile(latencies, 99),
      maxMs: latencies[latencies.length - 1] ?? 0,
    },
    connectErrors,
    errors,
  };

  fs.mkdirSync("test-results", { recursive: true });
  const reportPath = `test-results/load-report-${runId}.json`;
  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));

  console.log(
    `[load] connected=${users.length}/${USERS} failed=${connectFailures} ` +
      `sent=${totalSent} measured=${latencies.length} lost=${lost} ` +
      `p50=${report.delivery.p50Ms}ms p95=${report.delivery.p95Ms}ms ` +
      `p99=${report.delivery.p99Ms}ms max=${report.delivery.maxMs}ms`,
  );
  console.log(`[load] report: e2e/${reportPath}`);
  if (connectFailures > 0) {
    console.log(
      `[load] ${connectFailures} user(s) never connected — a load finding, ` +
        `not a harness fault (see report)`,
    );
  }
  if (errors.length > 0) {
    console.log(
      `[load] ${errors.length} connected user(s) hit errors mid-run — see report`,
    );
  }

  await Promise.all(users.map((u) => u.ctx.close().catch(() => {})));

  // Sanity floor, not a benchmark threshold: enough of the cohort must have
  // connected and delivered for the run to mean anything. Connect failures and
  // latency under load are findings we REPORT, not reasons to fail the run.
  expect(users.length).toBeGreaterThan(0);
  expect(latencies.length).toBeGreaterThan(0);
  expect(lost / Math.max(1, sentAt.size)).toBeLessThan(0.2);
});
