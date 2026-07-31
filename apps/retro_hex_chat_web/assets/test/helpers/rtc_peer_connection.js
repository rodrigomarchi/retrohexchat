/**
 * An RTCPeerConnection double that enforces the rules browsers enforce.
 *
 * A permissive stub — one where `setRemoteDescription` is a plain assignment —
 * accepts negotiation sequences that Chrome rejects outright, so a hook can be
 * green in jsdom and loop forever in a real call. This double models the two
 * rules that actually fire in production:
 *
 *   1. The signaling state machine. An answer is only applicable in
 *      `have-local-offer`; an offer only in `stable` or `have-remote-offer`.
 *   2. m-line ordering. A subsequent offer may append m-lines but never reorder
 *      the ones already negotiated, and an answer must mirror its offer exactly.
 *
 * Violations throw the same DOMException name and message Chrome throws, so a
 * failing assertion reads like the browser console.
 *
 * SDP here is not opaque: it carries one `m=` line per transceiver, in
 * transceiver order, which is what makes ordering observable.
 */

/** Build an SDP whose m-line order mirrors `kinds`. */
export function sdpFor(kinds) {
  const lines = ["v=0", "o=- 0 0 IN IP4 127.0.0.1", "s=-", "t=0 0"];
  for (const kind of kinds) {
    lines.push(`m=${kind} 9 UDP/TLS/RTP/SAVPF 96`);
    lines.push("c=IN IP4 0.0.0.0");
  }
  return lines.join("\r\n");
}

/** Extract the m-line kinds from an SDP, in order. */
export function mLinesOf(sdp) {
  if (typeof sdp !== "string") return [];
  return Array.from(sdp.matchAll(/^m=(\w+)/gm)).map((match) => match[1]);
}

function domException(name, message) {
  const error = new Error(message);
  error.name = name;
  return error;
}

function wrongState(type, state) {
  return domException(
    "InvalidStateError",
    `Failed to execute 'setRemoteDescription' on 'RTCPeerConnection': ` +
      `Failed to set remote ${type} sdp: Called in wrong state: ${state}`,
  );
}

export class FakeDataChannel {
  constructor(label, options) {
    this.label = label;
    this.ordered = options?.ordered ?? true;
    this.readyState = "connecting";
    this.binaryType = "arraybuffer";
    this.onopen = null;
    this.onclose = null;
    this.onmessage = null;
  }

  close() {
    this.readyState = "closed";
  }
}

export class FakeRTCPeerConnection {
  constructor(config = {}) {
    this.config = config;
    this.localDescription = null;
    this.remoteDescription = null;
    this.connectionState = "new";
    this.iceConnectionState = "new";
    this.signalingState = "stable";
    this.onconnectionstatechange = null;
    this.oniceconnectionstatechange = null;
    this.onicecandidate = null;
    this.onicecandidateerror = null;
    this.onnegotiationneeded = null;
    this.ondatachannel = null;
    this.ontrack = null;
    this.addedCandidates = [];
    this.transceivers = [];
    this.statsQueue = [];
    this.restartIce = vi.fn();

    // The m-line layout agreed by the last completed negotiation. Ordering
    // rules are enforced against this, not against the live transceiver list.
    this.negotiatedMLines = null;
  }

  // --- Media / transport surface ---

  createDataChannel(label, options) {
    return new FakeDataChannel(label, options);
  }

  addTransceiver(kind, init = {}) {
    const transceiver = {
      receiver: { track: { kind } },
      sender: { track: null, replaceTrack: vi.fn() },
      direction: init.direction || "sendrecv",
      stop: vi.fn(),
    };
    this.transceivers.push(transceiver);
    return transceiver;
  }

  // Reuses a compatible unused transceiver before appending one, which is why
  // publishing local media after a remote offer does not add m-lines to it.
  addTrack(track, _stream) {
    const existing = this.transceivers.find(
      (t) => !t.sender.track && t.receiver.track.kind === track.kind,
    );
    if (existing) {
      existing.sender.track = track;
      existing.direction = "sendrecv";
      return existing.sender;
    }
    const transceiver = this.addTransceiver(track.kind, { direction: "sendrecv" });
    transceiver.sender.track = track;
    return transceiver.sender;
  }

  removeTrack(sender) {
    const transceiver = this.transceivers.find((t) => t.sender === sender);
    if (transceiver) transceiver.sender.track = null;
  }

  getTransceivers() {
    return this.transceivers;
  }

  getReceivers() {
    return this.transceivers.map((t) => t.receiver);
  }

  getSenders() {
    return this.transceivers.map((t) => t.sender);
  }

  async addIceCandidate(candidate) {
    this.addedCandidates.push(candidate);
  }

  async getStats() {
    return this.statsQueue.shift() || new Map();
  }

  close() {
    this.connectionState = "closed";
    this.signalingState = "closed";
  }

  // --- Negotiation ---

  /** The m-line layout this side would put on the wire right now. */
  currentMLines() {
    return this.transceivers.map((t) => t.receiver.track.kind);
  }

  async createOffer() {
    return { type: "offer", sdp: sdpFor(this.currentMLines()) };
  }

  async createAnswer() {
    return { type: "answer", sdp: sdpFor(this.currentMLines()) };
  }

  async setLocalDescription(desc) {
    const description = desc || (await this.#implicitLocalDescription());

    if (description.type === "offer") {
      this.#assertState("stable", description.type, "setLocalDescription");
      this.signalingState = "have-local-offer";
    } else {
      this.#assertState("have-remote-offer", description.type, "setLocalDescription");
      this.signalingState = "stable";
      this.negotiatedMLines = mLinesOf(description.sdp);
    }

    this.localDescription = description;
  }

  async setRemoteDescription(description) {
    if (description.type === "offer") {
      if (this.signalingState !== "stable" && this.signalingState !== "have-remote-offer") {
        throw wrongState("offer", this.signalingState);
      }
      this.#assertSubsequentOfferOrder(description.sdp);
      this.#adoptRemoteMLines(mLinesOf(description.sdp));
      this.signalingState = "have-remote-offer";
    } else {
      if (this.signalingState !== "have-local-offer") {
        throw wrongState("answer", this.signalingState);
      }
      this.#assertAnswerMatchesOffer(description.sdp);
      this.signalingState = "stable";
      this.negotiatedMLines = mLinesOf(description.sdp);
    }

    this.remoteDescription = description;
  }

  // --- Rule enforcement ---

  async #implicitLocalDescription() {
    return this.remoteDescription?.type === "offer"
      ? await this.createAnswer()
      : await this.createOffer();
  }

  #assertState(expected, type, method) {
    if (this.signalingState !== expected) {
      throw domException(
        "InvalidStateError",
        `Failed to execute '${method}' on 'RTCPeerConnection': ` +
          `Failed to set local ${type} sdp: Called in wrong state: ${this.signalingState}`,
      );
    }
  }

  /** A later offer may append m-lines but never reorder the settled ones. */
  #assertSubsequentOfferOrder(sdp) {
    if (!this.negotiatedMLines) return;

    const incoming = mLinesOf(sdp);
    const settled = this.negotiatedMLines;

    const reordered =
      incoming.length < settled.length || settled.some((kind, index) => incoming[index] !== kind);

    if (reordered) {
      throw domException(
        "InvalidAccessError",
        "Failed to execute 'setRemoteDescription' on 'RTCPeerConnection': " +
          "Failed to set remote offer sdp: The order of m-lines in subsequent " +
          "offer doesn't match order from previous offer/answer.",
      );
    }
  }

  /** An answer must mirror the offer it answers, m-line for m-line. */
  #assertAnswerMatchesOffer(sdp) {
    const offered = mLinesOf(this.localDescription?.sdp);
    const answered = mLinesOf(sdp);

    const mismatched =
      offered.length !== answered.length || offered.some((kind, index) => answered[index] !== kind);

    if (mismatched) {
      throw domException(
        "InvalidAccessError",
        "Failed to execute 'setRemoteDescription' on 'RTCPeerConnection': " +
          "Failed to set remote answer sdp: The order of m-lines in answer " +
          "doesn't match order in offer. Rejecting answer.",
      );
    }
  }

  /**
   * Applying a remote offer materialises transceivers for its m-lines, which is
   * what makes the local answer mirror the offer's ordering.
   */
  #adoptRemoteMLines(kinds) {
    kinds.forEach((kind, index) => {
      if (!this.transceivers[index]) {
        this.addTransceiver(kind, { direction: "recvonly" });
        return;
      }

      // A pre-created transceiver sitting at the wrong index is exactly the
      // desync that produces an m-line mismatch; surface it rather than repair.
      if (this.transceivers[index].receiver.track.kind !== kind) {
        this.transceivers.splice(index, 0, {
          receiver: { track: { kind } },
          sender: { track: null, replaceTrack: vi.fn() },
          direction: "recvonly",
          stop: vi.fn(),
        });
      }
    });
  }
}

/**
 * Drive a description from one peer into the other, mimicking the server relay.
 * Returns the error when the receiving side rejects it, so tests can assert on
 * the exact DOMException instead of on a swallowed recovery.
 */
export async function relayDescription(from, to) {
  try {
    await to.setRemoteDescription({
      type: from.localDescription.type,
      sdp: from.localDescription.sdp,
    });
    return null;
  } catch (error) {
    return error;
  }
}
