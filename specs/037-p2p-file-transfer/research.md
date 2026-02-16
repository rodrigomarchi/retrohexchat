# Research: P2P File Transfer

**Feature**: 037-p2p-file-transfer
**Date**: 2026-02-16

## R1: DataChannel Binary Transfer Protocol

**Decision**: Use a custom binary protocol over RTCDataChannel with `arraybuffer` binaryType.

**Rationale**: The DataChannel is already available via the existing WebRTC infrastructure (`webrtc.js` exports `onDataChannel(pc, callback)`). Binary transfers are the most efficient format. A simple message-type header (1 byte) followed by payload allows multiplexing control messages (offer, accept, reject, cancel, have_chunks, complete, hash-verify) and data chunks on the same channel.

**Protocol Message Format**:
- Byte 0: Message type (0x01=file-offer, 0x02=file-accept, 0x03=file-reject, 0x04=chunk, 0x05=cancel, 0x06=have-chunks, 0x07=transfer-complete, 0x08=hash-result, 0x09=retry)
- Bytes 1+: Payload (JSON for control messages, raw binary for chunks)
- For chunk messages: Bytes 1-4 = chunk index (Uint32BE), Bytes 5+ = chunk data

**Alternatives Considered**:
- JSON-only protocol: Simpler parsing but base64 encoding of binary data would increase payload by ~33%. Rejected for efficiency.
- Separate DataChannels for control/data: More complex lifecycle management. Rejected — single channel is sufficient at one-transfer-at-a-time constraint.

## R2: Backpressure Strategy

**Decision**: Monitor `RTCDataChannel.bufferedAmount` and pause sending when it exceeds a high-water mark (1 MB). Resume when it drops below low-water mark (256 KB). Use `bufferedAmountLowThreshold` event when available.

**Rationale**: WebRTC DataChannel uses SCTP internally which has flow control, but the JavaScript sender can still queue data faster than the network can send it. Monitoring `bufferedAmount` prevents unbounded memory growth. The 1 MB high-water mark allows multiple chunks to be in-flight while keeping memory bounded.

**Alternatives Considered**:
- ACK-based flow control (receiver ACKs each chunk): Adds round-trip latency per chunk. Rejected — SCTP already guarantees ordered reliable delivery.
- No backpressure: Risk of memory exhaustion on large files. Rejected.

## R3: SHA-256 Hashing Strategy

**Decision**: Use `crypto.subtle.digest('SHA-256', buffer)` on both sender and receiver. Sender computes hash before transfer and includes it in the file-offer message. Receiver computes incrementally is infeasible with SubtleCrypto, so receiver hashes the complete assembled ArrayBuffer after all chunks arrive.

**Rationale**: `crypto.subtle` is available in all modern browsers over HTTPS (confirmed in spec assumptions). SubtleCrypto's `digest()` operates on a single ArrayBuffer, so incremental hashing would require a streaming implementation or WebAssembly. For files up to 500 MB, hashing the complete buffer is feasible (takes ~1-2 seconds on modern hardware).

**Alternatives Considered**:
- Web Crypto streaming hash: Not available in SubtleCrypto API. Would require a polyfill or WASM.
- Skip hashing for small files: Inconsistent behavior. Rejected — always verify.
- CRC32 instead of SHA-256: Weaker integrity guarantee. Rejected.

## R4: Resume Protocol Design

**Decision**: After reconnection, receiver sends a `have-chunks` message containing a Uint32Array of received chunk indices. Sender marks those as done and sends only missing chunks. This supports non-contiguous reception.

**Rationale**: Using a bitmap or index array rather than a simple "last received index" handles the case where chunks arrived out of order or some were lost during disconnection. The Uint32Array is compact: 500 MB file = ~7,813 chunks = ~31 KB index array (worst case).

**Alternatives Considered**:
- Byte offset resume (like HTTP Range): Doesn't handle non-contiguous reception. Rejected per spec requirements.
- Bitmap (1 bit per chunk): More compact but harder to parse. For 7,813 chunks = ~1 KB. The difference vs. Uint32Array is negligible.

## R5: File Assembly and Download

**Decision**: Receive chunks into a pre-allocated Array of ArrayBuffers indexed by chunk number. On completion, create a Blob from the ordered chunks and trigger download via `URL.createObjectURL()` + hidden anchor click.

**Rationale**: Storing chunks in an indexed array allows O(1) insertion regardless of arrival order (important for resume). Creating a Blob from chunk array avoids copying into a single ArrayBuffer. The hidden anchor + click pattern is the standard browser download trigger.

**Alternatives Considered**:
- StreamSaver.js for large file streaming to disk: Adds external dependency. Rejected per constitution (minimize dependencies).
- Single growing ArrayBuffer: Requires copying on each append. Rejected for performance.

## R6: DataChannel Creation Strategy

**Decision**: The initiator (connection creator) creates a DataChannel named `"filetransfer"` with `{ ordered: true }` during the WebRTC offer phase. The answerer receives it via the `ondatachannel` event (already wired via `webrtc.js` `onDataChannel()`).

**Rationale**: The existing `webrtc.js` library already exports `onDataChannel(pc, callback)` but no code currently creates a channel. The initiator-creates pattern is the standard WebRTC pattern. Using `ordered: true` (default) ensures chunks arrive in order, simplifying reassembly.

**Alternatives Considered**:
- Create DataChannel on-demand when file transfer starts: Would require renegotiation if the channel doesn't exist. More complex. Rejected.
- Unordered channel with manual reordering: Adds complexity. Rejected since ordered delivery is needed for the protocol.

## R7: Progress Calculation

**Decision**: Track `bytesSent`/`bytesReceived` and `startTime`. Calculate speed as a rolling average over the last 3 seconds (to smooth fluctuations). ETA = remainingBytes / rollingSpeed. Update UI at most once per 250ms via `requestAnimationFrame` throttle.

**Rationale**: A rolling average prevents wild speed fluctuations. 250ms throttle prevents excessive DOM updates while maintaining perceived smoothness (4 updates/second meets the spec's "at least once per second" requirement with headroom).

**Alternatives Considered**:
- Instantaneous speed: Too jittery. Rejected.
- Fixed interval (setInterval): Less efficient than rAF-based throttle. Rejected.

## R8: Integration with Existing Action Request Flow

**Decision**: Reuse the existing `request_action("file_transfer")` → `respond_action(accepted/rejected)` flow for the file offer consent phase. The file metadata (name, size, type) is sent via the DataChannel after WebRTC connection is established, NOT through PubSub. This keeps file data entirely P2P.

**Rationale**: The existing action request flow provides bilateral consent and handles the lobby UI (consent banner with accept/reject buttons). File metadata flows through the DataChannel to satisfy the "no server involvement" requirement. The sequence is: (1) User selects file → validation → (2) `request_action("file_transfer")` via LiveView → (3) Peer accepts → (4) WebRTC connects → (5) File offer message via DataChannel → (6) Transfer begins.

**Alternatives Considered**:
- Send file metadata via PubSub: Technically works but violates the spirit of "file data never transits the server." Metadata (filename, size) is not file data, but keeping everything on the DataChannel is cleaner.
- Skip the action request and use DataChannel directly: Loses the lobby consent UI. Rejected.

## R9: Blocked Extension List

**Decision**: Default blocked extensions: `.exe`, `.bat`, `.cmd`, `.com`, `.msi`, `.scr`, `.pif`, `.vbs`, `.vbe`, `.js`, `.jse`, `.wsf`, `.wsh`, `.ps1`, `.reg`. Configurable via `FILE_TRANSFER_BLOCKED_EXTENSIONS` environment variable (comma-separated).

**Rationale**: This covers the most common Windows executable/script extensions. The list is conservative but configurable. Extension-only checking is explicitly stated in the spec as basic protection.

**Alternatives Considered**:
- MIME type checking: Browser-provided MIME types are unreliable (based on extension anyway). Rejected.
- No default block list: Too permissive. Rejected.
