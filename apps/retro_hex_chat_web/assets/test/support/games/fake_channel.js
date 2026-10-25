/**
 * A data channel that is open, accepts every send, and hands the test the
 * events a real one would fire: `emit("message", { data })` delivers a
 * datagram, `emit("close")` drops the peer.
 *
 * @returns {{ readyState: string, bufferedAmount: number, sent: ArrayBuffer[],
 *   send: (data: ArrayBuffer) => void, addEventListener: Function,
 *   removeEventListener: Function, emit: (type: string, event?: object) => void }}
 */
export function fakeChannel() {
  const listeners = { message: new Set(), close: new Set() };
  return {
    readyState: "open",
    bufferedAmount: 0,
    sent: [],
    send(data) {
      this.sent.push(data);
    },
    addEventListener(type, listener) {
      listeners[type]?.add(listener);
    },
    removeEventListener(type, listener) {
      listeners[type]?.delete(listener);
    },
    emit(type, event = {}) {
      if (type === "close") this.readyState = "closed";
      for (const listener of [...(listeners[type] ?? [])]) listener({ type, ...event });
    },
  };
}
