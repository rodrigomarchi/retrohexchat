# Feature Specification: P2P File Transfer

**Feature Branch**: `037-p2p-file-transfer`
**Created**: 2026-02-16
**Status**: Draft
**Input**: User description: "P2P File Transfer for RetroHexChat — direct file sending between peers via DataChannel"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Send a File to a Peer (Priority: P1)

Alice is in the P2P lobby with Mario. He wants to share a PDF report. He clicks the "Enviar Arquivo" button (or drags a file onto the lobby area). The system validates the file is under the size limit and has an allowed extension. A file offer appears on Mario's side showing the file name, size, and type. Mario accepts the offer. The file transfers in chunks with a progress bar showing percentage, speed, and estimated time remaining. When complete, the system verifies the file's integrity. Mario's browser automatically triggers a download of the received file. Both users see a success confirmation message.

**Why this priority**: This is the core value proposition — without the ability to send and receive a file end-to-end, the feature has no purpose. Every other story builds on this foundation.

**Independent Test**: Can be fully tested by having two peers in a lobby, one selecting a file, the other accepting, and verifying the downloaded file matches the original. Delivers the primary file sharing value.

**Acceptance Scenarios**:

1. **Given** two peers are connected in a P2P lobby with an active data channel, **When** Alice clicks "Enviar Arquivo" and selects a 2.4 MB PDF file, **Then** a file offer notification appears on Mario's side showing "alice quer enviar: relatorio-2026.pdf (2.4 MB)".
2. **Given** Mario sees a pending file offer, **When** Mario clicks "Aceitar", **Then** the file transfer begins and both users see a progress bar with percentage, transfer speed (KB/s), and ETA.
3. **Given** a file transfer is in progress, **When** all chunks have been sent and integrity verification succeeds, **Then** Mario's browser triggers an automatic download and both users see "Transferencia concluida com sucesso".
4. **Given** two peers are connected in a P2P lobby, **When** Alice drags a valid file onto the lobby area, **Then** the system initiates the same file offer flow as clicking the button.
5. **Given** Alice selects a file, **When** the file exceeds the maximum size limit, **Then** the system shows an error message with the file size and the allowed maximum, and no offer is sent.
6. **Given** Alice selects a file, **When** the file has a blocked extension (e.g., .exe, .bat), **Then** the system shows an error message listing the blocked type, and no offer is sent.
7. **Given** Mario sees a pending file offer, **When** Mario clicks "Rejeitar", **Then** the offer is dismissed, Alice sees "Mario rejeitou a transferencia de arquivo", and no data is transferred.

---

### User Story 2 - Cancel an Active Transfer (Priority: P2)

During an active file transfer at 45% progress, Mario decides he no longer wants to receive the file. He clicks "Cancelar" on the progress bar. A cancellation message is sent to the other peer. Both sides clean up any partial data. The progress bar disappears and both users see a message indicating who cancelled the transfer.

**Why this priority**: Cancellation is essential for user control. Without it, users are trapped in unwanted transfers with no recourse. This is a safety valve that must exist alongside the core transfer.

**Independent Test**: Can be tested by starting a transfer with a large enough file to allow time for cancellation, clicking cancel mid-transfer, and verifying both sides clean up and display the cancellation message.

**Acceptance Scenarios**:

1. **Given** a file transfer is in progress at any percentage, **When** the receiver clicks "Cancelar", **Then** the transfer stops immediately, partial data is discarded, and both users see "Transferencia cancelada por [receiver name]".
2. **Given** a file transfer is in progress, **When** the sender clicks "Cancelar", **Then** the transfer stops immediately, partial data is discarded, and both users see "Transferencia cancelada por [sender name]".
3. **Given** a transfer has been cancelled, **When** the cancellation completes, **Then** both users are returned to the normal lobby state and can initiate new transfers.

---

### User Story 3 - Resume Transfer After Disconnection (Priority: P3)

At 60% through a file transfer, the connection between Alice and Mario drops unexpectedly. The existing reconnection mechanism attempts to re-establish the connection. Upon reconnection, the receiver reports which chunks it has already received. The sender transmits only the missing chunks. The progress bar continues from where it left off rather than starting over.

**Why this priority**: Resume prevents frustration from lost progress on large transfers. While not strictly required for basic functionality, it significantly improves the experience for larger files where re-transferring from scratch would be unacceptable.

**Independent Test**: Can be tested by simulating a connection drop mid-transfer, allowing reconnection, and verifying that only missing chunks are re-sent and the final downloaded file is intact.

**Acceptance Scenarios**:

1. **Given** a file transfer is at 60% and the connection drops, **When** the automatic reconnection succeeds, **Then** the receiver reports its array of already-received chunk indices to the sender.
2. **Given** the sender receives the list of already-received chunks, **When** the transfer resumes, **Then** only the missing chunks are transmitted, and the progress bar continues from the reconnection point.
3. **Given** a resumed transfer completes, **When** integrity verification runs, **Then** the full file passes verification and downloads correctly.
4. **Given** a connection drops during transfer, **When** all reconnection attempts fail, **Then** both sides clean up partial data and display "Conexao perdida — transferencia falhou".

---

### User Story 4 - Integrity Verification Failure (Priority: P4)

After all chunks are transmitted, the system computes a hash of the received file and compares it with the hash provided by the sender. If the hashes don't match, the receiver is notified of the integrity failure and the sender is given the option to retry the entire transfer.

**Why this priority**: Data integrity is important but failures should be rare given reliable DataChannel transport. This story handles the exceptional case gracefully.

**Independent Test**: Can be tested by corrupting received data before verification and confirming the mismatch is detected and the retry option is presented.

**Acceptance Scenarios**:

1. **Given** all chunks have been received, **When** the computed hash matches the sender's hash, **Then** the file downloads automatically and both users see a success message.
2. **Given** all chunks have been received, **When** the computed hash does NOT match the sender's hash, **Then** the receiver sees "Verificacao de integridade falhou" and the sender sees an option to retry the entire transfer.
3. **Given** the sender chooses to retry after a checksum mismatch, **When** the retry begins, **Then** the entire file is re-transferred from scratch (not resumed).

---

### User Story 5 - Concurrent Transfer Queueing (Priority: P5)

While a transfer is already in progress between Alice and Mario, one of them tries to initiate a second file transfer. The system informs them that only one transfer can be active at a time and queues the new request until the current transfer completes.

**Why this priority**: This is a constraint-handling story. The one-transfer-at-a-time limit is straightforward, and queueing provides a clean user experience without blocking the user from planning their next send.

**Independent Test**: Can be tested by attempting to send a second file during an active transfer and verifying the queued message appears, then confirming the queued transfer starts after the first completes.

**Acceptance Scenarios**:

1. **Given** a file transfer is currently active, **When** either peer attempts to send another file, **Then** the system displays a message indicating a transfer is already in progress and the new request is queued.
2. **Given** a file transfer completes while another is queued, **When** the active transfer finishes, **Then** the queued file offer is automatically presented to the receiver for acceptance.

---

### Edge Cases

- **File exactly at size limit (500 MB)**: Transfer is allowed — the boundary check is inclusive (<=).
- **File just over size limit (500.1 MB)**: Transfer is rejected with a clear error message showing the file size and the 500 MB maximum.
- **Blocked extension renamed**: Only the file extension is checked, not file contents. A `.exe` renamed to `.pdf` passes validation (basic protection only).
- **Very small file (single chunk)**: Transfer completes in one chunk. Backpressure logic is skipped. Progress bar shows 100% immediately.
- **Very large file (500 MB, ~7,813 chunks)**: Chunk indexing supports up to 2^32 indices. Backpressure prevents memory exhaustion on the receiver.
- **DataChannel closes mid-transfer**: The system attempts to resume via the automatic reconnection mechanism. If reconnection fails after all retry attempts, both sides clean up and show an error.
- **Browser tab closed during transfer**: The remaining peer sees "Conexao perdida" and cleans up partial data.
- **Both peers try to send simultaneously**: The first offer is processed; the second is queued. Only one active transfer per session.
- **Checksum mismatch**: The sender is notified and offered the option to retry the entire file transfer from scratch.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST allow a user to select a file for transfer via a file picker button ("Enviar Arquivo") in the P2P lobby.
- **FR-002**: System MUST allow a user to select a file for transfer via drag-and-drop onto the P2P lobby area.
- **FR-003**: System MUST validate that selected files do not exceed the configurable maximum file size (default: 500 MB, inclusive).
- **FR-004**: System MUST validate that selected files do not have a blocked file extension (configurable blocked list).
- **FR-005**: System MUST display validation errors to the sender with specific details (file size vs. limit, or blocked extension name).
- **FR-006**: System MUST send a file offer to the receiving peer containing the file name, size, and MIME type.
- **FR-007**: System MUST display the file offer to the receiver with sender name, file name, formatted size, and Accept/Reject buttons.
- **FR-008**: System MUST transfer file data exclusively over the peer-to-peer data channel — file data MUST NOT pass through the server.
- **FR-009**: System MUST split files into 64 KB chunks for transfer.
- **FR-010**: System MUST implement backpressure to prevent overwhelming the receiver's memory during transfer.
- **FR-011**: System MUST display a progress bar during transfer showing percentage complete, current transfer speed (KB/s), and estimated time remaining (ETA).
- **FR-012**: System MUST compute a SHA-256 hash of the complete file after transfer and verify it against the sender's hash.
- **FR-013**: System MUST trigger an automatic browser download of the received file upon successful integrity verification.
- **FR-014**: System MUST display a success message ("Transferencia concluida com sucesso") to both peers upon successful transfer completion.
- **FR-015**: System MUST allow either peer to cancel an active transfer at any time.
- **FR-016**: System MUST clean up all partial data on both sides when a transfer is cancelled.
- **FR-017**: System MUST display a cancellation message identifying who cancelled ("Transferencia cancelada por [name]") to both peers.
- **FR-018**: System MUST support resuming interrupted transfers after reconnection by having the receiver report its array of already-received chunk indices.
- **FR-019**: System MUST transmit only missing chunks when resuming a transfer (not the entire file).
- **FR-020**: System MUST enforce a maximum of one simultaneous transfer per session, queueing additional requests.
- **FR-021**: System MUST notify the sender when a checksum mismatch occurs and offer the option to retry the entire transfer.
- **FR-022**: System MUST separate transfer protocol logic (library) from UI wiring (hook) — the library MUST NOT contain DOM manipulation, and the hook MUST NOT contain protocol logic.
- **FR-023**: System MUST display "Conexao perdida" to the remaining peer when the other peer's connection is lost irrecoverably.
- **FR-024**: File size limit and blocked extension list MUST be configurable via environment variables.

### Key Entities

- **File Offer**: Represents a proposed file transfer — contains file name, size, MIME type, sender identity, and a unique transfer identifier. Transitions through states: pending, accepted, rejected.
- **Transfer Session**: Represents an active file transfer — tracks chunk progress, transfer speed, received chunk indices, sender/receiver roles, and current state (transferring, paused, completed, failed, cancelled).
- **Chunk**: A segment of file data with a sequential index (0-based, fits in 4 bytes) and binary payload (64 KB maximum). Used for ordered and resumable transfer.

## Assumptions

- The P2P data channel is already established and functional before file transfer can begin (prerequisite from existing WebRTC signaling feature).
- The existing automatic reconnection mechanism (3 attempts with exponential backoff) handles re-establishing the data channel after disconnection.
- The browser's native file download mechanism handles disk space concerns on the receiver's end.
- File extension validation provides basic protection only — the system does not perform deep content inspection or virus scanning.
- All state is ephemeral — no transfer history or metadata is persisted to a database.
- The file picker and drag-and-drop permissions are already handled by the existing lobby infrastructure.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can complete a 10 MB file transfer end-to-end (select, accept, transfer, verify, download) in under 30 seconds on a typical broadband connection.
- **SC-002**: The progress bar updates at least once per second during active transfer, accurately reflecting percentage, speed, and ETA.
- **SC-003**: 100% of completed transfers pass SHA-256 integrity verification (no silent data corruption).
- **SC-004**: Cancelled transfers release all partial data within 1 second, leaving no orphaned resources.
- **SC-005**: Resumed transfers after reconnection complete successfully with the final file matching the original (verified by hash).
- **SC-006**: Users see clear, actionable feedback for all error conditions (oversized file, blocked type, verification failure, connection loss) within 1 second of the event.
- **SC-007**: File data never transits the server — 100% of file bytes flow exclusively through the direct peer connection.
