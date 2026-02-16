# Data Model: P2P File Transfer

**Feature**: 037-p2p-file-transfer
**Date**: 2026-02-16

## Overview

This feature has **no new database tables or migrations**. All transfer state is ephemeral — held in JavaScript memory on the client side and in the existing SessionServer GenServer state. The P2P session infrastructure (table `p2p_sessions`, SessionServer GenServer) from features 034-036 is reused as-is.

## Ephemeral Entities (Client-Side JavaScript)

### FileOffer

Represents a proposed file transfer sent via DataChannel.

| Field        | Type     | Description                                         |
|------------- |--------- |---------------------------------------------------- |
| transferId   | string   | UUID v4, unique per transfer attempt                |
| fileName     | string   | Original file name (e.g., "relatorio-2026.pdf")     |
| fileSize     | number   | File size in bytes                                  |
| mimeType     | string   | MIME type from File API (e.g., "application/pdf")   |
| totalChunks  | number   | ceil(fileSize / CHUNK_SIZE)                         |
| sha256       | string   | Hex-encoded SHA-256 hash of the complete file       |

**State Transitions**: pending → accepted | rejected

### TransferSession

Represents an active file transfer tracked on both sender and receiver sides.

| Field           | Type       | Description                                          |
|---------------- |----------- |----------------------------------------------------- |
| transferId      | string     | Matches the FileOffer transferId                     |
| role            | string     | "sender" or "receiver"                               |
| state           | string     | Current transfer state (see state machine below)     |
| file            | File/null  | Reference to the File object (sender only)           |
| chunks          | Array      | Array of ArrayBuffer (receiver: indexed by chunk #)  |
| receivedSet     | Set        | Set of received chunk indices (receiver only)        |
| totalChunks     | number     | Total expected chunks                                |
| bytesSent       | number     | Bytes sent so far (sender)                           |
| bytesReceived   | number     | Bytes received so far (receiver)                     |
| fileSize        | number     | Total file size in bytes                             |
| fileName        | string     | File name for download                               |
| mimeType        | string     | MIME type for download                               |
| expectedHash    | string     | SHA-256 hash from sender (receiver uses for verify)  |
| startTime       | number     | Transfer start timestamp (Date.now())                |
| speedSamples    | Array      | Rolling speed samples for ETA calculation            |

**State Machine**:
```
idle → offering → transferring → verifying → completed
                                           → failed
       → rejected
       → cancelled (from offering or transferring)
       → paused (from transferring, on disconnect)
         → transferring (on resume)
```

### Chunk (Wire Format)

Binary message sent over DataChannel.

| Offset  | Size    | Field       | Description                    |
|-------- |-------- |------------ |------------------------------- |
| 0       | 1 byte  | messageType | 0x04 for data chunk            |
| 1       | 4 bytes | chunkIndex  | Uint32 big-endian (0-based)    |
| 5       | ≤64KB   | payload     | Raw file data                  |

**Constraints**:
- Maximum payload: 65,536 bytes (64 KB)
- Maximum chunk index: 2^32 - 1 (supports files up to ~256 TB)
- Last chunk may be smaller than 64 KB

## Control Messages (Wire Format)

All control messages: 1-byte type header + JSON-encoded payload.

| Type | Code | Payload                                              |
|----- |----- |----------------------------------------------------- |
| file-offer     | 0x01 | `{ transferId, fileName, fileSize, mimeType, totalChunks, sha256 }` |
| file-accept    | 0x02 | `{ transferId }`                                     |
| file-reject    | 0x03 | `{ transferId }`                                     |
| chunk          | 0x04 | Binary (see Chunk above)                             |
| cancel         | 0x05 | `{ transferId, cancelledBy }`                        |
| have-chunks    | 0x06 | `{ transferId, indices: Uint32Array }` (binary)      |
| transfer-done  | 0x07 | `{ transferId }`                                     |
| hash-result    | 0x08 | `{ transferId, match: boolean }`                     |
| retry          | 0x09 | `{ transferId }`                                     |

## Existing Entities (Reused, No Changes)

### p2p_sessions (Database Table)

The existing `session_type` field already supports `"file_transfer"` as a value. No schema changes needed.

### SessionServer (GenServer State)

The existing `action_request` field in SessionServer state stores the current action request. For file transfer, it holds:

```elixir
%{
  type: "file_transfer",
  from: nickname,
  at: DateTime.utc_now()
}
```

This is already implemented in the 034/035 features.

## Configuration (Environment Variables)

| Variable                          | Default        | Description                          |
|---------------------------------- |--------------- |------------------------------------- |
| FILE_TRANSFER_MAX_SIZE_MB         | 500            | Maximum file size in MB (inclusive)  |
| FILE_TRANSFER_BLOCKED_EXTENSIONS  | .exe,.bat,...  | Comma-separated blocked extensions   |
| FILE_TRANSFER_CHUNK_SIZE_KB       | 64             | Chunk size in KB                     |

## Validation Rules

- File size: `file.size <= maxSizeMB * 1024 * 1024`
- File extension: extracted via `fileName.split('.').pop().toLowerCase()`, checked against blocked list
- Transfer ID: UUID v4 format
- Chunk index: 0 ≤ index < totalChunks
- SHA-256 hash: 64-character hex string
