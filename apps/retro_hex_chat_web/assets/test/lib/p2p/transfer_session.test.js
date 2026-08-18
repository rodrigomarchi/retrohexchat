import { describe, expect, it } from "vitest";

import { STATE } from "../../../js/lib/p2p/file_transfer.js";
import { EFFECT, step } from "../../../js/lib/p2p/transfer_session.js";

const now = () => 1000;

function senderSession(over = {}) {
  return { role: "sender", transferId: "t1", fileName: "a.txt", state: STATE.OFFERING, ...over };
}
function receiverSession(over = {}) {
  return { role: "receiver", transferId: "t1", fileName: "a.txt", state: STATE.OFFERING, ...over };
}

const kinds = (effects) => effects.map((e) => e.type);
const pushed = (effects) => effects.filter((e) => e.type === EFFECT.PUSH).map((e) => e.event);

describe("step — unknown or missing", () => {
  it("is a no-op for an unknown event", () => {
    const s = senderSession();
    const { session, effects } = step(s, { type: "nope" }, { now });
    expect(session).toBe(s);
    expect(effects).toEqual([]);
  });

  it("is a no-op when there is no session", () => {
    expect(step(null, { type: "peer_accept" }, { now }).effects).toEqual([]);
  });
});

describe("peer_accept", () => {
  it("sender starts transferring and sending", () => {
    const s = senderSession();
    const { session, effects } = step(s, { type: "peer_accept" }, { now });
    expect(session.state).toBe(STATE.TRANSFERRING);
    expect(session.startTime).toBe(1000);
    expect(kinds(effects)).toContain(EFFECT.START_SENDING);
    expect(pushed(effects)).toContain("ft_accepted");
  });

  it("receiver acknowledges with a FILE_ACCEPT control message", () => {
    const s = receiverSession();
    const { effects } = step(s, { type: "peer_accept" }, { now });
    const send = effects.find((e) => e.type === EFFECT.SEND_CONTROL);
    expect(send).toBeTruthy();
    expect(kinds(effects)).not.toContain(EFFECT.START_SENDING);
  });
});

describe("peer_reject", () => {
  it("sender cleans up and processes the queue", () => {
    const { session, effects } = step(senderSession(), { type: "peer_reject" }, { now });
    expect(session).toBeNull();
    expect(pushed(effects)).toContain("ft_rejected");
    expect(kinds(effects)).toContain(EFFECT.PROCESS_QUEUE);
  });

  it("receiver sends a reject before cleaning up", () => {
    const { session, effects } = step(receiverSession(), { type: "peer_reject" }, { now });
    expect(session).toBeNull();
    expect(effects.some((e) => e.type === EFFECT.SEND_CONTROL)).toBe(true);
  });
});

describe("hash results", () => {
  it("sender completion cleans up and stops progress", () => {
    const { session, effects } = step(
      senderSession(),
      { type: "sender_hash_result", match: true },
      { now },
    );
    expect(session).toBeNull();
    expect(pushed(effects)).toContain("ft_completed");
    expect(kinds(effects)).toContain(EFFECT.STOP_PROGRESS);
  });

  it("sender mismatch fails without cleanup", () => {
    const { session, effects } = step(
      senderSession(),
      { type: "sender_hash_result", match: false },
      { now },
    );
    expect(session.state).toBe(STATE.FAILED);
    expect(pushed(effects)).toContain("ft_failed");
  });

  it("receiver match downloads then completes", () => {
    const blob = { size: 1 };
    const { session, effects } = step(
      receiverSession(),
      { type: "receiver_hash_result", match: true, blob },
      { now },
    );
    expect(session).toBeNull();
    const download = effects.find((e) => e.type === EFFECT.DOWNLOAD);
    expect(download.blob).toBe(blob);
  });

  it("receiver mismatch fails", () => {
    const { session, effects } = step(
      receiverSession(),
      { type: "receiver_hash_result", match: false },
      { now },
    );
    expect(session.state).toBe(STATE.FAILED);
    expect(pushed(effects)).toContain("ft_failed");
  });
});

describe("cancel", () => {
  it("local cancel sends CANCEL only when the channel is open (requireOpen)", () => {
    const { session, effects } = step(
      senderSession(),
      { type: "local_cancel", nickname: "ana" },
      { now },
    );
    expect(session).toBeNull();
    const send = effects.find((e) => e.type === EFFECT.SEND_CONTROL);
    expect(send.requireOpen).toBe(true);
    expect(pushed(effects)).toContain("ft_cancelled");
  });

  it("incoming cancel cleans up without sending", () => {
    const { session, effects } = step(
      receiverSession(),
      { type: "incoming_cancel", cancelledBy: "bob" },
      { now },
    );
    expect(session).toBeNull();
    expect(effects.some((e) => e.type === EFFECT.SEND_CONTROL)).toBe(false);
  });
});

describe("channel_close", () => {
  it("pauses a transferring session", () => {
    const { session, effects } = step(
      senderSession({ state: STATE.TRANSFERRING }),
      { type: "channel_close" },
      { now },
    );
    expect(session.state).toBe(STATE.PAUSED);
    expect(pushed(effects)).toContain("ft_paused");
  });

  it("does nothing to a completed session", () => {
    const { session, effects } = step(
      senderSession({ state: STATE.COMPLETED }),
      { type: "channel_close" },
      { now },
    );
    expect(session.state).toBe(STATE.COMPLETED);
    expect(effects).toEqual([]);
  });
});

describe("resume and retry", () => {
  it("incoming_have_chunks marks chunks and resumes sending", () => {
    const s = senderSession({
      state: STATE.PAUSED,
      receivedSet: new Set(),
      totalChunks: 3,
      sentSet: new Set(),
    });
    const { session, effects } = step(
      s,
      { type: "incoming_have_chunks", indices: [0, 1] },
      { now },
    );
    expect(session.state).toBe(STATE.TRANSFERRING);
    expect(session.nextChunkIndex).toBe(0);
    expect(kinds(effects)).toContain(EFFECT.START_SENDING);
    expect(pushed(effects)).toContain("ft_resumed");
  });

  it("retry_request resets the sender and re-sends", () => {
    const s = senderSession({ sentSet: new Set([1]), bytesSent: 99, nextChunkIndex: 5 });
    const { session, effects } = step(s, { type: "retry_request" }, { now });
    expect(session.sentSet.size).toBe(0);
    expect(session.bytesSent).toBe(0);
    expect(session.state).toBe(STATE.TRANSFERRING);
    expect(kinds(effects)).toContain(EFFECT.START_SENDING);
  });

  it("incoming_retry resets the receiver", () => {
    const s = receiverSession({ totalChunks: 4, receivedSet: new Set([1]), bytesReceived: 50 });
    const { session, effects } = step(s, { type: "incoming_retry" }, { now });
    expect(session.chunks).toHaveLength(4);
    expect(session.bytesReceived).toBe(0);
    expect(pushed(effects)).toContain("ft_progress");
  });

  it("role guards: incoming_have_chunks ignores a receiver", () => {
    const { effects } = step(
      receiverSession(),
      { type: "incoming_have_chunks", indices: [] },
      { now },
    );
    expect(effects).toEqual([]);
  });
});
