# Category AH: P2P File Transfer

**Priority**: Yellow (High — core P2P feature)
**Dependencies**: AE (P2P Foundation), AF (P2P Lobby & Session UI), AG (WebRTC Signaling)
**Existing**: None (new feature)

## Items

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| AH1 | file_transfer.js lib module | New | Pure logic module implementing the 3-phase file transfer protocol: metadata exchange, chunked transfer with backpressure, SHA-256 verification. Handles DataChannel configuration (ordered, reliable, 64KB threshold) |
| AH2 | file_transfer_hook.js | New | LiveView hook wiring: connects file_transfer.js to DOM (progress bar, cancel button, download trigger) and LiveView events. Follows hook=wiring/lib=logic pattern |
| AH3 | File picker and drag-and-drop | New | File selection via button click (input[type=file]) and drag-and-drop on the lobby area. Validates file before offering: size ≤500MB, extension not blocked (.exe, .bat, .cmd, .scr) |
| AH4 | Metadata exchange (Phase 1) | New | Sender sends file-offer message via DataChannel: `{type, id, name, size, mime, chunks}`. Receiver displays file info and Accept/Reject buttons. Accept triggers Phase 2 |
| AH5 | Chunked transfer with backpressure (Phase 2) | New | 64KB chunks with 4-byte index header sent via DataChannel. Backpressure: pause sending when `bufferedAmount > CHUNK_SIZE * 4`. Resume on `onbufferedamountlow`. Receiver sends file-ack every N chunks |
| AH6 | SHA-256 verification (Phase 3) | New | After all chunks sent, sender sends file-complete with SHA-256 checksum. Receiver computes checksum via `crypto.subtle.digest('SHA-256', data)` and compares. Sends file-verified or file-error |
| AH7 | Progress bar UI | New | 98.css-styled progress bar showing: percentage, bytes transferred/total, transfer speed (KB/s moving average of last 10 samples), ETA. Updates every chunk (64KB). Sender and receiver both see progress |
| AH8 | Transfer cancellation | New | Either peer can cancel anytime via file-cancel message on DataChannel. Cancellation cleans up partial data, resets UI, shows 'Transferência cancelada' message |
| AH9 | Resume after reconnection | New | If WebRTC connection drops and reconnects (via AG6 retry), receiver reports already-received chunk indices as an array (`have_chunks: [0, 1, 2, 3]`) to support non-contiguous reception. Sender transmits only missing chunks instead of restarting |
| AH10 | File size and type restrictions | New | Max file size: 500MB, blocked extensions: .exe, .bat, .cmd, .scr. One simultaneous transfer per session. Chunk timeout: 30s with no ack triggers error. All limits configurable by server operator via environment variables (P2P_MAX_FILE_SIZE, P2P_BLOCKED_EXTENSIONS) |
| AH11 | Browser download trigger | New | After successful verification, trigger browser download: create Blob from received chunks, generate object URL, programmatic click on download link. Clean up object URL after download starts |
| AH12 | JS tests | New | Vitest tests for file_transfer.js: chunking logic, backpressure simulation, checksum calculation, metadata protocol, cancellation, resume logic. Tests for file_transfer_hook.js: DOM wiring, progress updates, file picker integration |

## Dependencies Detail

- AH1 (lib) depends on AG2 (webrtc.js provides DataChannel)
- AH2 (hook) depends on AH1 (lib) and AG3 (webrtc_hook.js for DataChannel events)
- AH3 (file picker) depends on AF7 (lobby layout for drop zone) and AH2 (hook)
- AH4 (metadata) depends on AH1 (protocol implementation)
- AH5 (chunking) depends on AH4 (metadata accepted first)
- AH6 (verification) depends on AH5 (all chunks received)
- AH7 (progress) depends on AH2 (hook updates DOM) and AF13 (CSS)
- AH8 (cancellation) depends on AH1 (protocol support)
- AH9 (resume) depends on AG6 (retry mechanism) and AH5 (chunk tracking)
- AH10 (restrictions) depends on AH3 (validation before offer) and AE4 (policy)
- AH11 (download) depends on AH6 (verification complete)
- AH12 (tests) depends on AH1 and AH2

## Technical Notes

- DataChannel configuration: `{ordered: true, maxRetransmits: null, bufferedAmountLowThreshold: 65536}`
- Chunk format: `[4-byte Uint32 chunk index][up to 64KB binary data]` — sent as ArrayBuffer
- Backpressure: check `channel.bufferedAmount` before each send, listen to `onbufferedamountlow`
- SHA-256: use `crypto.subtle.digest('SHA-256', concatenatedBuffer)` — available in all modern browsers over HTTPS
- Speed calculation: moving average of last 10 chunk durations, displayed as KB/s or MB/s
- ETA: remaining bytes / current speed, displayed in human-readable format
- File size display: human-readable (KB, MB) with 2 decimal places
- Blob construction: collect chunks in array, create Blob with correct MIME type
- Download trigger: `URL.createObjectURL(blob)` → create `<a>` element → click → `URL.revokeObjectURL`
- Resume protocol: on reconnect, receiver sends `{type: "file-resume", id: "...", have_chunks: [0, 1, 2, ...]}` — array of received chunk indices supports non-contiguous reception (e.g., chunks 0,1,3 received but 2 missing)
- One transfer at a time per session — queue or reject additional requests
- 30-second chunk timeout: if no data received for 30s, consider transfer failed
- File transfer limits (max size, blocked extensions) are configurable via app environment / env vars for server operators

---

## Spec Command

```
/speckit.specify "P2P File Transfer for RetroHexChat.

PROBLEM: Users cannot send files directly to each other. In a chat application inspired by mIRC's DCC, file transfer is a fundamental P2P feature. Users need to select a file, have it validated and accepted by the peer, transfer it efficiently in chunks with progress feedback, verify integrity, and trigger a browser download — all over a direct WebRTC DataChannel connection without server involvement in the actual data transfer.

EXISTING CONTEXT: The P2P bounded context provides session infrastructure (SessionServer GenServer, Service, Policy, tokens). The lobby UI provides bilateral consent for actions, browser capability detection (RTCDataChannel check), and file picker permission handling. WebRTC signaling establishes RTCPeerConnection with DataChannel support. The project uses Vitest+jsdom for JS testing and follows the hook=wiring/lib=logic pattern. crypto.subtle is available in all modern browsers over HTTPS for SHA-256 hashing.

USER JOURNEY — SEND FILE: Rodrigo is in the P2P lobby with Mario. He clicks 'Enviar Arquivo' or drags a file onto the lobby area. The file is validated (under 500MB, not a blocked extension). A file-offer message is sent via DataChannel showing the file name, size, and type. Mario sees: 'rodrigo quer enviar: relatorio-2026.pdf (2.4 MB)' with Accept/Reject buttons. Mario clicks Accept. The transfer begins: 64KB chunks flow over the DataChannel. Both users see a 98.css progress bar with percentage, speed (KB/s), and ETA. After all chunks are sent, SHA-256 verification runs. On success, Mario's browser automatically triggers the download. Both users see 'Transferência concluída com sucesso'.

USER JOURNEY — CANCEL TRANSFER: During an active transfer at 45%, Mario clicks 'Cancelar'. A file-cancel message is sent. Both sides clean up partial data. The progress bar disappears and both users see 'Transferência cancelada por Mario'.

USER JOURNEY — RESUME AFTER DISCONNECT: At 60% transfer, the WebRTC connection drops. The signaling automatic retry mechanism (3 attempts with exponential backoff) reconnects. The receiver reports an array of already-received chunk indices (have_chunks) to support non-contiguous reception. The sender transmits only the missing chunks, and the progress bar continues from where it left off.

ACTORS: Sender (selects and sends file), receiver (accepts/rejects and downloads). Both can cancel. The browser handles DataChannel reliability and flow control. crypto.subtle provides integrity verification.

EDGE CASES: File exactly 500MB (allowed, boundary check). File 500.1MB (rejected with clear message). File with blocked extension renamed to .pdf (only extension check, not magic bytes — basic protection). DataChannel closes mid-transfer (attempt resume via automatic WebRTC retry, else fail gracefully). Receiver's disk space insufficient (browser handles this during download). Very small file (1 chunk — skip backpressure logic). Very large file (500MB = ~7,813 chunks — ensure chunk index fits in 4 bytes, max 2^32). Checksum mismatch (sender notified, option to retry entire transfer). Both peers try to send files simultaneously (one transfer at a time, second request queued). Browser tab closed during transfer (other peer sees 'Conexão perdida').

NEGATIVE REQUIREMENTS: File data must NEVER pass through the server — DataChannel is the exclusive transport. No server-side file storage. The file_transfer.js lib must NOT contain DOM manipulation. The hook must NOT contain transfer protocol logic. File type validation is basic (extension only) — no server-side virus scanning. No thumbnail generation or file preview. No transfer history persistence (ephemeral). Maximum one simultaneous transfer per session.

SCOPE: In scope — file_transfer.js lib with 3-phase protocol, file_transfer_hook.js wiring, file picker and drag-and-drop, metadata exchange UI, 64KB chunked transfer with backpressure, SHA-256 verification, 98.css progress bar with speed and ETA, cancellation, resume after reconnection (have_chunks array for non-contiguous resume), file size and type restrictions (configurable via env vars), browser download trigger, JS tests. Out of scope — multiple simultaneous transfers, file preview/thumbnail, transfer history, server-side file relay, virus scanning, help documentation."
```
